import Foundation
import Vision
import AppKit
import Carbon.HIToolbox

final class TrackingCoordinator {
    private let cameraManager = CameraManager()
    private let handTracker = HandTracker()
    private let appState: AppState
    private var lastClickTime: Date = .distantPast

    private let screenW: CGFloat
    private let screenH: CGFloat

    // Right hand relative cursor movement
    private var rightHandAnchor: CGPoint?
    private var cursorAnchor: CGPoint?
    private let sensitivity: CGFloat = 2.5

    // Left hand gesture hold detection
    private var leftGestureStartTime: Date?
    private var leftGestureValue: Int = -1
    private var leftGestureFired: Bool = false
    private let holdDuration: TimeInterval = 1.0

    // Wave detection
    private var wavePositions: [(x: CGFloat, time: Date)] = []
    private var lastWaveTime: Date = .distantPast

    // Speech
    private let speechEngine = SpeechEngine()
    private var bothFistsStartTime: Date?
    private var speechActive = false
    private var lastTypedLength = 0

    init(appState: AppState) {
        self.appState = appState
        let screen = NSScreen.main?.frame.size ?? CGSize(width: 1512, height: 982)
        self.screenW = screen.width
        self.screenH = screen.height

        cameraManager.onFrame = { [weak self] pixelBuffer in
            self?.processFrame(pixelBuffer)
        }
    }

    func start() {
        cameraManager.start()
    }

    func stop() {
        cameraManager.stop()
    }

    func emergencyKill() {
        stop()
        DispatchQueue.main.async { [weak self] in
            self?.appState.isEnabled = false
        }
    }

    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2

        do {
            try handler.perform([handRequest])
        } catch {
            return
        }

        let results = handRequest.results ?? []

