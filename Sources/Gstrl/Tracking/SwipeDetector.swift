import Vision
import Foundation

final class SwipeDetector {
    enum SwipeDirection {
        case left, right, up, down
    }

    private var rightIndexPrev: (pos: CGPoint, time: Date)?
    private var lastSwipeTime: Date = .distantPast
    private let swipeCooldown: TimeInterval = 1.0
    private let velocityThreshold: CGFloat = 0.6
    private var swipeReturnIgnoreUntil: Date = .distantPast
    private var swipeVelocityAccum: CGPoint = .zero
    private var swipeAccumFrames: Int = 0
    private var rightHandEntryFrames: Int = 0
    private let handEntryGraceFrames: Int = 5

    var onSwipe: ((_ direction: SwipeDirection, _ leftOpen: Bool) -> Void)?

    func reset() {
        rightIndexPrev = nil
        swipeVelocityAccum = .zero
        swipeAccumFrames = 0
        rightHandEntryFrames = 0
    }

    func resetEntryFrames() {
        rightHandEntryFrames = 0
    }

    func process(_ obs: VNHumanHandPoseObservation, leftHand: VNHumanHandPoseObservation?) {
        let leftOpen = leftHand != nil && GestureClassifier.countExtendedFingers(leftHand!) >= 4

        if leftHand != nil && !leftOpen { return }

        rightHandEntryFrames += 1
        if rightHandEntryFrames <= handEntryGraceFrames {
            return
        }

        guard let indexTip = try? obs.recognizedPoint(.indexTip),
              indexTip.confidence > 0.15 else { return }

        let now = Date()

        if now < swipeReturnIgnoreUntil {
            rightIndexPrev = nil
            swipeVelocityAccum = .zero
            swipeAccumFrames = 0
            return
        }

        let pos = CGPoint(x: indexTip.location.x, y: indexTip.location.y)

        defer { rightIndexPrev = (pos: pos, time: now) }

        guard let prev = rightIndexPrev else { return }
        let dt = now.timeIntervalSince(prev.time)
        guard dt > 0.001 && dt < 0.2 else {
            swipeVelocityAccum = .zero
            swipeAccumFrames = 0
            return
        }

        let vx = (pos.x - prev.pos.x) / CGFloat(dt)
        let vy = (pos.y - prev.pos.y) / CGFloat(dt)

        let speed = hypot(vx, vy)
        if speed < velocityThreshold * 0.4 {
            swipeVelocityAccum = .zero
            swipeAccumFrames = 0
            return
        }

        if swipeAccumFrames > 0 {
            let dotProduct = vx * swipeVelocityAccum.x + vy * swipeVelocityAccum.y
            if dotProduct < 0 {
                swipeVelocityAccum = .zero
                swipeAccumFrames = 0
                return
            }
        }

        swipeVelocityAccum = CGPoint(x: swipeVelocityAccum.x + vx, y: swipeVelocityAccum.y + vy)
        swipeAccumFrames += 1

        guard swipeAccumFrames >= 2 else { return }

        let avgVx = swipeVelocityAccum.x / CGFloat(swipeAccumFrames)
        let avgVy = swipeVelocityAccum.y / CGFloat(swipeAccumFrames)
        let absVx = abs(avgVx)
        let absVy = abs(avgVy)

        guard max(absVx, absVy) > velocityThreshold else { return }
        guard max(absVx, absVy) > min(absVx, absVy) * 1.5 else { return }
        guard now.timeIntervalSince(lastSwipeTime) > swipeCooldown else { return }

        if absVy > absVx && leftOpen { return }

        lastSwipeTime = now
        swipeVelocityAccum = .zero
        swipeAccumFrames = 0
        rightIndexPrev = nil
        swipeReturnIgnoreUntil = now.addingTimeInterval(swipeCooldown)

        let direction: SwipeDirection
        if absVx > absVy {
            direction = avgVx > 0 ? .left : .right
        } else {
            direction = avgVy > 0 ? .up : .down
        }

        onSwipe?(direction, leftOpen)
    }
}
