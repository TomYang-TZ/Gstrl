import Foundation

final class GazeCollector: ObservableObject {
    private var samples: [CGPoint] = []

    func add(_ point: CGPoint) {
        samples.append(point)
    }

    func average() -> CGPoint? {
        guard !samples.isEmpty else { return nil }
        let sumX = samples.reduce(0.0) { $0 + $1.x }
        let sumY = samples.reduce(0.0) { $0 + $1.y }
        return CGPoint(x: sumX / CGFloat(samples.count), y: sumY / CGFloat(samples.count))
    }

    func reset() {
        samples = []
    }
}