        if results.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.appState.trackingState = .inactive
                self?.appState.handsCount = 0
                self?.appState.leftHandDetected = false
                self?.appState.rightHandDetected = false
                self?.appState.gestureLabel = ""
                self?.appState.gestureProgress = 0
            }
            resetLeftGesture()
            rightHandAnchor = nil
            cursorAnchor = nil
            return
        }

        // Separate hands
        var leftHand: VNHumanHandPoseObservation?
        var rightHand: VNHumanHandPoseObservation?

        for obs in results {
            switch obs.chirality {
            case .left:
                leftHand = obs
            case .right:
                rightHand = obs
            default:
                if let wrist = try? obs.recognizedPoint(.wrist) {
                    if wrist.location.x < 0.5 {
                        rightHand = obs
                    } else {
                        leftHand = obs
                    }
                }
            }
        }

        let lFingers = leftHand != nil ? countExtendedFingers(leftHand!) : -1
        let rFingers = rightHand != nil ? countExtendedFingers(rightHand!) : -1

        DispatchQueue.main.async { [weak self] in
            self?.appState.handsCount = results.count
            self?.appState.leftHandDetected = leftHand != nil
            self?.appState.rightHandDetected = rightHand != nil
            self?.appState.debugInfo = "L:\(lFingers)f R:\(rFingers)f"
        }

        // === SPEECH: both fists = start, no hands = stop ===
        let bothFists = leftHand != nil && rightHand != nil
            && countExtendedFingers(leftHand!) == 0 && countExtendedFingers(rightHand!) == 0
            && !isPinching(leftHand!) && !isPinching(rightHand!)

        if bothFists {
            if bothFistsStartTime == nil { bothFistsStartTime = Date() }
            if let start = bothFistsStartTime, Date().timeIntervalSince(start) > 1.0 && !speechActive {
                speechActive = true
                lastTypedLength = 0
                speechEngine.onResult = { [weak self] text in
                    guard let self else { return }
                    let newChars = String(text.dropFirst(self.lastTypedLength))
                    if !newChars.isEmpty {
                        self.speechEngine.typeText(newChars)
                        self.lastTypedLength = text.count
                    }
                    DispatchQueue.main.async { self.appState.gestureLabel = "🎤 \(text)" }
                }
                speechEngine.startListening()
                DispatchQueue.main.async { [weak self] in
                    self?.appState.gestureLabel = "🎤 Listening..."
                }
            }
            return
        } else {
            bothFistsStartTime = nil
            if speechActive {
                // Stop speech when both fists are released (any other gesture)
                speechActive = false
                speechEngine.stopListening()
                DispatchQueue.main.async { [weak self] in
                    self?.appState.gestureLabel = ""
                    self?.appState.gestureProgress = 0
                }
            }
        }

        // === RIGHT HAND: pinch to drag cursor (relative) ===
        if let rh = rightHand {
            if isPinching(rh) {
                if let wrist = try? rh.recognizedPoint(.wrist), wrist.confidence > 0.3 {
                    let currentWrist = CGPoint(x: wrist.location.x, y: wrist.location.y)
                    if rightHandAnchor == nil {
                        rightHandAnchor = currentWrist
                        cursorAnchor = CGEvent(source: nil)?.location ?? .zero
                    } else if let anchor = rightHandAnchor, let curAnchor = cursorAnchor {
                        let deltaX = -(currentWrist.x - anchor.x) * screenW * sensitivity
                        let deltaY = -(currentWrist.y - anchor.y) * screenH * sensitivity
                        let newX = max(0, min(screenW, curAnchor.x + deltaX))
                        let newY = max(0, min(screenH, curAnchor.y + deltaY))
                        CGWarpMouseCursorPosition(CGPoint(x: newX, y: newY))
                    }
                }
            } else {
                rightHandAnchor = nil
                cursorAnchor = nil
            }
        } else {
            rightHandAnchor = nil
            cursorAnchor = nil
        }

        // === LEFT HAND ===
        if let lh = leftHand {
            // Thumb+pinky (🤙) detected — treat as gestureValue -2 (Escape) below

            // Pinch = click
            if isPinching(lh) {
                resetLeftGesture()
                let now = Date()
                if now.timeIntervalSince(lastClickTime) > 0.5 {
                    lastClickTime = now
                    performClick()
                }
                DispatchQueue.main.async { [weak self] in
                    self?.appState.trackingState = .pinching
                    self?.appState.gestureLabel = "👆 Click"
                }
            } else {
                // Finger counting
                let fingerCount = countExtendedFingers(lh)

                let gestureValue: Int
                if isThumbPinky(lh) {
                    gestureValue = -2  // Escape (🤙)
                } else if fingerCount >= 4 {
                    gestureValue = -1  // idle
                } else if fingerCount == 0 {
                    gestureValue = 0   // Enter (fist)
                } else {
                    gestureValue = fingerCount  // 1-3
                }

                // Update label
                DispatchQueue.main.async { [weak self] in
                    self?.appState.trackingState = .tracking
                    if gestureValue == -1 {
                        self?.appState.gestureLabel = ""
                        self?.appState.gestureProgress = 0
                    } else if gestureValue == -2 {
                        self?.appState.gestureLabel = "🤙 Esc"
                    } else if gestureValue == 0 {
                        self?.appState.gestureLabel = "⏎ Enter"
                    } else {
                        self?.appState.gestureLabel = "\(gestureValue)"
                    }
                }

                // Hold detection (skip idle)
                if gestureValue == -1 {
                    resetLeftGesture()
                } else if gestureValue == leftGestureValue {
                    if !leftGestureFired, let start = leftGestureStartTime {
                        let elapsed = Date().timeIntervalSince(start)
                        let progress = min(1.0, elapsed / holdDuration)
                        DispatchQueue.main.async { [weak self] in
                            self?.appState.gestureProgress = progress
                        }
                        if elapsed >= holdDuration {
                            leftGestureFired = true
                            fireGesture(gestureValue)
                            DispatchQueue.main.async { [weak self] in
                                self?.appState.gestureLabel = "✓"
                                self?.appState.gestureProgress = 0
                            }
                        }
                    }
                } else {
                    leftGestureValue = gestureValue
                    leftGestureStartTime = Date()
                    leftGestureFired = false
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.gestureProgress = 0
                    }
                }
            }
        } else {
            resetLeftGesture()
            DispatchQueue.main.async { [weak self] in
                self?.appState.trackingState = .inactive
                self?.appState.gestureLabel = ""
                self?.appState.gestureProgress = 0
            }
        }
    }

    // MARK: - Helpers

    private func isPinching(_ obs: VNHumanHandPoseObservation) -> Bool {
        guard let thumb = try? obs.recognizedPoint(.thumbTip),
              let index = try? obs.recognizedPoint(.indexTip),
              thumb.confidence > 0.3, index.confidence > 0.3 else { return false }
        return hypot(thumb.location.x - index.location.x, thumb.location.y - index.location.y) < 0.06
    }

    private func countExtendedFingers(_ obs: VNHumanHandPoseObservation) -> Int {
        var count = 0
        let pairs: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
            (.indexTip, .indexPIP), (.middleTip, .middlePIP),
            (.ringTip, .ringPIP), (.littleTip, .littlePIP)
        ]
        for (tip, pip) in pairs {
            if let t = try? obs.recognizedPoint(tip), let p = try? obs.recognizedPoint(pip),
               t.confidence > 0.3, p.confidence > 0.3, t.location.y > p.location.y {
                count += 1
            }
        }
        return count
    }

    private func isThumbPinky(_ obs: VNHumanHandPoseObservation) -> Bool {
        // Thumb and pinky extended, other fingers closed
        guard let thumbTip = try? obs.recognizedPoint(.thumbTip),
              let thumbIP = try? obs.recognizedPoint(.thumbIP),
              let littleTip = try? obs.recognizedPoint(.littleTip),
              let littlePIP = try? obs.recognizedPoint(.littlePIP),
              let indexTip = try? obs.recognizedPoint(.indexTip),
              let indexPIP = try? obs.recognizedPoint(.indexPIP),
              let middleTip = try? obs.recognizedPoint(.middleTip),
              let middlePIP = try? obs.recognizedPoint(.middlePIP),
              thumbTip.confidence > 0.3, littleTip.confidence > 0.3 else { return false }

        let pinkyExtended = littleTip.location.y > littlePIP.location.y
        let indexClosed = indexTip.location.y <= indexPIP.location.y
        let middleClosed = middleTip.location.y <= middlePIP.location.y
        let thumbExtended = hypot(thumbTip.location.x - thumbIP.location.x,
                                  thumbTip.location.y - thumbIP.location.y) > 0.03

        return thumbExtended && pinkyExtended && indexClosed && middleClosed
    }

    private func resetLeftGesture() {
        leftGestureValue = -1
        leftGestureStartTime = nil
        leftGestureFired = false
    }

    private func fireGesture(_ value: Int) {
        switch value {
        case -2: pressKey(keyCode: UInt16(kVK_Escape))
        case 0: pressKey(keyCode: UInt16(kVK_Return))
        case 1: pressKey(keyCode: UInt16(kVK_ANSI_1))
        case 2: pressKey(keyCode: UInt16(kVK_ANSI_2))
        case 3: pressKey(keyCode: UInt16(kVK_ANSI_3))
        default: break
        }
    }

    private func pressKey(keyCode: UInt16) {
        DispatchQueue.main.async {
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }
            down.post(tap: .cghidEventTap)
            usleep(30000)
            up.post(tap: .cghidEventTap)
        }
    }

    private func performClick() {
        DispatchQueue.main.async {
            guard let pos = CGEvent(source: nil)?.location else { return }
            NSLog("iGest: CLICK at (\(Int(pos.x)), \(Int(pos.y)))")
            guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left),
                  let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left) else { return }
            down.post(tap: .cghidEventTap)
            usleep(50000)
            up.post(tap: .cghidEventTap)
        }
    }
}
