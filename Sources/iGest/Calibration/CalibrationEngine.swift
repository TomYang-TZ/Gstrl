import Foundation

final class CalibrationEngine: ObservableObject {
    let calibrationPoints: [CGPoint]
    @Published var currentPointIndex: Int = 0
    @Published var isComplete: Bool = false

    private var collectedGazeVectors: [CGPoint] = []
    private let mapper: PolynomialMapper

    var currentTarget: CGPoint? {
        guard currentPointIndex < calibrationPoints.count else { return nil }
        return calibrationPoints[currentPointIndex]
    }

    init(screenSize: CGSize, mapper: PolynomialMapper = PolynomialMapper()) {
        self.mapper = mapper

        let marginX = screenSize.width * 0.1
        let marginY = screenSize.height * 0.1
        let stepX = (screenSize.width - 2 * marginX) / 2
        let stepY = (screenSize.height - 2 * marginY) / 2

        var points: [CGPoint] = []
        for row in 0..<3 {
            for col in 0..<3 {
                points.append(CGPoint(
                    x: marginX + CGFloat(col) * stepX,
                    y: marginY + CGFloat(row) * stepY
                ))
            }
        }
        self.calibrationPoints = points
    }

    func recordGazeVector(_ gazeVector: CGPoint) {
        guard currentPointIndex < calibrationPoints.count else { return }
        collectedGazeVectors.append(gazeVector)
        currentPointIndex += 1

        if currentPointIndex >= calibrationPoints.count {
            computeCalibration()
            isComplete = true
        }
    }

    func reset() {
        currentPointIndex = 0
        collectedGazeVectors = []
        isComplete = false
    }

    private func computeCalibration() {
        mapper.calibrate(gazePoints: collectedGazeVectors, screenPoints: calibrationPoints)
        mapper.save()
    }
}
