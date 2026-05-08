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
              let ringTip = try? obs.recognizedPoint(.ringTip),
              let ringPIP = try? obs.recognizedPoint(.ringPIP),
              let littleTip = try? obs.recognizedPoint(.littleTip),
              let littlePIP = try? obs.recognizedPoint(.littlePIP),
              indexTip.confidence > 0.3, middleTip.confidence > 0.3 else { return nil }

        // Two fingers extended (index + middle), ring + pinky closed
        let indexLength = hypot(indexTip.location.x - indexPIP.location.x,
                                indexTip.location.y - indexPIP.location.y)
        let middleLength = hypot(middleTip.location.x - middlePIP.location.x,
                                 middleTip.location.y - middlePIP.location.y)
        let ringLength = hypot(ringTip.location.x - ringPIP.location.x,
                               ringTip.location.y - ringPIP.location.y)
        let littleLength = hypot(littleTip.location.x - littlePIP.location.x,
                                 littleTip.location.y - littlePIP.location.y)

        guard indexLength > 0.06 && middleLength > 0.06 else { return nil }
        guard ringLength < 0.05 && littleLength < 0.05 else { return nil }

        // Use average direction of both extended fingers
        let dx = ((indexTip.location.x - indexPIP.location.x) + (middleTip.location.x - middlePIP.location.x)) / 2
        let dy = ((indexTip.location.y - indexPIP.location.y) + (middleTip.location.y - middlePIP.location.y)) / 2
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
