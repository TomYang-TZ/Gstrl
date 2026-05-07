import Foundation
import CoreGraphics

final class CursorController {
    enum EventType: Equatable {
        case mouseMoved
        case leftMouseDown
        case leftMouseUp
    }

    var currentState: TrackingState = .inactive
    private var previousState: TrackingState = .inactive
    private var isKilled = false
    private let postEvent: (EventType, CGPoint) -> Void

    init(postEvent: @escaping (EventType, CGPoint) -> Void) {
        self.postEvent = postEvent
    }

    convenience init() {
        self.init { type, point in
            CursorController.postCGEvent(type: type, point: point)
        }
    }

    func update(state: TrackingState, gazePoint: CGPoint) {
        guard !isKilled else { return }

        if previousState == .pinching && state != .pinching {
            postEvent(.leftMouseUp, gazePoint)
        }

        switch state {
        case .tracking:
            postEvent(.mouseMoved, gazePoint)
        case .pinching:
            if previousState != .pinching {
                postEvent(.leftMouseDown, gazePoint)
            }
        case .inactive:
            break
        }

        previousState = state
        currentState = state
    }

    func emergencyKill() {
        if previousState == .pinching {
            postEvent(.leftMouseUp, .zero)
        }
        previousState = .inactive
        isKilled = true
    }

    func reenable() {
        isKilled = false
    }

    private static func postCGEvent(type: EventType, point: CGPoint) {
        let cgEventType: CGEventType
        let mouseButton: CGMouseButton

        switch type {
        case .mouseMoved:
            cgEventType = .mouseMoved
            mouseButton = .left
        case .leftMouseDown:
            cgEventType = .leftMouseDown
            mouseButton = .left
        case .leftMouseUp:
            cgEventType = .leftMouseUp
            mouseButton = .left
        }

        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: cgEventType,
            mouseCursorPosition: point,
            mouseButton: mouseButton
        ) else { return }

        event.post(tap: .cghidEventTap)
    }
}
