import Foundation
import AppKit
import Vision

final class CursorDragController {
    private var anchor: CGPoint?
    private var cursorAnchor: CGPoint?
    private let sensitivity: CGFloat = 2.5
    private let screenW: CGFloat
    private let screenH: CGFloat

    init() {
        let screen = NSScreen.main?.frame.size ?? CGSize(width: 1512, height: 982)
        screenW = screen.width
        screenH = screen.height
    }

    func reset() {
        anchor = nil
        cursorAnchor = nil
    }

    func process(_ obs: VNHumanHandPoseObservation) {
        guard let wrist = try? obs.recognizedPoint(.wrist), wrist.confidence > 0.3 else { return }

        let currentWrist = CGPoint(x: wrist.location.x, y: wrist.location.y)
        if anchor == nil {
            anchor = currentWrist
            cursorAnchor = CGEvent(source: nil)?.location ?? .zero
        } else if let anc = anchor, let curAnc = cursorAnchor {
            let deltaX = -(currentWrist.x - anc.x) * screenW * sensitivity
            let deltaY = -(currentWrist.y - anc.y) * screenH * sensitivity
            let newX = max(0, min(screenW, curAnc.x + deltaX))
            let newY = max(0, min(screenH, curAnc.y + deltaY))
            CGWarpMouseCursorPosition(CGPoint(x: newX, y: newY))
        }
    }
}
