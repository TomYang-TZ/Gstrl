import Foundation

final class SpeechController {
    private let speechEngine = SpeechEngine()
    private var startTime: Date?
    private(set) var isActive = false
    private var committedLen = 0
    private let holdDuration: TimeInterval = 1.0

    // Debounce: wait for recognizer to settle before typing
    private var pendingText = ""
    private var debounceWork: DispatchWorkItem?
    private var flushedPrefix: String?
    private static let debounceDelay: TimeInterval = 0.3
    private static let partialWaitDelay: TimeInterval = 0.8

    var onLabelUpdate: ((String) -> Void)?
    var commandFlashUntil: Date = .distantPast

    func reset() {
        if startTime != nil || isActive {
            startTime = nil
            committedLen = 0
            pendingText = ""
            flushedPrefix = nil
            debounceWork?.cancel()
            debounceWork = nil
            if isActive {
                isActive = false
                speechEngine.stopListening()
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

        let delta = String(text.dropFirst(committedLen))

        let work = DispatchWorkItem { [weak self] in
            self?.commitPendingText()
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounceDelay, execute: work)
    }

    private func commitPendingText() {
        guard isActive else { return }
        let text = pendingText
        let delta = String(text.dropFirst(committedLen))
        guard !delta.trimmingCharacters(in: .whitespaces).isEmpty else {
            committedLen = text.count
            return
        }

        // If we previously flushed a prefix as text, check if this delta completes the command
        if let prefix = flushedPrefix {
            let combined = prefix + " " + delta.trimmingCharacters(in: .whitespaces)
            if case .command(let action, _, let displayName) = VoiceCommandParser.parse(newText: combined) {
                // Undo the flushed prefix text and fire the command
                speechEngine.deleteChars(prefix.count)
                InputDispatch.perform(action)
                committedLen = text.count
                flushedPrefix = nil
                flashCommandFeedback(displayName)
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
            InputDispatch.perform(action)
            committedLen = text.count
            flashCommandFeedback(displayName)
        case .partial(_, _):
            // Still waiting for keyword — extend with longer timeout
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
        commandFlashUntil = Date().addingTimeInterval(1.0)
        onLabelUpdate?("⌨️ \(displayName)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.onLabelUpdate?("🎤 Listening...")
        }
    }
}
