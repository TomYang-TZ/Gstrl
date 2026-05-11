import Foundation

final class SpeechController {
    private let speechEngine = SpeechEngine()
    private(set) var startTime: Date?

    func updateLocale(_ identifier: String) {
        speechEngine.updateLocale(identifier)
    }
    private(set) var isActive = false
    private var committedLen = 0
    private var committedSnapshot = ""
    private let holdDuration: TimeInterval = 1.0

    // Debounce: wait for recognizer to settle before typing
    private var pendingText = ""
    private var debounceWork: DispatchWorkItem?
    private var flushedPrefix: String?
    private static let debounceDelay: TimeInterval = 0.15
    private static let partialWaitDelay: TimeInterval = 0.5

    var onLabelUpdate: ((String) -> Void)?
    var onTranscriptUpdate: ((String) -> Void)?
    var commandFlashUntil: Date = .distantPast
    private var fadeWork: DispatchWorkItem?
    private var displayedTranscript: String = ""

    func reset() {
        if startTime != nil || isActive {
            startTime = nil
            committedLen = 0
            committedSnapshot = ""
            pendingText = ""
            flushedPrefix = nil
            debounceWork?.cancel()
            debounceWork = nil
            if isActive {
                isActive = false
                speechEngine.stopListening()
                onTranscriptUpdate?("")
            }
        }
    }

    struct Status {
        let label: String
        let progress: Double
        let progressMode: AppState.ProgressMode
        let activated: Bool
    }

    func process() -> Status {
        if startTime == nil { startTime = Date() }

        let elapsed = Date().timeIntervalSince(startTime!)

        if !isActive {
            if elapsed >= holdDuration {
                isActive = true
                committedLen = 0
                committedSnapshot = ""
                pendingText = ""
                debounceWork?.cancel()
                debounceWork = nil
                speechEngine.onResult = { [weak self] text in
                    DispatchQueue.main.async {
                        self?.handleSpeechResult(text)
                    }
                }
                speechEngine.startListening()
                return Status(label: "🎤 Listening...", progress: 0, progressMode: .countdown, activated: true)
            }
            let progress = min(1.0, elapsed / holdDuration)
            return Status(label: "🎤 Speech", progress: progress, progressMode: .countdown, activated: false)
        }

        return Status(label: "🎤 Listening...", progress: 0, progressMode: .countdown, activated: true)
    }

    private func handleSpeechResult(_ text: String) {
        guard isActive else { return }

        // Store latest cumulative text and restart debounce timer
        pendingText = text
        debounceWork?.cancel()
        displayedTranscript = text
        onTranscriptUpdate?(text)
        scheduleFade()

        let work = DispatchWorkItem { [weak self] in
            self?.commitPendingText()
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounceDelay, execute: work)
    }

    private func commitPendingText() {
        guard isActive else { return }
        let text = pendingText
        // If recognizer revised committed text, skip this frame
        if committedLen > text.count {
            committedLen = text.count
            committedSnapshot = text
            return
        }
        if !committedSnapshot.isEmpty && !text.hasPrefix(committedSnapshot) {
            committedLen = text.count
            committedSnapshot = text
            return
        }
        let delta = String(text.dropFirst(committedLen))
        guard !delta.trimmingCharacters(in: .whitespaces).isEmpty else {
            committedLen = text.count
            return
        }

        // If we previously flushed a prefix as text, check if this delta completes the command
        if let prefix = flushedPrefix {
            let combined = prefix + " " + delta.trimmingCharacters(in: .whitespaces)
            if case .command(let action, _, let displayName) = VoiceCommandParser.parse(newText: combined) {
                speechEngine.deleteChars(prefix.count)
                InputDispatch.perform(action, usePhysicalModifiers: false)
                flushedPrefix = nil
                flashCommandFeedback(displayName)
                resetAfterCommand()
                return
            }
            flushedPrefix = nil
        }

        // Parse the entire uncommitted delta for commands
        switch VoiceCommandParser.parse(newText: delta) {
        case .command(let action, let wordCount, let displayName):
            let words = delta.split(separator: " ", omittingEmptySubsequences: true)
            if words.count > wordCount {
                let preCommandText = words.dropLast(wordCount).joined(separator: " ")
                speechEngine.typeText(preCommandText + " ")
            }
            InputDispatch.perform(action, usePhysicalModifiers: false)
            flashCommandFeedback(displayName)
            resetAfterCommand()
        case .partial(_, _):
            let work = DispatchWorkItem { [weak self] in
                self?.flushPartialAsText()
            }
            debounceWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.partialWaitDelay, execute: work)
            onLabelUpdate?("⌨️ \(delta.trimmingCharacters(in: .whitespaces)) ...?")
        case .text:
            speechEngine.typeText(delta)
            committedLen = text.count
        }
    }

    private func resetAfterCommand() {
        committedLen = pendingText.count
        committedSnapshot = pendingText
        flushedPrefix = nil
    }

    private func flushPartialAsText() {
        guard isActive else { return }
        let text = pendingText
        let delta = String(text.dropFirst(committedLen))
        guard !delta.isEmpty else { return }
        speechEngine.typeText(delta)
        flushedPrefix = delta.trimmingCharacters(in: .whitespaces)
        committedLen = text.count
    }

    private func flashCommandFeedback(_ displayName: String) {
        commandFlashUntil = Date().addingTimeInterval(3.0)
        onLabelUpdate?("⌨️ \(displayName)")
        onTranscriptUpdate?("⌨️ \(displayName)")
        fadeWork?.cancel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self, self.isActive else { return }
            self.onLabelUpdate?("🎤 Listening...")
            self.onTranscriptUpdate?(self.displayedTranscript)
            self.scheduleFade()
        }
    }

    private func scheduleFade() {
        fadeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.fadeOneWord()
        }
        fadeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private func fadeOneWord() {
        guard isActive, !displayedTranscript.isEmpty else { return }
        var words = displayedTranscript.split(separator: " ", omittingEmptySubsequences: true)
        guard words.count > 1 else {
            displayedTranscript = ""
            onTranscriptUpdate?("")
            return
        }
        words.removeFirst()
        displayedTranscript = words.joined(separator: " ")
        onTranscriptUpdate?(displayedTranscript)

        let work = DispatchWorkItem { [weak self] in
            self?.fadeOneWord()
        }
        fadeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}
