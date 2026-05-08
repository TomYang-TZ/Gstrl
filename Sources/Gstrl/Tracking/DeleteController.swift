import Foundation
import Carbon.HIToolbox

final class DeleteController {
    private var startTime: Date?
    private var fired: Bool = false
    private var lastRepeat: Date = .distantPast
    private var repeatCount: Int = 0
    private var thumbPinkyFrames: Int = 0
    private let holdDuration: TimeInterval = 1.0
    private let requiredFrames: Int = 5

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
                lastRepeat = now
                repeatCount = 0
                onKeyPress?(UInt16(kVK_Delete), false, false, false, false)
                return Status(label: "🗑 Delete...", progress: 0, progressMode: .countdown)
            }
            return Status(label: "🗑 Delete", progress: progress, progressMode: .countdown)
        } else if fired {
            let elapsed = now.timeIntervalSince(startTime ?? now)
            let interval: TimeInterval
            let deleteType: Int
            let warningProgress: Double

            if elapsed < 5.0 {
                interval = max(0.1, 0.5 - Double(repeatCount) * 0.1)
                deleteType = 0
                warningProgress = elapsed / 5.0
            } else if elapsed < 8.0 {
                interval = 0.3
                deleteType = 1
                warningProgress = (elapsed - 5.0) / 3.0
            } else if elapsed < 11.0 {
                interval = 0.4
                deleteType = 2
                warningProgress = (elapsed - 8.0) / 3.0
            } else {
                interval = 0.5
                deleteType = 3
                warningProgress = 0
            }

            if now.timeIntervalSince(lastRepeat) >= interval {
                lastRepeat = now
                repeatCount += 1
                switch deleteType {
                case 3:
                    onKeyPress?(UInt16(kVK_ANSI_A), false, false, false, true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.onKeyPress?(UInt16(kVK_Delete), false, false, false, false)
                    }
                case 2:
                    onKeyPress?(UInt16(kVK_Delete), false, false, false, true)
                case 1:
                    onKeyPress?(UInt16(kVK_Delete), false, false, true, false)
                default:
                    onKeyPress?(UInt16(kVK_Delete), false, false, false, false)
                }
            }

            let label: String
            switch deleteType {
            case 0: label = "🗑 Char → Word"
            case 1: label = "🗑 Word → Line"
            case 2: label = "⚠️ Line → ALL"
            default: label = "⚠️ DELETE ALL"
            }
            return Status(label: label, progress: warningProgress, progressMode: .countdown)
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

        let activeElapsed = elapsed - holdDuration
        let isSelectAll = activeElapsed >= 5.0
        let interval: TimeInterval = isSelectAll ? 0.5 : 0.4

        if now.timeIntervalSince(bothHandsLastRepeat) >= interval {
            bothHandsLastRepeat = now
            bothHandsCount += 1
            if isSelectAll {
                onKeyPress?(UInt16(kVK_ANSI_A), false, false, false, true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.onKeyPress?(UInt16(kVK_Delete), false, false, false, false)
                }
                return Status(label: "⚠️ DELETE ALL", progress: 0, progressMode: .countdown)
            } else {
                onKeyPress?(UInt16(kVK_Delete), false, false, false, true)
            }
        }

        if !isSelectAll {
            let warningProgress = min(1.0, activeElapsed / 5.0)
            return Status(label: "⚠️ Line → ALL", progress: warningProgress, progressMode: .countdown)
        }
        return Status(label: "⚠️ DELETE ALL", progress: 0, progressMode: .countdown)
    }
}
