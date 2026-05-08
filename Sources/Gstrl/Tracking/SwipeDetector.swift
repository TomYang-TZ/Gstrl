import Vision
import Foundation

final class SwipeDetector {
    enum SwipeDirection {
        case left, right, up, down
    }

    private var positions: [(pos: CGPoint, time: Date)] = []
    private var lastSwipeTime: Date = .distantPast
    private let swipeCooldown: TimeInterval = 1.0
    private var rightHandEntryFrames: Int = 0
    private let handEntryGraceFrames: Int = 15
    private var swipeModeActive: Bool = false

    // Displacement detection params
    private let minDisplacement: CGFloat = 0.08
    private let maxSwipeDuration: TimeInterval = 0.3
    private let directionRatio: CGFloat = 2.0

    var onSwipe: ((_ direction: SwipeDirection, _ leftOpen: Bool) -> Void)?

    func reset() {
        positions.removeAll()
        rightHandEntryFrames = 0
        swipeModeActive = false
    }

    func resetEntryFrames() {
        rightHandEntryFrames = 0
    }

    func process(_ obs: VNHumanHandPoseObservation, leftHand: VNHumanHandPoseObservation?) {
        let leftOpen = leftHand != nil && GestureClassifier.countExtendedFingers(leftHand!) >= 4

        // Only detect swipes when left hand isn't forming a non-open gesture
        if leftHand != nil && !leftOpen { return }

        // Require open hand to ENTER swipe mode, but stay in mode during motion
        let rFingers = GestureClassifier.countExtendedFingers(obs)
        if rFingers >= 4 {
            swipeModeActive = true
        } else if positions.isEmpty {
            // Not in swipe mode and hand isn't open — skip
            swipeModeActive = false
            return
        }
        // If mid-swipe (positions not empty), keep tracking even if fingers drop

        rightHandEntryFrames += 1
        if rightHandEntryFrames <= handEntryGraceFrames {
            return
        }

        guard let indexTip = try? obs.recognizedPoint(.indexTip),
              indexTip.confidence > 0.3 else { return }

        let now = Date()

        guard now.timeIntervalSince(lastSwipeTime) > swipeCooldown else {
            positions.removeAll()
            return
        }

        let pos = CGPoint(x: indexTip.location.x, y: indexTip.location.y)
        positions.append((pos: pos, time: now))

        // Keep only recent positions within the swipe window
        positions.removeAll { now.timeIntervalSince($0.time) > maxSwipeDuration }

        guard positions.count >= 3 else { return }

        // Check displacement from first to last position
        let start = positions.first!
        let end = positions.last!
        let dt = end.time.timeIntervalSince(start.time)
        guard dt > 0.03 && dt <= maxSwipeDuration else { return }

        let dx = end.pos.x - start.pos.x
        let dy = end.pos.y - start.pos.y
        let absDx = abs(dx)
        let absDy = abs(dy)
        let totalDisplacement = max(absDx, absDy)

        guard totalDisplacement > minDisplacement else { return }
        guard max(absDx, absDy) > min(absDx, absDy) * directionRatio else { return }

        // Check deceleration — last segment should be slower than first
        if positions.count >= 4 {
            let mid = positions.count / 2
            let firstHalfDist = hypot(
                positions[mid].pos.x - positions[0].pos.x,
                positions[mid].pos.y - positions[0].pos.y
            )
            let secondHalfDist = hypot(
                positions.last!.pos.x - positions[mid].pos.x,
                positions.last!.pos.y - positions[mid].pos.y
            )
            // First half should have more displacement (decelerating)
            guard firstHalfDist > secondHalfDist * 0.5 else { return }
        }

        // Fire swipe
        lastSwipeTime = now
        positions.removeAll()

        let direction: SwipeDirection
        if absDx > absDy {
            direction = dx > 0 ? .left : .right
        } else {
            direction = dy > 0 ? .up : .down
        }

        // Block vertical swipes when left hand is open (used for scroll)
        if absDy > absDx && leftOpen { return }

        onSwipe?(direction, leftOpen)
    }
}
