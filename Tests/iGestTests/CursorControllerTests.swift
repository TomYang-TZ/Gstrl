import XCTest
@testable import iGest

final class CursorControllerTests: XCTestCase {
    var controller: CursorController!
    var postedEvents: [(type: CursorController.EventType, point: CGPoint)]!

    override func setUp() {
        postedEvents = []
        controller = CursorController(postEvent: { [unowned self] type, point in
            self.postedEvents.append((type, point))
        })
    }

    func testTrackingStatePostsMouseMoved() {
        controller.update(state: .tracking, gazePoint: CGPoint(x: 500, y: 300))
        XCTAssertEqual(postedEvents.count, 1)
        XCTAssertEqual(postedEvents[0].type, .mouseMoved)
        XCTAssertEqual(postedEvents[0].point, CGPoint(x: 500, y: 300))
    }

    func testInactivePostsNothing() {
        controller.update(state: .inactive, gazePoint: CGPoint(x: 500, y: 300))
        XCTAssertTrue(postedEvents.isEmpty)
    }

    func testPinchingPostsMouseDown() {
        controller.update(state: .tracking, gazePoint: CGPoint(x: 500, y: 300))
        postedEvents.removeAll()
        controller.update(state: .pinching, gazePoint: CGPoint(x: 500, y: 300))
        XCTAssertEqual(postedEvents.count, 1)
        XCTAssertEqual(postedEvents[0].type, .leftMouseDown)
    }

    func testPinchToTrackingPostsMouseUp() {
        controller.update(state: .pinching, gazePoint: CGPoint(x: 500, y: 300))
        postedEvents.removeAll()
        controller.update(state: .tracking, gazePoint: CGPoint(x: 500, y: 300))
        XCTAssertEqual(postedEvents.count, 2)
        XCTAssertEqual(postedEvents[0].type, .leftMouseUp)
        XCTAssertEqual(postedEvents[1].type, .mouseMoved)
    }

    func testPinchToInactivePostsMouseUp() {
        controller.update(state: .pinching, gazePoint: CGPoint(x: 500, y: 300))
        postedEvents.removeAll()
        controller.update(state: .inactive, gazePoint: CGPoint(x: 500, y: 300))
        XCTAssertEqual(postedEvents.count, 1)
        XCTAssertEqual(postedEvents[0].type, .leftMouseUp)
    }

    func testEmergencyKillFromPinching() {
        controller.update(state: .pinching, gazePoint: CGPoint(x: 500, y: 300))
        postedEvents.removeAll()
        controller.emergencyKill()
        XCTAssertEqual(postedEvents.count, 1)
        XCTAssertEqual(postedEvents[0].type, .leftMouseUp)
    }

    func testEmergencyKillFromTrackingPostsNothing() {
        controller.update(state: .tracking, gazePoint: CGPoint(x: 500, y: 300))
        postedEvents.removeAll()
        controller.emergencyKill()
        XCTAssertTrue(postedEvents.isEmpty)
    }
}
