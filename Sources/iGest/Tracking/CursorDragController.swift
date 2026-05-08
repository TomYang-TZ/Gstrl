import Foundation
import AppKit
import Vision

final class CursorDragController {
    private var anchor: CGPoint?
    private var cursorAnchor: CGPoint?
    private let sensitivity: CGFloat = 2.5
    private let screenW: CGFloat
    private let screenH: CGFloat
    private var isDragging = false

    init() {
        let screen = NSScreen.main?.frame.size ?? CGSize(width: 1512, height: 982)
        screenW = screen.width
        screenH = screen.height
    }

    func reset() {
        if isDragging {
            releaseMouseDown()
        }
        anchor = nil
        cursorAnchor = nil
    }

    func process(_ obs: VNHumanHandPoseObservation, holdingClick: Bool) {
        guard let wrist = try? obs.recognizedPoint(.wrist), wrist.confidence > 0.3 else { return }

        let currentWrist = CGPoint(x: wrist.location.x, y: wrist.location.y)
        if anchor == nil {
            anchor = currentWrist
            cursorAnchor = CGEvent(source: nil)?.location ?? .zero
            if holdingClick && !isDragging {
                pressMouseDown()
            }
        } else if let anc = anchor, let curAnc = cursorAnchor {
            let deltaX = -(currentWrist.x - anc.x) * screenW * sensitivity
            let deltaY = -(currentWrist.y - anc.y) * screenH * sensitivity
            let newX = max(0, min(screenW, curAnc.x + deltaX))
            let newY = max(0, min(screenH, curAnc.y + deltaY))
            let pos = CGPoint(x: newX, y: newY)

            if holdingClick {
                if !isDragging { pressMouseDown() }
                if let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: pos, mouseButton: .left) {
                    event.post(tap: .cghidEventTap)
                }
            }
            CGWarpMouseCursorPosition(pos)
        }

        if !holdingClick && isDragging {
            releaseMouseDown()
        }
    }

    private func pressMouseDown() {
        isDragging = true
        let pos = CGEvent(source: nil)?.location ?? .zero
        if let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left) {
            event.post(tap: .cghidEventTap)
        }
    }

    private func releaseMouseDown() {
        isDragging = false
        let pos = CGEvent(source: nil)?.location ?? .zero
        if let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left) {
            event.post(tap: .cghidEventTap)
        }
    }
}
