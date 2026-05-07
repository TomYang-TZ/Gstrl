import XCTest
@testable import iGest

final class HandTrackerTests: XCTestCase {

    func testNoHandDetectedReturnsInactive() {
        let tracker = HandTracker()
        let state = tracker.classify(handLandmarks: nil)
        XCTAssertEqual(state, .inactive)
    }

    func testAllFingersExtendedReturnsPalmOpen() {
        let tracker = HandTracker()
        let landmarks = MockHandLandmarks.palmOpen()
        let state = tracker.classify(handLandmarks: landmarks, elapsed: 0.05)
        XCTAssertEqual(state, .tracking)
    }

    func testThumbIndexCloseReturnsPinching() {
        let tracker = HandTracker()
        let landmarks = MockHandLandmarks.pinching()
        let state = tracker.classify(handLandmarks: landmarks, elapsed: 0.05)
        XCTAssertEqual(state, .pinching)
    }

    func testDebouncingPreventsFlicker() {
        let tracker = HandTracker()
        _ = tracker.classify(handLandmarks: MockHandLandmarks.palmOpen(), elapsed: 0.05)
        let state = tracker.classify(handLandmarks: MockHandLandmarks.pinching(), elapsed: 0.01)
        XCTAssertEqual(state, .tracking)
    }
}

enum MockHandLandmarks {
    static func palmOpen() -> HandTracker.HandLandmarks {
        HandTracker.HandLandmarks(
            thumbTip: CGPoint(x: 0.2, y: 0.8),
            indexTip: CGPoint(x: 0.4, y: 0.9),
            middleTip: CGPoint(x: 0.5, y: 0.9),
            ringTip: CGPoint(x: 0.6, y: 0.9),
            littleTip: CGPoint(x: 0.7, y: 0.85),
            thumbIP: CGPoint(x: 0.25, y: 0.6),
            indexPIP: CGPoint(x: 0.4, y: 0.6),
            middlePIP: CGPoint(x: 0.5, y: 0.6),
            ringPIP: CGPoint(x: 0.6, y: 0.6),
            littlePIP: CGPoint(x: 0.7, y: 0.6),
            confidence: 0.9
        )
    }

    static func pinching() -> HandTracker.HandLandmarks {
        HandTracker.HandLandmarks(
            thumbTip: CGPoint(x: 0.4, y: 0.7),
            indexTip: CGPoint(x: 0.42, y: 0.72),
            middleTip: CGPoint(x: 0.5, y: 0.9),
            ringTip: CGPoint(x: 0.6, y: 0.9),
            littleTip: CGPoint(x: 0.7, y: 0.85),
            thumbIP: CGPoint(x: 0.35, y: 0.6),
            indexPIP: CGPoint(x: 0.4, y: 0.6),
            middlePIP: CGPoint(x: 0.5, y: 0.6),
            ringPIP: CGPoint(x: 0.6, y: 0.6),
            littlePIP: CGPoint(x: 0.7, y: 0.6),
            confidence: 0.9
        )
    }
}
