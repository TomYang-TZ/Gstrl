import XCTest
@testable import iGest

final class SmoothingFilterTests: XCTestCase {

    func testFirstValuePassesThrough() {
        let filter = SmoothingFilter(alpha: 0.3)
        let result = filter.apply(CGPoint(x: 100, y: 200))
        XCTAssertEqual(result.x, 100, accuracy: 0.01)
        XCTAssertEqual(result.y, 200, accuracy: 0.01)
    }

    func testSmoothingReducesJump() {
        let filter = SmoothingFilter(alpha: 0.3)
        _ = filter.apply(CGPoint(x: 100, y: 100))
        let result = filter.apply(CGPoint(x: 200, y: 200))
        XCTAssertEqual(result.x, 130, accuracy: 0.01)
        XCTAssertEqual(result.y, 130, accuracy: 0.01)
    }

    func testHighAlphaIsMoreResponsive() {
        let filter = SmoothingFilter(alpha: 0.8)
        _ = filter.apply(CGPoint(x: 100, y: 100))
        let result = filter.apply(CGPoint(x: 200, y: 200))
        XCTAssertEqual(result.x, 180, accuracy: 0.01)
        XCTAssertEqual(result.y, 180, accuracy: 0.01)
    }

    func testResetClearsState() {
        let filter = SmoothingFilter(alpha: 0.3)
        _ = filter.apply(CGPoint(x: 100, y: 100))
        filter.reset()
        let result = filter.apply(CGPoint(x: 500, y: 500))
        XCTAssertEqual(result.x, 500, accuracy: 0.01)
    }
}
