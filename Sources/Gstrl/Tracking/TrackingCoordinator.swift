import Foundation
import Vision
import AppKit
import Carbon.HIToolbox

final class TrackingCoordinator {
    private let cameraManager = CameraManager()
    private let appState: AppState
    private let swipeDetector = SwipeDetector()
    private let deleteController = DeleteController()
    private let speechController = SpeechController()
    private let agentController = AgentController()
    private let cursorDrag = CursorDragController()
    private let scrollController = ScrollController()
    private var lastClickTime: Date = .distantPast

    // Left hand gesture hold detection
    private var leftGestureStartTime: Date?
    private var leftGestureValue: Int = -1
    private var leftGestureStableFrames: Int = 0
    private let stableFramesRequired: Int = 3
    private let holdDuration: TimeInterval = 1.0
    private var leftHandEntryFrames: Int = 0
    private var rightHandEntryFrames: Int = 0
    private let handEntryGraceFrames: Int = 15

    // Crossed fingers (X) = Ctrl+C
    private var fingersCrossedStartTime: Date?
    private var fingersCrossedCount: Int = 0

    // Scroll countdown
    private var scrollStartTime: Date?

    // Left pinch timing (short = click, long = right click)
    private var leftPinchStartTime: Date?
    private var leftPinchFired: Bool = false

    // Cache to avoid redundant AppState writes
    private var cachedLeft = false
    private var cachedRight = false
    private var cachedDebug = ""
    private var cachedLabel = ""

    private let countdownDelay: TimeInterval = 0.15

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

        speechController.onTranscriptUpdate = { [weak self] text in
            DispatchQueue.main.async { self?.appState.speechTranscript = text }
        }

        agentController.onStateChanged = { [weak self] (label: String, progress: Double, mode: AppState.ProgressMode) in
            DispatchQueue.main.async {
                self?.appState.gestureLabel = label
                self?.appState.gestureProgress = progress
                self?.appState.progressMode = mode
                if label.contains("Thinking") || label.contains("Listening") {
                    self?.appState.agentActive = true
                    self?.appState.agentSilenceStart = nil
                    self?.appState.agentResponse = ""
                }
                if label.isEmpty {
                    self?.appState.agentActive = false
                    self?.appState.agentSilenceStart = nil
                }
            }
        }

        agentController.onTranscriptUpdate = { [weak self] (text: String) in
            DispatchQueue.main.async {
                self?.appState.agentTranscript = text
            }
        }

        agentController.onSilenceReset = { [weak self] in
            DispatchQueue.main.async {
                self?.appState.agentSilenceStart = Date()
            }
        }

        agentController.onSpeakingChanged = { [weak self] (speaking: Bool) in
            DispatchQueue.main.async {
                self?.appState.agentSpeaking = speaking
            }
        }

        agentController.onSelectionCaptured = { [weak self] (lineCount: Int) in
            DispatchQueue.main.async {
                self?.appState.agentSelectedLines = lineCount
            }
        }

        agentController.onThinkingUpdate = { [weak self] (text: String) in
            DispatchQueue.main.async {
                self?.appState.agentThinking = text
                self?.appState.agentCurrentAction = ""
            }
        }

        agentController.onActionUpdate = { [weak self] (tool: String, summary: String) in
            DispatchQueue.main.async {
                self?.appState.agentThinking = ""
                self?.appState.agentCurrentAction = summary.isEmpty ? tool : "\(tool) \(summary)"
            }
        }

        agentController.onResponse = { [weak self] (query: String, response: String, screenshotPath: String?, durationMs: Int, turns: Int, costUSD: Double, actions: [(tool: String, summary: String)]) in
            DispatchQueue.main.async {
                guard let self else { return }
                let sid = self.agentController.sessionId ?? UUID().uuidString
                self.appState.agentActive = false
                self.appState.agentResponse = response
                self.appState.agentTranscript = ""
                let agentActions = actions.map { AppState.AgentAction(tool: $0.tool, summary: $0.summary) }
                self.appState.agentHistory.append(AppState.AgentEntry(
                    sessionId: sid, query: query, response: response,
                    screenshotPath: screenshotPath,
                    durationMs: durationMs, turns: turns, costUSD: costUSD,
                    actions: agentActions
                ))
                self.appState.gestureLabel = "🤖 Done"
                self.appState.gestureProgress = 0
                self.appState.agentSelectedLines = 0
                self.appState.agentThinking = ""
                self.appState.agentCurrentAction = ""
            }
        }

