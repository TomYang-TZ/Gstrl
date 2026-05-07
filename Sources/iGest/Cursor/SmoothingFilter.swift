import Foundation

final class SmoothingFilter {
    var alpha: Double
    private var previous: CGPoint?

    init(alpha: Double) {
        self.alpha = alpha
    }

    func apply(_ point: CGPoint) -> CGPoint {
        guard let prev = previous else {
            previous = point
            return point
        }

        let smoothed = CGPoint(
            x: alpha * point.x + (1 - alpha) * prev.x,
            y: alpha * point.y + (1 - alpha) * prev.y
        )
        previous = smoothed
        return smoothed
    }

    func reset() {
        previous = nil
    }
}
