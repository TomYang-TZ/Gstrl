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
    private var noHandFrames: Int = 0
    private let handEntryGraceFrames: Int = 8

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

        agentController.onResponse = { [weak self] (query: String, response: String, screenshotPath: String?, selectedText: String?, durationMs: Int, turns: Int, costUSD: Double, actions: [(tool: String, summary: String)]) in
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
                    selectedLines: self.appState.agentSelectedLines,
                    selectedText: selectedText,
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

        let whip = (NSApp.delegate as? AppDelegate)?.whipOverlay
        cursorDrag.onCursorStart = { [weak self] in DispatchQueue.main.async {
            guard self?.appState.whipEnabled == true else { return }
            whip?.show()
        }}
        cursorDrag.onCursorEnd = { DispatchQueue.main.async { whip?.hide() } }
        cursorDrag.onCursorMove = { pos in DispatchQueue.main.async { whip?.updateCursor(pos) } }

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
        DispatchQueue.main.async {
            (NSApp.delegate as? AppDelegate)?.whipOverlay.updateFPS(self.appState.fps.timescale)
        }
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
            noHandFrames += 1
            let agentBusy = agentController.isActive || agentController.isProcessing
            let speechBusy = speechController.isActive
            cachedLeft = false
            cachedRight = false
            cachedDebug = ""
            DispatchQueue.main.async { [weak self] in
                self?.appState.trackingState = .inactive
                self?.appState.handsCount = 0
                self?.appState.leftHandDetected = false
                self?.appState.rightHandDetected = false
                if !agentBusy && (!speechBusy || self?.noHandFrames ?? 0 > 10) {
                    self?.appState.gestureLabel = ""
                    self?.appState.gestureProgress = 0
                    self?.appState.gestureCountdownStart = nil
                }
            }
            resetLeftGesture()
            cursorDrag.reset()
            if !speechBusy || noHandFrames > 10 {
                speechController.reset()
            }
            if agentController.isActive && !agentController.isProcessing {
                agentController.handsReleased()
            }
            deleteController.reset()
            swipeDetector.reset()
            return
        }
        noHandFrames = 0

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
                DispatchQueue.main.async { [weak self] in
                    self?.appState.progressMode = .countdown
                    self?.appState.gestureHand = .both
                    self?.appState.gestureLabel = "✕ Cancel"
                    self?.appState.gestureCountdownStart = self?.fingersCrossedStartTime
                    self?.appState.gestureCountdownDuration = self?.holdDuration ?? 1.0
                }
                if elapsed >= holdDuration {
                    fingersCrossedCount = 1
                    InputDispatch.perform(.pressModifiedKey(UInt16(kVK_ANSI_C), shift: false, control: true, option: false, command: false))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        InputDispatch.perform(.pressModifiedKey(UInt16(kVK_ANSI_C), shift: false, control: true, option: false, command: false))
                    }
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.gestureLabel = "✕ Ctrl+C ×2"
                        self?.appState.gestureCountdownStart = nil
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
            scrollController.sensitivityMultiplier = appState.scrollSensitivity
            scrollController.naturalScroll = appState.naturalScroll
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

        // Right hand grace period (must be before agent/speech checks that depend on it)
        if rightHand != nil {
            rightHandEntryFrames += 1
        } else {
            rightHandEntryFrames = 0
        }

        // === AGENT: both fists ===
        let bothFistsShape = leftHand != nil && rightHand != nil
            && GestureClassifier.countExtendedFingers(leftHand!) == 0
            && GestureClassifier.countExtendedFingers(rightHand!) == 0
            && !GestureClassifier.isThumbPinky(leftHand!) && !GestureClassifier.isThumbPinky(rightHand!)
        let bothFists = bothFistsShape && rightHandEntryFrames > handEntryGraceFrames

        // Show agent label during grace
        if bothFistsShape && rightHandEntryFrames <= handEntryGraceFrames {
            DispatchQueue.main.async { [weak self] in
                self?.appState.gestureLabel = "🤖 Agent"
            }
            return
        }

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
            } else {
                agentController.reset()
            }
        }

        // Show speech label during grace (no countdown yet)
        if rightHand != nil && leftHand == nil
            && rightHandEntryFrames <= handEntryGraceFrames
            && GestureClassifier.countExtendedFingers(rightHand!) == 0
            && !GestureClassifier.isThumbPinky(rightHand!) {
            DispatchQueue.main.async { [weak self] in
                self?.appState.gestureLabel = "🎤 Speech"
            }
            return
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
            let wasInactive = speechController.startTime == nil
            let status = speechController.process()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.appState.progressMode = status.progressMode
                if !status.activated, let start = self.speechController.startTime {
                    if wasInactive {
                        self.appState.gestureCountdownStart = nil
                        DispatchQueue.main.async {
                            self.appState.gestureCountdownStart = start
                            self.appState.gestureCountdownDuration = 1.0
                        }
                    } else {
                        self.appState.gestureCountdownStart = start
                        self.appState.gestureCountdownDuration = 1.0
                    }
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
                cursorDrag.sensitivity = appState.cursorSensitivity
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
            let leftInGrace = leftHandEntryFrames <= handEntryGraceFrames
            if leftInGrace {
                // Track gesture stability during grace so countdown starts instantly after
                if !GestureClassifier.isPinching(lh) {
                    let fingerCount = GestureClassifier.countExtendedFingers(lh)
                    let graceGesture: Int
                    if rightHand != nil {
                        graceGesture = -1
                    } else if GestureClassifier.isThumbPinky(lh) {
                        graceGesture = -2
                    } else if fingerCount >= 4 {
                        graceGesture = 5
                    } else if fingerCount == 0 {
                        graceGesture = 0
                    } else {
                        graceGesture = fingerCount
                    }

                    if graceGesture == leftGestureValue {
                        leftGestureStableFrames += 1
                    } else {
                        leftGestureValue = graceGesture
                        leftGestureStableFrames = 1
                    }

                    // Show label during grace
                    let previewLabel: String? = {
                        if graceGesture == -1 { return nil }
                        if graceGesture == -2 {
                            let b = GestureActionConfig.shared.binding(for: .leftThumbPinky)
                            return "🤙 \(b.displayName)"
                        }
                        if graceGesture == 0 {
                            let b = GestureActionConfig.shared.binding(for: .leftFist)
                            return "✊ \(b.displayName)"
                        }
                        if graceGesture == 5 {
                            let b = GestureActionConfig.shared.binding(for: .leftOpenPalm)
                            return "🖐 \(b.displayName)"
                        }
                        let slot: GestureSlot? = switch graceGesture {
                        case 1: .leftOneFinger
                        case 2: .leftTwoFingers
                        case 3: .leftThreeFingers
                        default: nil
                        }
                        if let slot {
                            let b = GestureActionConfig.shared.binding(for: slot)
                            return "☝️ \(b.displayName)"
                        }
                        return nil
                    }()
                    if let label = previewLabel {
                        DispatchQueue.main.async { [weak self] in
                            self?.appState.gestureLabel = label
                        }
                    }
                }
                return
            }

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
                // Pinch released — fire click or double-click
                if let start = leftPinchStartTime, !leftPinchFired {
                    let elapsed = Date().timeIntervalSince(start)
                    if elapsed < 0.5 {
                        let now = Date()
                        if now.timeIntervalSince(lastClickTime) < 0.4 {
                            InputDispatch.perform(.doubleClick)
                            lastClickTime = .distantPast
                            DispatchQueue.main.async { [weak self] in
                                self?.appState.gestureLabel = "👆👆 Double Click"
                            }
                        } else {
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
                    gestureValue = 5
                } else if fingerCount == 0 {
                    gestureValue = 0
                } else {
                    gestureValue = fingerCount
                }

                let rightLabelActive = self.rightHandLabelActive
                let gestureLabel: String? = {
                    if gestureValue == -1 { return nil }
                    if gestureValue == -2 {
                        let b = GestureActionConfig.shared.binding(for: .leftThumbPinky)
                        return "🤙 \(b.displayName)"
                    }
                    if gestureValue == 0 {
                        let b = GestureActionConfig.shared.binding(for: .leftFist)
                        return "✊ \(b.displayName)"
                    }
                    if gestureValue == 5 {
                        let b = GestureActionConfig.shared.binding(for: .leftOpenPalm)
                        return "🖐 \(b.displayName)"
                    }
                    let slot: GestureSlot? = switch gestureValue {
                    case 1: .leftOneFinger
                    case 2: .leftTwoFingers
                    case 3: .leftThreeFingers
                    default: nil
                    }
                    if let slot {
                        let b = GestureActionConfig.shared.binding(for: slot)
                        return "☝️ \(b.displayName)"
                    }
                    return nil
                }()

                if gestureValue == -1 {
                    resetLeftGesture()
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.trackingState = .tracking
                        if rightLabelActive { return }
                        self?.appState.gestureLabel = ""
                        self?.appState.gestureProgress = 0
                        self?.appState.gestureCountdownStart = nil
                    }
                } else if gestureValue == leftGestureValue {
                    leftGestureStableFrames += 1
                    guard leftGestureStableFrames >= stableFramesRequired else {
                        DispatchQueue.main.async { [weak self] in
                            self?.appState.trackingState = .tracking
                            if rightLabelActive { return }
                            if let label = gestureLabel {
                                self?.appState.gestureLabel = label
                            }
                        }
                        return
                    }
                    if leftGestureStartTime == nil {
                        leftGestureStartTime = Date()
                    }
                    let start = leftGestureStartTime!
                    let elapsed = Date().timeIntervalSince(start)
                    if elapsed >= holdDuration {
                        fireGesture(gestureValue)
                        leftGestureStartTime = nil
                    } else {
                        let dur = holdDuration
                        DispatchQueue.main.async { [weak self] in
                            self?.appState.trackingState = .tracking
                            if rightLabelActive { return }
                            if let label = gestureLabel {
                                self?.appState.gestureLabel = label
                            }
                            self?.appState.progressMode = .countdown
                            self?.appState.gestureCountdownStart = start
                            self?.appState.gestureCountdownDuration = dur
                        }
                    }
                } else {
                    leftGestureValue = gestureValue
                    leftGestureStableFrames = 0
                    leftGestureStartTime = nil
                    DispatchQueue.main.async { [weak self] in
                        self?.appState.trackingState = .tracking
                        if rightLabelActive { return }
                        if let label = gestureLabel {
                            self?.appState.gestureLabel = label
                        }
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
        let slot: GestureSlot? = switch value {
        case -2: .leftThumbPinky
        case 0: .leftFist
        case 1: .leftOneFinger
        case 2: .leftTwoFingers
        case 3: .leftThreeFingers
        case 5: .leftOpenPalm
        default: nil
        }
        guard let slot else { return }
        let binding = GestureActionConfig.shared.binding(for: slot)
        fireBinding(binding)
        startCooldownProgress()
    }

    private func fireBinding(_ binding: KeyBinding) {
        if binding.isMediaKey {
            InputDispatch.performMediaKey(binding.keyCode)
        } else if binding.hasModifiers {
            InputDispatch.perform(.pressModifiedKey(binding.keyCode, shift: binding.shift, control: binding.control, option: binding.option, command: binding.command))
        } else {
            InputDispatch.perform(.pressKey(binding.keyCode))
        }
    }

    private func handleSwipe(_ direction: SwipeDetector.SwipeDirection, leftOpen: Bool) {
        rightHandLabelActive = true
        startCooldownProgress()

        let slot: GestureSlot
        switch direction {
        case .left: slot = leftOpen ? .swipeLeftWithLeftOpen : .swipeLeft
        case .right: slot = leftOpen ? .swipeRightWithLeftOpen : .swipeRight
        case .up: slot = .swipeUp
        case .down: slot = .swipeDown
        }

        let binding = GestureActionConfig.shared.binding(for: slot)
        fireBinding(binding)

        let arrow: String = switch direction {
        case .left: "←"
        case .right: "→"
        case .up: "↑"
        case .down: "↓"
        }
        DispatchQueue.main.async { [weak self] in
            self?.appState.gestureLabel = "\(arrow) \(binding.displayName)"
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
