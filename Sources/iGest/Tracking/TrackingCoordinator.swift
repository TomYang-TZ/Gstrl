import Foundation
import Vision
import Carbon.HIToolbox

final class TrackingCoordinator {
    private let cameraManager = CameraManager()
    private let appState: AppState
    private let swipeDetector = SwipeDetector()
    private let deleteController = DeleteController()
    private let speechController = SpeechController()
    private let cursorDrag = CursorDragController()
    private let scrollController = ScrollController()
    private var lastClickTime: Date = .distantPast

    // Left hand gesture hold detection
    private var leftGestureStartTime: Date?
    private var leftGestureValue: Int = -1
    private var leftGestureFired: Bool = false
    private let holdDuration: TimeInterval = 1.0
    private var leftHandEntryFrames: Int = 0
    private let handEntryGraceFrames: Int = 5

    // Crossed fingers (X) = Ctrl+C
    private var fingersCrossedStartTime: Date?
    private var fingersCrossedCount: Int = 0

    // UI label management
    private var rightHandLabelActive: Bool = false
    private var rightHandLabelUntil: Date = .distantPast

    init(appState: AppState) {
        self.appState = appState

        cameraManager.onFrame = { [weak self] pixelBuffer in
            self?.processFrame(pixelBuffer)
        }

        swipeDetector.onSwipe = { [weak self] direction, leftOpen in
            self?.handleSwipe(direction, leftOpen: leftOpen)
        }

        deleteController.onKeyPress = { keyCode, shift, control, option, command in
            InputDispatch.perform(.pressModifiedKey(keyCode, shift: shift, control: control, option: option, command: command))
        }

        speechController.onLabelUpdate = { [weak self] label in
            DispatchQueue.main.async { self?.appState.gestureLabel = label }
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
            cursorDrag.reset()
            return
        }

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

        let lFingers = leftHand != nil ? GestureClassifier.countExtendedFingers(leftHand!) : 0
        let rFingers = rightHand != nil ? GestureClassifier.countExtendedFingers(rightHand!) : 0

        DispatchQueue.main.async { [weak self] in
            self?.appState.handsCount = results.count
            self?.appState.leftHandDetected = leftHand != nil
            self?.appState.rightHandDetected = rightHand != nil
            self?.appState.debugInfo = leftHand != nil || rightHand != nil
                ? "L:\(lFingers)f R:\(rFingers)f" : ""
        }

        // === CROSSED INDEX FINGERS (X) = Ctrl+C ×2 ===
        if let lh = leftHand, let rh = rightHand, GestureClassifier.isFingersCrossed(lh, rh) {
            if fingersCrossedStartTime == nil {
                fingersCrossedStartTime = Date()
                fingersCrossedCount = 0
            }
            let elapsed = Date().timeIntervalSince(fingersCrossedStartTime!)

            if fingersCrossedCount == 0 {
                let progress = min(1.0, elapsed / holdDuration)
                DispatchQueue.main.async { [weak self] in
                    self?.appState.progressMode = .countdown
                    self?.appState.gestureLabel = "✕ Cancel"
                    self?.appState.gestureProgress = progress
                }
                if elapsed >= holdDuration {
                    fingersCrossedCount = 1
                    InputDispatch.perform(.pressModifiedKey(UInt16(kVK_ANSI_C), shift: false, control: true, option: false, command: false))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        InputDispatch.perform(.pressModifiedKey(UInt16(kVK_ANSI_C), shift: false, control: true, option: false, command: false))
                    }
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.gestureLabel = "✕ Ctrl+C ×2"
                        self?.appState.gestureProgress = 0
                    }
                    startCooldownProgress()
                }
            }
            return
        } else {
            fingersCrossedStartTime = nil
            fingersCrossedCount = 0
        }

        // === LEFT PINCH + RIGHT FIST = scroll ===
        let rightFist = rightHand != nil && GestureClassifier.countExtendedFingers(rightHand!) == 0
            && !GestureClassifier.isPinching(rightHand!) && !GestureClassifier.isThumbPinky(rightHand!)
        let scrollActive = leftHand != nil && rightFist && GestureClassifier.isPinching(leftHand!)

        if scrollActive {
            cursorDrag.reset()
            scrollController.process(leftHand!)
            DispatchQueue.main.async { [weak self] in
                self?.appState.trackingState = .pinching
                self?.appState.gestureLabel = "↕ Scroll"
                self?.appState.gestureProgress = 0
            }
            return
        } else {
            scrollController.reset()
        }

        // === BOTH HANDS 🤙 = aggressive delete ===
        let bothThumbPinky = leftHand != nil && rightHand != nil
            && GestureClassifier.isThumbPinky(leftHand!) && GestureClassifier.isThumbPinky(rightHand!)

        if bothThumbPinky {
            if let status = deleteController.processBothHands() {
                DispatchQueue.main.async { [weak self] in
                    self?.appState.progressMode = status.progressMode
                    self?.appState.gestureLabel = status.label
                    self?.appState.gestureProgress = status.progress
                }
            }
            return
        } else {
            deleteController.resetBothHands()
        }

        // === SPEECH: both hands open ===
        let bothOpen = leftHand != nil && rightHand != nil
            && GestureClassifier.countExtendedFingers(leftHand!) >= 4
            && GestureClassifier.countExtendedFingers(rightHand!) >= 4
            && !GestureClassifier.isPinching(leftHand!) && !GestureClassifier.isPinching(rightHand!)

        if bothOpen {
            let status = speechController.process()
            DispatchQueue.main.async { [weak self] in
                self?.appState.progressMode = status.progressMode
                self?.appState.gestureLabel = status.label
                self?.appState.gestureProgress = status.progress
            }
            return
        } else {
            if speechController.isActive {
                speechController.reset()
                DispatchQueue.main.async { [weak self] in
                    self?.appState.gestureLabel = ""
                    self?.appState.gestureProgress = 0
                }
            } else {
                speechController.reset()
            }
        }

        // === RIGHT HAND ===
        if let rh = rightHand {
            let rThumbPinky = GestureClassifier.isThumbPinky(rh) && leftHand == nil

            if GestureClassifier.isPinching(rh) {
                deleteController.reset()
                swipeDetector.resetEntryFrames()
                swipeDetector.reset()
                let leftPinching = leftHand != nil && GestureClassifier.isPinching(leftHand!)
                cursorDrag.process(rh, holdingClick: leftPinching)
                if leftPinching {
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.gestureLabel = "🔀 Drag"
                    }
                }
            } else if rThumbPinky {
                cursorDrag.reset()
                swipeDetector.reset()
                rightHandLabelActive = true
                if let status = deleteController.processSingleHand() {
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.progressMode = status.progressMode
                        self?.appState.gestureLabel = status.label
                        self?.appState.gestureProgress = status.progress
                    }
                }
            } else {
                deleteController.reset()
                cursorDrag.reset()
                if Date() >= rightHandLabelUntil {
                    rightHandLabelActive = false
                }
                swipeDetector.process(rh, leftHand: leftHand)
            }
        } else {
            deleteController.reset()
            cursorDrag.reset()
            swipeDetector.reset()
            if Date() >= rightHandLabelUntil {
                rightHandLabelActive = false
            }
        }

        // === LEFT HAND ===
        if let lh = leftHand {
            leftHandEntryFrames += 1
            guard leftHandEntryFrames > handEntryGraceFrames else { return }

            if GestureClassifier.isTwoFingerPinch(lh) {
                resetLeftGesture()
                let now = Date()
                if now.timeIntervalSince(lastClickTime) > 0.5 {
                    lastClickTime = now
                    InputDispatch.perform(.rightClick)
                }
                DispatchQueue.main.async { [weak self] in
                    self?.appState.trackingState = .pinching
                    self?.appState.gestureLabel = "👆👆 Right Click"
                }
            } else if GestureClassifier.isPinching(lh) {
                resetLeftGesture()
                let rightIsPinching = rightHand != nil && GestureClassifier.isPinching(rightHand!)
                if rightIsPinching {
                    // Drag mode — don't fire click, right-hand section handles it
                } else {
                    let now = Date()
                    if now.timeIntervalSince(lastClickTime) > 0.5 {
                        lastClickTime = now
                        InputDispatch.perform(.click)
                    }
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.trackingState = .pinching
                        self?.appState.gestureLabel = "👆 Click"
                    }
                }
            } else {
                let fingerCount = GestureClassifier.countExtendedFingers(lh)

                let gestureValue: Int
                if rightHand != nil {
                    gestureValue = -1
                } else if GestureClassifier.isThumbPinky(lh) {
                    gestureValue = -2
                } else if fingerCount >= 4 {
                    gestureValue = -1
                } else if fingerCount == 0 {
                    gestureValue = 0
                } else {
                    gestureValue = fingerCount
                }

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

                if gestureValue == -1 {
                    resetLeftGesture()
                } else if gestureValue == leftGestureValue {
                    if !leftGestureFired, let start = leftGestureStartTime {
                        let elapsed = Date().timeIntervalSince(start)
                        let progress = min(1.0, elapsed / holdDuration)
                        DispatchQueue.main.async { [weak self] in
                            self?.appState.progressMode = .countdown
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
            leftHandEntryFrames = 0
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

    private func resetLeftGesture() {
        leftGestureValue = -1
        leftGestureStartTime = nil
        leftGestureFired = false
    }

    private func fireGesture(_ value: Int) {
        switch value {
        case -2: InputDispatch.perform(.pressKey(UInt16(kVK_Escape)))
        case 0: InputDispatch.perform(.pressKey(UInt16(kVK_Return)))
        case 1: InputDispatch.perform(.pressKey(UInt16(kVK_ANSI_1)))
        case 2: InputDispatch.perform(.pressKey(UInt16(kVK_ANSI_2)))
        case 3: InputDispatch.perform(.pressKey(UInt16(kVK_ANSI_3)))
        default: break
        }
    }

    private func handleSwipe(_ direction: SwipeDetector.SwipeDirection, leftOpen: Bool) {
        rightHandLabelActive = true
        startCooldownProgress()

        switch direction {
        case .left:
            if leftOpen {
                InputDispatch.perform(.pressModifiedKey(UInt16(kVK_Tab), shift: true, control: false, option: false, command: false))
                DispatchQueue.main.async { [weak self] in self?.appState.gestureLabel = "← Shift+Tab" }
            } else {
                InputDispatch.perform(.pressKey(UInt16(kVK_LeftArrow)))
                DispatchQueue.main.async { [weak self] in self?.appState.gestureLabel = "← Left" }
            }
        case .right:
            if leftOpen {
                InputDispatch.perform(.pressKey(UInt16(kVK_Tab)))
                DispatchQueue.main.async { [weak self] in self?.appState.gestureLabel = "→ Tab" }
            } else {
                InputDispatch.perform(.pressKey(UInt16(kVK_RightArrow)))
                DispatchQueue.main.async { [weak self] in self?.appState.gestureLabel = "→ Right" }
            }
        case .up:
            InputDispatch.perform(.pressKey(UInt16(kVK_UpArrow)))
            DispatchQueue.main.async { [weak self] in self?.appState.gestureLabel = "↑ Up" }
        case .down:
            InputDispatch.perform(.pressKey(UInt16(kVK_DownArrow)))
            DispatchQueue.main.async { [weak self] in self?.appState.gestureLabel = "↓ Down" }
        }
    }

    private func startCooldownProgress() {
        let startTime = Date()
        let duration: TimeInterval = 1.0
        rightHandLabelUntil = startTime.addingTimeInterval(duration)
        DispatchQueue.main.async { [weak self] in
            self?.appState.progressMode = .cooldown
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

}
