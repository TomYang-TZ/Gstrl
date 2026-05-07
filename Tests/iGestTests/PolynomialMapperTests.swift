import XCTest
@testable import iGest

final class PolynomialMapperTests: XCTestCase {

    func testIdentityMappingWithLinearCalibration() {
        let gazePoints = [
            CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 0.5), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 1, y: 0.5),
            CGPoint(x: 0, y: 1), CGPoint(x: 0.5, y: 1), CGPoint(x: 1, y: 1)
        ]
        let screenPoints = gazePoints.map { CGPoint(x: $0.x * 1920, y: $0.y * 1080) }

        let mapper = PolynomialMapper()
        mapper.calibrate(gazePoints: gazePoints, screenPoints: screenPoints)

        let result = mapper.map(CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(result.x, 960, accuracy: 5)
        XCTAssertEqual(result.y, 540, accuracy: 5)
    }

    func testCornerAccuracy() {
        let gazePoints = [
            CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 0.5), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 1, y: 0.5),
            CGPoint(x: 0, y: 1), CGPoint(x: 0.5, y: 1), CGPoint(x: 1, y: 1)
        ]
        let screenPoints = gazePoints.map { CGPoint(x: $0.x * 1920, y: $0.y * 1080) }

        let mapper = PolynomialMapper()
        mapper.calibrate(gazePoints: gazePoints, screenPoints: screenPoints)

        let topLeft = mapper.map(CGPoint(x: 0, y: 0))
        XCTAssertEqual(topLeft.x, 0, accuracy: 5)
        XCTAssertEqual(topLeft.y, 0, accuracy: 5)

        let bottomRight = mapper.map(CGPoint(x: 1, y: 1))
        XCTAssertEqual(bottomRight.x, 1920, accuracy: 5)
        XCTAssertEqual(bottomRight.y, 1080, accuracy: 5)
    }

    func testUncalibratedReturnsZero() {
        let mapper = PolynomialMapper()
        let result = mapper.map(CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(result, .zero)
    }
}
