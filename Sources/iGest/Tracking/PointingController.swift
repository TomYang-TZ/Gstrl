import Foundation
import Vision
import Carbon.HIToolbox

final class PointingController {
    enum Direction {
        case left, right, up, down
    }

    private var currentDirection: Direction?
    private var startTime: Date?
    private var lastRepeat: Date = .distantPast
    private var repeatCount: Int = 0
    private let activationDelay: TimeInterval = 0.5

    struct Status {
        let direction: Direction
        let label: String
        let progress: Double
        let fired: Bool
    }

    func reset() {
        currentDirection = nil
        startTime = nil
        repeatCount = 0
    }

    func process(_ obs: VNHumanHandPoseObservation) -> Status? {
        guard let direction = detectPointingDirection(obs) else {
            reset()
            return nil
        }

        if direction != currentDirection {
            currentDirection = direction
            startTime = Date()
            repeatCount = 0
        }

        guard let start = startTime else { return nil }
        let elapsed = Date().timeIntervalSince(start)

        if elapsed < activationDelay {
            let progress = elapsed / activationDelay
            return Status(direction: direction, label: labelFor(direction), progress: progress, fired: false)
        }

        let activeTime = elapsed - activationDelay
        let interval = max(0.05, 0.4 - activeTime * 0.04)

        let now = Date()
        if now.timeIntervalSince(lastRepeat) >= interval {
            lastRepeat = now
            repeatCount += 1
            fireKey(direction)
        }

        return Status(direction: direction, label: labelFor(direction) + "...", progress: 0, fired: true)
    }

    private func detectPointingDirection(_ obs: VNHumanHandPoseObservation) -> Direction? {
        guard let indexTip = try? obs.recognizedPoint(.indexTip),
              let indexPIP = try? obs.recognizedPoint(.indexPIP),
              let middleTip = try? obs.recognizedPoint(.middleTip),
              let middlePIP = try? obs.recognizedPoint(.middlePIP),
              indexTip.confidence > 0.3, indexPIP.confidence > 0.3 else { return nil }

        let indexExtended = indexTip.location.y > indexPIP.location.y
            || abs(indexTip.location.x - indexPIP.location.x) > 0.06
        let middleClosed = middleTip.location.y <= middlePIP.location.y

        guard indexExtended && middleClosed else { return nil }

        let dx = indexTip.location.x - indexPIP.location.x
        let dy = indexTip.location.y - indexPIP.location.y
        let absDx = abs(dx)
        let absDy = abs(dy)

        guard max(absDx, absDy) > 0.04 else { return nil }
        guard max(absDx, absDy) > min(absDx, absDy) * 1.5 else { return nil }

        if absDx > absDy {
            return dx > 0 ? .left : .right
        } else {
            return dy > 0 ? .up : .down
        }
    }

    private func fireKey(_ direction: Direction) {
        let keyCode: UInt16
        switch direction {
        case .left: keyCode = UInt16(kVK_LeftArrow)
        case .right: keyCode = UInt16(kVK_RightArrow)
        case .up: keyCode = UInt16(kVK_UpArrow)
        case .down: keyCode = UInt16(kVK_DownArrow)
        }
        InputDispatch.perform(.pressKey(keyCode))
    }

    private func labelFor(_ direction: Direction) -> String {
        switch direction {
        case .left: return "☞ ←"
        case .right: return "☞ →"
        case .up: return "☞ ↑"
        case .down: return "☞ ↓"
        }
    }
}
