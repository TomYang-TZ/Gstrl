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

    // Right hand 🤙 (thumb+pinky) = Delete (repeats with acceleration)
    private var rightDeleteStartTime: Date?
    private var rightDeleteFired: Bool = false
    private var rightDeleteLastRepeat: Date = .distantPast
    private var deleteRepeatCount: Int = 0

    // Left hand gesture hold detection
    private var leftGestureStartTime: Date?
    private var leftGestureValue: Int = -1
    private var leftGestureFired: Bool = false
    private let holdDuration: TimeInterval = 1.0

    // Wave detection
    private var wavePositions: [(x: CGFloat, time: Date)] = []
    private var lastWaveTime: Date = .distantPast

    // Right hand swipe detection (velocity-based)
    private var rightIndexPrev: (pos: CGPoint, time: Date)?
    private var lastSwipeTime: Date = .distantPast
    private let swipeCooldown: TimeInterval = 1.0
    private let velocityThreshold: CGFloat = 0.6  // normalized units per second
    private var swipeReturnIgnoreUntil: Date = .distantPast
    private var rightHandLabelActive: Bool = false
    private var rightHandLabelUntil: Date = .distantPast
    private var swipeVelocityAccum: CGPoint = .zero
    private var swipeAccumFrames: Int = 0

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

        let lFingers = leftHand != nil ? countExtendedFingers(leftHand!) : 0
        let rFingers = rightHand != nil ? countExtendedFingers(rightHand!) : 0

        DispatchQueue.main.async { [weak self] in
            self?.appState.handsCount = results.count
            self?.appState.leftHandDetected = leftHand != nil
            self?.appState.rightHandDetected = rightHand != nil
            self?.appState.debugInfo = leftHand != nil || rightHand != nil
                ? "L:\(lFingers)f R:\(rFingers)f" : ""
        }

        // === SPEECH: both hands open (5 fingers) = start ===
        let bothOpen = leftHand != nil && rightHand != nil
            && countExtendedFingers(leftHand!) >= 4 && countExtendedFingers(rightHand!) >= 4
            && !isPinching(leftHand!) && !isPinching(rightHand!)

        let speechHoldDuration: TimeInterval = 1.0

        if bothOpen {
            if bothFistsStartTime == nil { bothFistsStartTime = Date() }
            if let start = bothFistsStartTime {
                let elapsed = Date().timeIntervalSince(start)
                if !speechActive {
                    let progress = min(1.0, elapsed / speechHoldDuration)
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.gestureLabel = "🎤 Speech"
                        self?.appState.gestureProgress = progress
                    }
                }
                if elapsed >= speechHoldDuration && !speechActive {
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
                        self?.appState.gestureProgress = 0
                    }
                }
            }
            return
        } else {
            if bothFistsStartTime != nil || speechActive {
                bothFistsStartTime = nil
                if speechActive {
                    speechActive = false
                    speechEngine.stopListening()
                }
                DispatchQueue.main.async { [weak self] in
                    self?.appState.gestureLabel = ""
                    self?.appState.gestureProgress = 0
                }
            }
        }

        // === RIGHT HAND: pinch to drag, 🤙 to delete, open hand swipe for nav ===
        if let rh = rightHand {
            let rThumbPinky = isThumbPinky(rh) && leftHand == nil

            if isPinching(rh) {
                rightIndexPrev = nil
                swipeVelocityAccum = .zero
                swipeAccumFrames = 0
                rightDeleteStartTime = nil
                rightDeleteFired = false
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
            } else if rThumbPinky {
                rightHandAnchor = nil
                cursorAnchor = nil
                rightIndexPrev = nil
                swipeVelocityAccum = .zero
                swipeAccumFrames = 0
                rightHandLabelActive = true
                if rightDeleteStartTime == nil {
                    rightDeleteStartTime = Date()
                }
                let now = Date()
                if !rightDeleteFired, let start = rightDeleteStartTime {
                    let elapsed = now.timeIntervalSince(start)
                    let progress = min(1.0, elapsed / holdDuration)
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.gestureLabel = "🗑 Delete"
                        self?.appState.gestureProgress = progress
                    }
                    if elapsed >= holdDuration {
                        rightDeleteFired = true
                        rightDeleteLastRepeat = now
                        deleteRepeatCount = 0
                        pressKey(keyCode: UInt16(kVK_Delete))
                        DispatchQueue.main.async { [weak self] in
                            self?.appState.gestureLabel = "🗑 Delete..."
                            self?.appState.gestureProgress = 0
                        }
                    }
                } else if rightDeleteFired {
                    let elapsed = now.timeIntervalSince(rightDeleteStartTime ?? now)
                    let interval: TimeInterval
                    let deleteType: Int // 0=char, 1=word, 2=line

                    if elapsed < 5.0 {
                        // Phase 1: char by char, accelerate 0.5→0.1
                        interval = max(0.1, 0.5 - Double(deleteRepeatCount) * 0.1)
                        deleteType = 0
                    } else if elapsed < 8.0 {
                        // Phase 2: word by word
                        interval = 0.3
                        deleteType = 1
                    } else if elapsed < 11.0 {
                        // Phase 3: line by line
                        interval = 0.4
                        deleteType = 2
                    } else {
                        // Phase 4: select all + delete
                        interval = 0.5
                        deleteType = 3
                    }

                    if now.timeIntervalSince(rightDeleteLastRepeat) >= interval {
                        rightDeleteLastRepeat = now
                        deleteRepeatCount += 1
                        switch deleteType {
                        case 3:
                            // Select all + delete
                            pressKeyWithModifiers(keyCode: UInt16(kVK_ANSI_A), command: true)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                                self?.pressKey(keyCode: UInt16(kVK_Delete))
                            }
                        case 2:
                            pressKeyWithModifiers(keyCode: UInt16(kVK_Delete), command: true)
                        case 1:
                            pressKeyWithModifiers(keyCode: UInt16(kVK_Delete), option: true)
                        default:
                            pressKey(keyCode: UInt16(kVK_Delete))
                        }
                        DispatchQueue.main.async { [weak self] in
                            let label = deleteType == 3 ? "🗑 ALL" : deleteType == 2 ? "🗑 Line..." : deleteType == 1 ? "🗑 Word..." : "🗑 Delete..."
                            self?.appState.gestureLabel = label
                        }
                    }
                }
            } else {
                rightHandAnchor = nil
                cursorAnchor = nil
                rightDeleteStartTime = nil
                rightDeleteFired = false
                if Date() >= rightHandLabelUntil {
                    rightHandLabelActive = false
                }
                detectSwipe(rh, leftHand: leftHand)
            }
        } else {
            rightHandAnchor = nil
            cursorAnchor = nil
            rightIndexPrev = nil
            swipeVelocityAccum = .zero
            swipeAccumFrames = 0
            rightDeleteStartTime = nil
            rightDeleteFired = false
            if Date() >= rightHandLabelUntil {
                rightHandLabelActive = false
            }
        }

        // === LEFT HAND ===
        if let lh = leftHand {
            // Pinch = click (only when right hand is NOT detected)
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
                if rightHand != nil {
                    // Both hands detected — left hand hold gestures disabled
                    // (left open + right swipe combo still works via detectSwipe)
                    gestureValue = -1  // idle
                } else if isThumbPinky(lh) {
                    gestureValue = -2  // Escape (🤙)
                } else if fingerCount >= 4 {
                    gestureValue = -1  // idle
                } else if fingerCount == 0 {
                    gestureValue = 0   // Enter (fist)
                } else {
                    gestureValue = fingerCount  // 1-3
                }

                // Update label (don't overwrite if swipe label is still showing)
                let rightLabelActive = self.rightHandLabelActive
                DispatchQueue.main.async { [weak self] in
                    self?.appState.trackingState = .tracking
                    if rightLabelActive { return }
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
            let rightLabelActive = self.rightHandLabelActive
            DispatchQueue.main.async { [weak self] in
                self?.appState.trackingState = .inactive
                if rightLabelActive { return }
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

    // MARK: - Swipe Detection

    private func detectSwipe(_ obs: VNHumanHandPoseObservation, leftHand: VNHumanHandPoseObservation?) {
        let leftOpen = leftHand != nil && countExtendedFingers(leftHand!) >= 4

        // Only allow swipes when: no left hand, or left hand is open (for Tab combo)
        // Block swipes when left hand is doing something else (fist, fingers, etc.)
        if leftHand != nil && !leftOpen { return }

        // Use wrist as fallback anchor — index tip confidence drops during fast downward motion
        guard let indexTip = try? obs.recognizedPoint(.indexTip),
              indexTip.confidence > 0.15 else { return }

        let now = Date()

        // After a swipe fires, ignore all motion for the cooldown period
        if now < swipeReturnIgnoreUntil {
            rightIndexPrev = nil
            swipeVelocityAccum = .zero
            swipeAccumFrames = 0
            return
        }

        let pos = CGPoint(x: indexTip.location.x, y: indexTip.location.y)

        defer { rightIndexPrev = (pos: pos, time: now) }

        guard let prev = rightIndexPrev else { return }
        let dt = now.timeIntervalSince(prev.time)
        guard dt > 0.001 && dt < 0.2 else {
            swipeVelocityAccum = .zero
            swipeAccumFrames = 0
            return
        }

        // Instantaneous velocity (normalized units per second)
        let vx = (pos.x - prev.pos.x) / CGFloat(dt)
        let vy = (pos.y - prev.pos.y) / CGFloat(dt)

        // Accumulate only if velocity is above a minimum (ignore slow wind-up)
        let speed = hypot(vx, vy)
        if speed < velocityThreshold * 0.4 {
            swipeVelocityAccum = .zero
            swipeAccumFrames = 0
            return
        }

        // Accumulate consistent direction frames
        if swipeAccumFrames > 0 {
            let dotProduct = vx * swipeVelocityAccum.x + vy * swipeVelocityAccum.y
            if dotProduct < 0 {
                // Direction reversed — reset
                swipeVelocityAccum = .zero
                swipeAccumFrames = 0
                return
            }
        }

        swipeVelocityAccum = CGPoint(x: swipeVelocityAccum.x + vx, y: swipeVelocityAccum.y + vy)
        swipeAccumFrames += 1

        // Need at least 2 consistent fast frames to trigger
        guard swipeAccumFrames >= 2 else { return }

        let avgVx = swipeVelocityAccum.x / CGFloat(swipeAccumFrames)
        let avgVy = swipeVelocityAccum.y / CGFloat(swipeAccumFrames)
        let absVx = abs(avgVx)
        let absVy = abs(avgVy)

        guard max(absVx, absVy) > velocityThreshold else { return }
        // Reject diagonal
        guard max(absVx, absVy) > min(absVx, absVy) * 1.5 else { return }
        guard now.timeIntervalSince(lastSwipeTime) > swipeCooldown else { return }

        // Block vertical swipes when left hand is open (only horizontal Tab allowed)
        if absVy > absVx && leftOpen { return }

        lastSwipeTime = now
        swipeVelocityAccum = .zero
        swipeAccumFrames = 0
        rightIndexPrev = nil
        swipeReturnIgnoreUntil = now.addingTimeInterval(swipeCooldown)
        rightHandLabelActive = true
        startSwipeCooldownProgress()

        if absVx > absVy {
            if leftOpen {
                // Left hand open + horizontal swipe = Tab navigation
                if avgVx > 0 {
                    pressKeyWithModifiers(keyCode: UInt16(kVK_Tab), shift: true)
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.gestureLabel = "← Shift+Tab"
                    }
                } else {
                    pressKey(keyCode: UInt16(kVK_Tab))
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.gestureLabel = "→ Tab"
                    }
                }
            } else {
                // Right hand only + horizontal swipe = arrow keys
                if avgVx > 0 {
                    pressKey(keyCode: UInt16(kVK_LeftArrow))
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.gestureLabel = "← Left"
                    }
                } else {
                    pressKey(keyCode: UInt16(kVK_RightArrow))
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.gestureLabel = "→ Right"
                    }
                }
            }
        } else if !leftOpen {
            // Vertical swipes only work with right hand alone
            if avgVy > 0 {
                pressKey(keyCode: UInt16(kVK_UpArrow))
                DispatchQueue.main.async { [weak self] in
                    self?.appState.gestureLabel = "↑ Up"
                }
            } else {
                pressKey(keyCode: UInt16(kVK_DownArrow))
                DispatchQueue.main.async { [weak self] in
                    self?.appState.gestureLabel = "↓ Down"
                }
            }
        }
    }

    private func startSwipeCooldownProgress() {
        let startTime = Date()
        let duration = swipeCooldown
        rightHandLabelUntil = startTime.addingTimeInterval(duration)
        DispatchQueue.main.async { [weak self] in
            self?.appState.gestureProgress = 1.0
        }
        func tick() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                let remaining = max(0, 1.0 - elapsed / duration)
                self.appState.gestureProgress = remaining
                if remaining > 0 {
                    tick()
                } else {
                    self.rightHandLabelActive = false
                    self.appState.gestureLabel = ""
                    self.appState.gestureProgress = 0
                }
            }
        }
        tick()
    }

    private func pressKeyWithModifiers(keyCode: UInt16, shift: Bool = false, control: Bool = false, option: Bool = false, command: Bool = false) {
        DispatchQueue.main.async {
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }
            var flags: CGEventFlags = []
            if shift { flags.insert(.maskShift) }
            if control { flags.insert(.maskControl) }
            if option { flags.insert(.maskAlternate) }
            if command { flags.insert(.maskCommand) }
            down.flags = flags
            up.flags = flags
            down.post(tap: .cghidEventTap)
            usleep(30000)
            up.post(tap: .cghidEventTap)
        }
    }
}
