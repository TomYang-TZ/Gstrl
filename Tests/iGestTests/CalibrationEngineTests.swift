import XCTest
@testable import iGest

final class CalibrationEngineTests: XCTestCase {

    func testCalibrationPointsAre9() {
        let engine = CalibrationEngine(screenSize: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(engine.calibrationPoints.count, 9)
    }

    func testCalibrationPointsCoverCorners() {
        let engine = CalibrationEngine(screenSize: CGSize(width: 1920, height: 1080))
        let points = engine.calibrationPoints
        XCTAssertLessThan(points[0].x, 500)
        XCTAssertLessThan(points[0].y, 400)
        XCTAssertGreaterThan(points[8].x, 1400)
        XCTAssertGreaterThan(points[8].y, 700)
    }

    func testRecordingGazeVectorAdvancesPoint() {
        let engine = CalibrationEngine(screenSize: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(engine.currentPointIndex, 0)
        engine.recordGazeVector(CGPoint(x: 0.1, y: 0.1))
        XCTAssertEqual(engine.currentPointIndex, 1)
    }

    func testCompletionAfter9Points() {
        let engine = CalibrationEngine(screenSize: CGSize(width: 1920, height: 1080))
        for i in 0..<9 {
            let gaze = CGPoint(x: Double(i % 3) * 0.5, y: Double(i / 3) * 0.5)
            engine.recordGazeVector(gaze)
        }
        XCTAssertTrue(engine.isComplete)
    }
}
