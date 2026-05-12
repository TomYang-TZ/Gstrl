import Foundation
import Carbon.HIToolbox

final class DeleteController {
    private(set) var startTime: Date?
    private(set) var fired: Bool = false
    private var lastRepeat: Date = .distantPast
    private var repeatCount: Int = 0
    private var thumbPinkyFrames: Int = 0
    let holdDuration: TimeInterval = 1.0
    private let requiredFrames: Int = 3

    struct Status {
        let label: String
        let progress: Double
        let progressMode: AppState.ProgressMode
    }

    var onKeyPress: ((_ keyCode: UInt16, _ shift: Bool, _ control: Bool, _ option: Bool, _ command: Bool) -> Void)?

    func reset() {
        startTime = nil
        fired = false
        thumbPinkyFrames = 0
        repeatCount = 0
    }

    func processSingleHand() -> Status? {
        thumbPinkyFrames += 1
        guard thumbPinkyFrames >= requiredFrames else { return nil }

        if startTime == nil {
            startTime = Date()
        }

        let now = Date()
        if !fired, let start = startTime {
            let elapsed = now.timeIntervalSince(start)
            let progress = min(1.0, elapsed / holdDuration)
            if elapsed >= holdDuration {
                fired = true
                lastRepeat = .distantPast
                repeatCount = 0
                return Status(label: "🗑 Char → Word", progress: 0, progressMode: .countdown)
            }
            return Status(label: "🗑 Delete", progress: progress, progressMode: .countdown)
        } else if fired {
            if now.timeIntervalSince(lastRepeat) >= 0.05 {
                lastRepeat = now
                onKeyPress?(UInt16(kVK_Delete), false, false, false, false)
            }
            return Status(label: "🗑 Char", progress: 0, progressMode: .countdown)
        }
        return nil
    }

    var bothHandsStartTime: Date?
    var bothHandsLastRepeat: Date = .distantPast
    var bothHandsCount: Int = 0

    func resetBothHands() {
        bothHandsStartTime = nil
        bothHandsCount = 0
    }

    func processBothHands() -> Status? {
        if bothHandsStartTime == nil {
            bothHandsStartTime = Date()
            bothHandsCount = 0
        }
        let now = Date()
        let elapsed = now.timeIntervalSince(bothHandsStartTime!)

        if elapsed < holdDuration {
            let progress = min(1.0, elapsed / holdDuration)
            return Status(label: "🗑🗑 Lines", progress: progress, progressMode: .countdown)
        }

        if now.timeIntervalSince(bothHandsLastRepeat) >= 0.05 {
            bothHandsLastRepeat = now
            bothHandsCount += 1
            onKeyPress?(UInt16(kVK_Delete), false, false, false, true)
        }

        return Status(label: "🗑 Line", progress: 0, progressMode: .countdown)
    }
}
