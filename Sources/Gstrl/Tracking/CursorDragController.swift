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

    private var pathBuffer: [CGPoint] = []
    var onCircleScreenshot: ((_ rect: CGRect) -> Void)?

    init() {
        let screen = NSScreen.main?.frame.size ?? CGSize(width: 1512, height: 982)
        screenW = screen.width
        screenH = screen.height
    }

    func reset() {
        if isDragging {
            releaseMouseDown()
        }
        if !pathBuffer.isEmpty {
            if let rect = detectCircleRegion() {
                onCircleScreenshot?(rect)
            }
            pathBuffer.removeAll()
        }
        anchor = nil
        cursorAnchor = nil
    }

    func process(_ obs: VNHumanHandPoseObservation, holdingClick: Bool) {
        guard let palmCenter = palmPosition(obs) else { return }

        let currentWrist = palmCenter
        if anchor == nil {
            anchor = currentWrist
            cursorAnchor = CGEvent(source: nil)?.location ?? .zero
            pathBuffer.removeAll()
            if holdingClick && !isDragging {
                pressMouseDown()
            }
        } else if let anc = anchor, let curAnc = cursorAnchor {
            let deltaX = -(currentWrist.x - anc.x) * screenW * sensitivity
            let deltaY = -(currentWrist.y - anc.y) * screenH * sensitivity
            let newX = max(0, min(screenW, curAnc.x + deltaX))
            let newY = max(0, min(screenH, curAnc.y + deltaY))
            let pos = CGPoint(x: newX, y: newY)

            pathBuffer.append(pos)

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

    private func palmPosition(_ obs: VNHumanHandPoseObservation) -> CGPoint? {
        let joints: [VNHumanHandPoseObservation.JointName] = [
            .indexMCP, .middleMCP, .ringMCP, .littleMCP
        ]
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        var count: CGFloat = 0
        for joint in joints {
            if let pt = try? obs.recognizedPoint(joint), pt.confidence > 0.3 {
                sumX += pt.location.x
                sumY += pt.location.y
                count += 1
            }
        }
        guard count >= 2 else { return nil }
        return CGPoint(x: sumX / count, y: sumY / count)
    }

    private func detectCircleRegion() -> CGRect? {
        guard pathBuffer.count >= 15 else { return nil }

        let points = pathBuffer

        // Centroid
        let cx = points.map(\.x).reduce(0, +) / CGFloat(points.count)
        let cy = points.map(\.y).reduce(0, +) / CGFloat(points.count)

        // Average radius
        let radii = points.map { hypot($0.x - cx, $0.y - cy) }
        let avgRadius = radii.reduce(0, +) / CGFloat(radii.count)

        // Need at least 50px radius to be intentional
        guard avgRadius > 50 else { return nil }

        // Radius consistency
        let radiusVariance = radii.map { ($0 - avgRadius) * ($0 - avgRadius) }.reduce(0, +) / CGFloat(radii.count)
        let radiusStdDev = sqrt(radiusVariance)
        guard radiusStdDev / avgRadius < 0.4 else { return nil }

        // Closure check (start near end)
        let start = points.first!
        let end = points.last!
        let closureDist = hypot(end.x - start.x, end.y - start.y)
        guard closureDist < avgRadius * 0.6 else { return nil }

        // Angular sweep check
        var totalAngle: CGFloat = 0
        for i in 1..<points.count {
            let a1 = atan2(points[i-1].y - cy, points[i-1].x - cx)
            let a2 = atan2(points[i].y - cy, points[i].x - cx)
            var delta = a2 - a1
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            totalAngle += delta
        }

        guard abs(totalAngle) > 4.7 else { return nil }

        // Return bounding rect of the circle in screen coordinates
        let minX = points.map(\.x).min()!
        let maxX = points.map(\.x).max()!
        let minY = points.map(\.y).min()!
        let maxY = points.map(\.y).max()!

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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
