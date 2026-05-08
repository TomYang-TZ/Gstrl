import Foundation

final class SpeechController {
    private let speechEngine = SpeechEngine()
    private var startTime: Date?
    private(set) var isActive = false
    private var lastTypedLength = 0
    private let holdDuration: TimeInterval = 1.0

    // Disambiguation buffering
    private var bufferedPrefix: String?
    private var bufferedTextBeforePrefix: String?
    private var bufferTimeout: DispatchWorkItem?
    private static let disambiguationTimeout: TimeInterval = 0.5

    var onLabelUpdate: ((String) -> Void)?

    func reset() {
        if startTime != nil || isActive {
            startTime = nil
            cancelBuffer()
            if isActive {
                isActive = false
                speechEngine.stopListening()
            }
        }
    }

    private func cancelBuffer() {
        bufferTimeout?.cancel()
        bufferTimeout = nil
        bufferedPrefix = nil
        bufferedTextBeforePrefix = nil
    }

    private func flushBufferAsText(cumulativeText: String) {
        guard let prefix = bufferedPrefix else { return }
        let textBefore = bufferedTextBeforePrefix ?? ""
        let textToType = textBefore.isEmpty ? prefix : textBefore + " " + prefix
        speechEngine.typeText(textToType)
        lastTypedLength = cumulativeText.count
        bufferedPrefix = nil
        bufferedTextBeforePrefix = nil
        bufferTimeout = nil
        onLabelUpdate?("🎤 \(cumulativeText)")
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
                lastTypedLength = 0
                cancelBuffer()
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
        let newChars = String(text.dropFirst(lastTypedLength))
        guard !newChars.isEmpty else { return }

        // If we have a buffered prefix, check if the new text completes a command
        if bufferedPrefix != nil {
            bufferTimeout?.cancel()
            bufferTimeout = nil

            let combined = bufferedPrefix! + " " + newChars
            switch VoiceCommandParser.parse(newText: combined) {
            case .command(let action, _, let displayName):
                InputDispatch.perform(action)
                lastTypedLength = text.count
                // Type any text that was before the prefix
                if let textBefore = bufferedTextBeforePrefix, !textBefore.isEmpty {
                    speechEngine.typeText(textBefore)
                }
                cancelBuffer()
                flashCommandFeedback(displayName)
                return
            case .partial(_, _):
                // Still partial — re-buffer with updated state
                startBufferTimeout(cumulativeText: text)
                return
            case .text:
                // Did not complete a command — flush buffer as literal text
                let prefix = bufferedPrefix!
                let textBefore = bufferedTextBeforePrefix ?? ""
                let allText = textBefore.isEmpty ? prefix + " " + newChars : textBefore + " " + prefix + " " + newChars
                speechEngine.typeText(allText)
                lastTypedLength = text.count
                cancelBuffer()
                self.onLabelUpdate?("🎤 \(text)")
                return
            }
        }

        // No buffer active — normal parsing
        switch VoiceCommandParser.parse(newText: newChars) {
        case .command(let action, let wordCount, let displayName):
            // Type any text before the command words
            let words = newChars.split(separator: " ", omittingEmptySubsequences: true)
            if words.count > wordCount {
                let preCommandText = words.dropLast(wordCount).joined(separator: " ")
                speechEngine.typeText(preCommandText + " ")
            }
            InputDispatch.perform(action)
            lastTypedLength = text.count
            flashCommandFeedback(displayName)
        case .partial(let prefix, let wordCount):
            // Buffer the prefix, type any text before it
            let words = newChars.split(separator: " ", omittingEmptySubsequences: true)
            if words.count > wordCount {
                let preText = words.dropLast(wordCount).joined(separator: " ")
                speechEngine.typeText(preText + " ")
                bufferedTextBeforePrefix = nil
            } else {
                bufferedTextBeforePrefix = nil
            }
            bufferedPrefix = prefix
            lastTypedLength = text.count
            startBufferTimeout(cumulativeText: text)
            self.onLabelUpdate?("⌨️ \(prefix) ...?")
        case .text:
            speechEngine.typeText(newChars)
            lastTypedLength = text.count
            self.onLabelUpdate?("🎤 \(text)")
        }
    }

    private func flashCommandFeedback(_ displayName: String) {
        onLabelUpdate?("⌨️ \(displayName)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.onLabelUpdate?("🎤 Listening...")
        }
    }

    private func startBufferTimeout(cumulativeText: String) {
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.bufferedPrefix != nil else { return }
            self.flushBufferAsText(cumulativeText: cumulativeText)
        }
        bufferTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.disambiguationTimeout, execute: work)
    }
}
