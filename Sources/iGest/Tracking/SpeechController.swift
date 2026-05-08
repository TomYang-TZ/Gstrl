import Foundation

final class SpeechController {
    private let speechEngine = SpeechEngine()
    private var startTime: Date?
    private(set) var isActive = false
    private var lastTypedLength = 0
    private let holdDuration: TimeInterval = 1.0

    var onLabelUpdate: ((String) -> Void)?

    func reset() {
        if startTime != nil || isActive {
            startTime = nil
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
                lastTypedLength = 0
                speechEngine.onResult = { [weak self] text in
                    guard let self else { return }
                    let newChars = String(text.dropFirst(self.lastTypedLength))
                    if !newChars.isEmpty {
                        self.speechEngine.typeText(newChars)
                        self.lastTypedLength = text.count
                    }
                    self.onLabelUpdate?("🎤 \(text)")
                }
                speechEngine.startListening()
                return Status(label: "🎤 Listening...", progress: 0, progressMode: .countdown, activated: true)
            }
            let progress = min(1.0, elapsed / holdDuration)
            return Status(label: "🎤 Speech", progress: progress, progressMode: .countdown, activated: false)
        }

        return Status(label: "🎤 Listening...", progress: 0, progressMode: .countdown, activated: true)
    }
}