        cursorDrag.onCircleScreenshot = { [weak self] rect in
            let tmpFile = "/tmp/gstrl-preview-\(ProcessInfo.processInfo.processIdentifier).png"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            let r = "\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.width)),\(Int(rect.height))"
            process.arguments = ["-R", r, tmpFile]
            try? process.run()
            process.waitUntilExit()

            guard let image = NSImage(contentsOfFile: tmpFile) else { return }

            DispatchQueue.main.async {
                self?.appState.gestureLabel = "📸 Captured"
                self?.appState.gestureProgress = 0
                self?.appState.screenshotPreview = image
            }

            // Copy to clipboard and dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.writeObjects([image])
                self?.appState.screenshotPreview = nil
                self?.appState.gestureLabel = "📸 Copied"
                try? FileManager.default.removeItem(atPath: tmpFile)
            }
            self?.startCooldownProgress()
        }
    }

    func start() {
        syncSettings()
        cameraManager.start()
    }

    func syncSettings() {
        cameraManager.updateFPS(appState.fps.timescale)
        cursorDrag.sensitivity = appState.cursorSensitivity
        scrollController.sensitivityMultiplier = appState.scrollSensitivity
        scrollController.naturalScroll = appState.naturalScroll
        speechController.updateLocale(appState.speechLanguage.localeIdentifier)
        agentController.updateLocale(appState.speechLanguage.localeIdentifier)
    }

    func stop() {
        cameraManager.stop()
    }

    func clearAgentSession() {
        agentController.clearSession()
    }

    func stopSpeaking() {
        agentController.stopSpeaking()
    }

    func terminateAgent() {
        agentController.terminateAgent()
        DispatchQueue.main.async { [weak self] in
            self?.appState.agentActive = false
            self?.appState.agentResponse = ""
            self?.appState.agentTranscript = ""
            self?.appState.agentThinking = ""
            self?.appState.agentCurrentAction = ""
            self?.appState.gestureLabel = ""
        }
    }

    func emergencyKill() {
        stop()
        DispatchQueue.main.async { [weak self] in
            self?.appState.isEnabled = false
        }
    }

    private func setLabel(_ label: String) {
        guard label != cachedLabel else { return }
        cachedLabel = label
        DispatchQueue.main.async { [weak self] in
            self?.appState.gestureLabel = label
            if label.isEmpty {
                self?.appState.gestureCountdownStart = nil
            }
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
            let agentBusy = agentController.isActive || agentController.isProcessing
            DispatchQueue.main.async { [weak self] in
                self?.appState.trackingState = .inactive
                self?.appState.handsCount = 0
                self?.appState.leftHandDetected = false
                self?.appState.rightHandDetected = false
                if !agentBusy {
                    self?.appState.gestureLabel = ""
                    self?.appState.gestureProgress = 0
                    self?.appState.gestureCountdownStart = nil
                }
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

        let newLeft = leftHand != nil
        let newRight = rightHand != nil
        let newDebug = newLeft || newRight ? "L:\(lFingers)f R:\(rFingers)f" : ""
        if newLeft != cachedLeft || newRight != cachedRight || newDebug != cachedDebug {
            cachedLeft = newLeft
            cachedRight = newRight
            cachedDebug = newDebug
            DispatchQueue.main.async { [weak self] in
                self?.appState.leftHandDetected = newLeft
                self?.appState.rightHandDetected = newRight
                self?.appState.debugInfo = newDebug
            }
        }

        // === GLOBAL COOLDOWN — no actions during cooldown ===
        if Date() < rightHandLabelUntil {
            return
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
                    self?.appState.gestureHand = .both
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
            && !GestureClassifier.isThumbPinky(rightHand!)
        let scrollActive = leftHand != nil && rightFist && GestureClassifier.isPinching(leftHand!)

        if scrollActive {
            cursorDrag.reset()
            scrollController.process(leftHand!)
            DispatchQueue.main.async { [weak self] in
                self?.appState.trackingState = .pinching
                self?.appState.gestureLabel = "↕ Scrolling"
            }
            return
        } else {
            scrollController.reset()
            scrollStartTime = nil
        }

        // === BOTH HANDS 🤙 = aggressive delete ===
        let bothThumbPinky = leftHand != nil && rightHand != nil
            && GestureClassifier.isThumbPinky(leftHand!) && GestureClassifier.isThumbPinky(rightHand!)

        if bothThumbPinky {
            if let status = deleteController.processBothHands() {
                let countdownStart = deleteController.bothHandsStartTime
                let holdDur = deleteController.holdDuration
                let elapsed = countdownStart.map { Date().timeIntervalSince($0) } ?? 0
                let showCountdown = elapsed < holdDur
                DispatchQueue.main.async { [weak self] in
                    self?.appState.progressMode = status.progressMode
                    self?.appState.gestureLabel = status.label
                    self?.appState.gestureProgress = status.progress
                    if showCountdown, let start = countdownStart {
                        self?.appState.gestureCountdownStart = start
                        self?.appState.gestureCountdownDuration = holdDur
                    } else {
                        self?.appState.gestureCountdownStart = nil
                    }
                }
            }
            return
        } else {
            deleteController.resetBothHands()
        }

        // === AGENT: both fists ===
        let bothFists = leftHand != nil && rightHand != nil
            && rightHandEntryFrames > handEntryGraceFrames
            && GestureClassifier.countExtendedFingers(leftHand!) == 0
            && GestureClassifier.countExtendedFingers(rightHand!) == 0
            && !GestureClassifier.isThumbPinky(leftHand!) && !GestureClassifier.isThumbPinky(rightHand!)

        if bothFists {
            speechController.reset()
            agentController.stopSpeaking()
            let status = agentController.process()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.appState.progressMode = status.progressMode
                self.appState.gestureLabel = status.label
                self.appState.agentActive = status.activated
                self.appState.agentResponse = ""
                if !status.activated, let start = self.agentController.startTime {
                    self.appState.gestureCountdownStart = start
                    self.appState.gestureCountdownDuration = 1.0
                }
            }
            return
        } else {
            if agentController.isActive || agentController.isProcessing {
                agentController.handsReleased()
                return
            }
            agentController.reset()
        }

        // Right hand grace period
        if rightHand != nil {
            rightHandEntryFrames += 1
        } else {
            rightHandEntryFrames = 0
        }

        // === RIGHT FIST ONLY → Speech ===
        let rightFistOnly = rightHand != nil && leftHand == nil
            && rightHandEntryFrames > handEntryGraceFrames
            && GestureClassifier.countExtendedFingers(rightHand!) == 0
            && !GestureClassifier.isThumbPinky(rightHand!)

        if rightFistOnly {
            deleteController.reset()
            cursorDrag.reset()
            swipeDetector.reset()
            let status = speechController.process()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.appState.progressMode = status.progressMode
                if !status.activated, let start = self.speechController.startTime {
                    self.appState.gestureCountdownStart = start
                    self.appState.gestureCountdownDuration = 1.0
                } else if status.activated {
                    self.appState.gestureCountdownStart = nil
                }
                if Date() > self.speechController.commandFlashUntil {
                    self.appState.gestureLabel = status.label
                }
            }
            return
        }

        // === RIGHT HAND ===
        if let rh = rightHand {
            let rThumbPinky = GestureClassifier.isThumbPinky(rh) && leftHand == nil

            if rThumbPinky {
                cursorDrag.reset()
                speechController.reset()
                swipeDetector.reset()
                rightHandLabelActive = true
                if let status = deleteController.processSingleHand() {
                    let showCountdown = !deleteController.fired
                    let countdownStart = deleteController.startTime
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.progressMode = status.progressMode
                        self?.appState.gestureLabel = status.label
                        self?.appState.gestureProgress = status.progress
                        if showCountdown, let start = countdownStart {
                            self?.appState.gestureCountdownStart = start
                            self?.appState.gestureCountdownDuration = 1.0
                        } else {
                            self?.appState.gestureCountdownStart = nil
                        }
                    }
                }
            } else if GestureClassifier.isPinching(rh) {
                deleteController.reset()
                speechController.reset()
                swipeDetector.resetEntryFrames()
                swipeDetector.reset()
                DispatchQueue.main.async { [weak self] in self?.appState.gestureCountdownStart = nil }
                let leftPinching = leftHand != nil && GestureClassifier.isPinching(leftHand!)
                cursorDrag.process(rh, holdingClick: leftPinching)
                if leftPinching {
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.gestureLabel = "🔀 Drag"
                    }
                }
            } else {
                deleteController.reset()
                cursorDrag.reset()
                speechController.reset()
                DispatchQueue.main.async { [weak self] in self?.appState.gestureCountdownStart = nil }
                if Date() >= rightHandLabelUntil {
                    rightHandLabelActive = false
                }

                swipeDetector.process(rh, leftHand: leftHand)
            }
        } else {
            deleteController.reset()
            cursorDrag.reset()
            swipeDetector.reset()
            speechController.reset()
            DispatchQueue.main.async { [weak self] in self?.appState.gestureCountdownStart = nil }
            if Date() >= rightHandLabelUntil {
                rightHandLabelActive = false
            }
        }

        // === LEFT HAND ===
        if let lh = leftHand {
            leftHandEntryFrames += 1
            guard leftHandEntryFrames > handEntryGraceFrames else { return }

            if GestureClassifier.isPinching(lh) {
                let rightIsPinching = rightHand != nil && GestureClassifier.isPinching(rightHand!)
                let rightPresent = rightHand != nil
                if rightIsPinching {
                    // Drag mode — don't fire click, right-hand section handles it
                    leftPinchStartTime = nil
                    leftPinchFired = true
                    resetLeftGesture()
                } else if rightPresent {
                    // Right hand present + left pinch hold = right click
                    if leftPinchStartTime == nil {
                        leftPinchStartTime = Date()
                    }
                    let elapsed = Date().timeIntervalSince(leftPinchStartTime!)
                    let longPinchDuration: TimeInterval = 1.0

                    if elapsed < longPinchDuration {
                        DispatchQueue.main.async { [weak self] in
                            self?.appState.trackingState = .pinching
                            self?.appState.progressMode = .countdown
                            self?.appState.gestureLabel = "👆 Hold → Right Click"
                            self?.appState.gestureCountdownStart = self?.leftPinchStartTime
                            self?.appState.gestureCountdownDuration = longPinchDuration
                        }
                    } else if !leftPinchFired {
                        leftPinchFired = true
                        InputDispatch.perform(.rightClick)
                        DispatchQueue.main.async { [weak self] in
                            self?.appState.gestureLabel = "👆 Right Click"
                            self?.appState.gestureCountdownStart = nil
                        }
                        startCooldownProgress()
                    }
                } else {
                    // Left pinch only (no right hand) — track for click on release
                    if leftPinchStartTime == nil {
                        leftPinchStartTime = Date()
                    }
                }
            } else {
                // Pinch released — fire left click if it was short
                if let start = leftPinchStartTime, !leftPinchFired {
                    let elapsed = Date().timeIntervalSince(start)
                    if elapsed < 0.5 {
                        let now = Date()
                        if now.timeIntervalSince(lastClickTime) > 0.3 {
                            lastClickTime = now
                            InputDispatch.perform(.click)
                            DispatchQueue.main.async { [weak self] in
                                self?.appState.gestureLabel = "👆 Click"
                            }
                        }
                    }
                }
                leftPinchStartTime = nil
                leftPinchFired = false
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
                        self?.appState.gestureCountdownStart = nil
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
                    leftGestureStableFrames += 1
                    guard leftGestureStableFrames >= stableFramesRequired else { return }
                    if let start = leftGestureStartTime {
                        let elapsed = Date().timeIntervalSince(start)
                        if elapsed >= holdDuration {
                            fireGesture(gestureValue)
                            leftGestureStartTime = Date()
                        } else {
                            DispatchQueue.main.async { [weak self] in
                                self?.appState.progressMode = .countdown
                                self?.appState.gestureCountdownStart = start
                                self?.appState.gestureCountdownDuration = self?.holdDuration ?? 1.0
                            }
                        }
                    }
                } else {
                    leftGestureValue = gestureValue
                    leftGestureStableFrames = 0
                    leftGestureStartTime = Date()
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.gestureCountdownStart = nil
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
                self?.appState.gestureCountdownStart = nil
            }
        }
    }

    // MARK: - Helpers


    private func resetLeftGesture() {
        leftGestureValue = -1
        leftGestureStartTime = nil
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
        startCooldownProgress()
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
        let duration: TimeInterval = 1.0
        rightHandLabelUntil = Date().addingTimeInterval(duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.rightHandLabelActive = false
            self?.appState.gestureLabel = ""
            self?.appState.gestureCountdownStart = nil
        }
    }

}
