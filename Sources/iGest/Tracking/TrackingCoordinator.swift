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

    // Left hand number/gesture hold detection
    private var leftGestureStartTime: Date?
    private var leftGestureValue: Int = -1  // -1 = none, 0 = fist, 1-4 = fingers
    private var leftGestureFired: Bool = false
    private let holdDuration: TimeInterval = 0.5

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

        guard let results = handRequest.results, !results.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.appState.trackingState = .inactive
                self?.appState.handsCount = 0
                self?.appState.leftHandDetected = false
                self?.appState.rightHandDetected = false
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

        DispatchQueue.main.async { [weak self] in
            self?.appState.handsCount = results.count
            self?.appState.leftHandDetected = leftHand != nil
            self?.appState.rightHandDetected = rightHand != nil
        }

        // === RIGHT HAND: pinch to drag cursor (relative) ===
        if let rh = rightHand {
            let rhPinching = isPinching(rh)

            if rhPinching {
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

        // === LEFT HAND: pinch = click, fingers = number, fist = enter ===
        if let lh = leftHand {
            if isPinching(lh) {
                // Pinch = click
                resetLeftGesture()
                let now = Date()
                if now.timeIntervalSince(lastClickTime) > 0.5 {
                    lastClickTime = now
                    performClick()
                }
                DispatchQueue.main.async { [weak self] in
                    self?.appState.trackingState = .pinching
                }
            } else {
                // Count extended fingers (excluding thumb)
                let fingerCount = countExtendedFingers(lh)
                let thumbUp = isThumbExtended(lh)

                DispatchQueue.main.async { [weak self] in
                    self?.appState.trackingState = .tracking
                    if fingerCount == 0 && !thumbUp {
                        self?.appState.debugInfo = "Left: FIST (hold for Enter)"
                    } else if thumbUp && fingerCount == 0 {
                        self?.appState.debugInfo = "Left: THUMB (hold for Esc)"
                    } else {
                        self?.appState.debugInfo = "Left: \(fingerCount) fingers (hold for '\(fingerCount)')"
                    }
                }

                // Determine gesture value
                let gestureValue: Int
                if thumbUp && fingerCount == 0 {
                    gestureValue = -2  // Escape
                } else if fingerCount == 0 && !thumbUp {
                    gestureValue = 0   // Enter (fist)
                } else {
                    gestureValue = fingerCount  // 1-4
                }

                // Hold detection
                if gestureValue == leftGestureValue {
                    if !leftGestureFired, let start = leftGestureStartTime {
                        if Date().timeIntervalSince(start) >= holdDuration {
                            leftGestureFired = true
                            fireGesture(gestureValue)
                        }
                    }
                } else {
                    leftGestureValue = gestureValue
                    leftGestureStartTime = Date()
                    leftGestureFired = false
                }
            }
        } else {
            resetLeftGesture()
            DispatchQueue.main.async { [weak self] in
                self?.appState.trackingState = .inactive
            }
        }
    }

    // MARK: - Gesture helpers

    private func isPinching(_ obs: VNHumanHandPoseObservation) -> Bool {
        guard let thumb = try? obs.recognizedPoint(.thumbTip),
              let index = try? obs.recognizedPoint(.indexTip),
              thumb.confidence > 0.3, index.confidence > 0.3 else { return false }
        let dist = hypot(thumb.location.x - index.location.x, thumb.location.y - index.location.y)
        return dist < 0.06
    }

    private func countExtendedFingers(_ obs: VNHumanHandPoseObservation) -> Int {
        var count = 0
        let pairs: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
            (.indexTip, .indexPIP),
            (.middleTip, .middlePIP),
            (.ringTip, .ringPIP),
            (.littleTip, .littlePIP)
        ]
        for (tip, pip) in pairs {
            if let t = try? obs.recognizedPoint(tip),
               let p = try? obs.recognizedPoint(pip),
               t.confidence > 0.3, p.confidence > 0.3 {
                if t.location.y > p.location.y {
                    count += 1
                }
            }
        }
        return count
    }

    private func isThumbExtended(_ obs: VNHumanHandPoseObservation) -> Bool {
        guard let thumbTip = try? obs.recognizedPoint(.thumbTip),
              let thumbIP = try? obs.recognizedPoint(.thumbIP),
              let wrist = try? obs.recognizedPoint(.wrist),
              thumbTip.confidence > 0.3 else { return false }
        // Thumb is extended if tip is far from wrist relative to IP
        let tipDist = hypot(thumbTip.location.x - wrist.location.x, thumbTip.location.y - wrist.location.y)
        let ipDist = hypot(thumbIP.location.x - wrist.location.x, thumbIP.location.y - wrist.location.y)
        return tipDist > ipDist * 1.3
    }

    private func resetLeftGesture() {
        leftGestureValue = -1
        leftGestureStartTime = nil
        leftGestureFired = false
    }

    // MARK: - Actions

    private func fireGesture(_ value: Int) {
        switch value {
        case -2:
            NSLog("iGest: ESCAPE")
            pressKey(keyCode: UInt16(kVK_Escape))
        case 0:
            NSLog("iGest: ENTER")
            pressKey(keyCode: UInt16(kVK_Return))
        case 1:
            NSLog("iGest: press '1'")
            pressKey(keyCode: UInt16(kVK_ANSI_1))
        case 2:
            NSLog("iGest: press '2'")
            pressKey(keyCode: UInt16(kVK_ANSI_2))
        case 3:
            NSLog("iGest: press '3'")
            pressKey(keyCode: UInt16(kVK_ANSI_3))
        case 4:
            NSLog("iGest: press '4'")
            pressKey(keyCode: UInt16(kVK_ANSI_4))
        default:
            break
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
