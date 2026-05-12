import Foundation
import AppKit
import Vision

final class CursorDragController {
    private var anchor: CGPoint?
    private var cursorAnchor: CGPoint?
    var sensitivity: CGFloat = 2.5
    private let totalBounds: CGRect
    private var isDragging = false

    private var smoothedPosition: CGPoint?
    private var doubleSmoothed: CGPoint?
    private var previousSmoothed: CGPoint?
    private let smoothingFactor: CGFloat = 0.55
    private let secondSmoothing: CGFloat = 0.4
    private let deadZone: CGFloat = 0.001
    private let minVelocity: CGFloat = 0.0001

    private var pathBuffer: [CGPoint] = []
    var onCircleScreenshot: ((_ rect: CGRect) -> Void)?
    var onCursorMove: ((_ pos: CGPoint) -> Void)?
    var onCursorStart: (() -> Void)?
    var onCursorEnd: (() -> Void)?

    init() {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        if displayCount > 0 {
            var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
            CGGetActiveDisplayList(displayCount, &displays, &displayCount)
            totalBounds = displays.reduce(CGRect.null) { $0.union(CGDisplayBounds($1)) }
        } else {
            totalBounds = CGRect(x: 0, y: 0, width: 1512, height: 982)
        }
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
        let wasActive = anchor != nil
        anchor = nil
        cursorAnchor = nil
        smoothedPosition = nil
        doubleSmoothed = nil
        previousSmoothed = nil
        if wasActive { onCursorEnd?() }
    }

    func process(_ obs: VNHumanHandPoseObservation, holdingClick: Bool) {
        guard let palmCenter = palmPosition(obs) else { return }

        let current = palmCenter
        if anchor == nil {
            anchor = current
            cursorAnchor = CGEvent(source: nil)?.location ?? .zero
            smoothedPosition = current
            doubleSmoothed = current
            previousSmoothed = current
            pathBuffer.removeAll()
            onCursorStart?()
            if holdingClick && !isDragging {
                pressMouseDown()
            }
        } else if let anc = anchor, let curAnc = cursorAnchor {
            // Double exponential smoothing
            let prev = smoothedPosition ?? current
            let smoothed = CGPoint(
                x: smoothingFactor * current.x + (1 - smoothingFactor) * prev.x,
                y: smoothingFactor * current.y + (1 - smoothingFactor) * prev.y
            )
            smoothedPosition = smoothed

            let prevDouble = doubleSmoothed ?? smoothed
            let final = CGPoint(
                x: secondSmoothing * smoothed.x + (1 - secondSmoothing) * prevDouble.x,
                y: secondSmoothing * smoothed.y + (1 - secondSmoothing) * prevDouble.y
            )
            doubleSmoothed = final

            // Velocity gate — skip if movement is below noise floor
            let velocity = hypot(final.x - (previousSmoothed ?? final).x,
                                 final.y - (previousSmoothed ?? final).y)
            previousSmoothed = final

            // Dead zone — ignore sub-threshold displacement from anchor
            let displacement = hypot(final.x - anc.x, final.y - anc.y)
            guard displacement > deadZone && velocity > minVelocity else {
                if !holdingClick && isDragging { releaseMouseDown() }
                return
            }

            let deltaX = -(final.x - anc.x) * totalBounds.width * sensitivity
            let deltaY = -(final.y - anc.y) * totalBounds.height * sensitivity
            let newX = max(totalBounds.minX, min(totalBounds.maxX, curAnc.x + deltaX))
            let newY = max(totalBounds.minY, min(totalBounds.maxY, curAnc.y + deltaY))
            let pos = CGPoint(x: newX, y: newY)

            pathBuffer.append(pos)

            if holdingClick {
                if !isDragging { pressMouseDown() }
                if let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: pos, mouseButton: .left) {
                    event.post(tap: .cghidEventTap)
                }
            }
            CGWarpMouseCursorPosition(pos)
            if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: pos, mouseButton: .left) {
                moveEvent.post(tap: .cghidEventTap)
            }
            onCursorMove?(pos)
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
        guard pathBuffer.count >= 12 else { return nil }

        let points = pathBuffer

        // Centroid
        let cx = points.map(\.x).reduce(0, +) / CGFloat(points.count)
        let cy = points.map(\.y).reduce(0, +) / CGFloat(points.count)

        // Average radius
        let radii = points.map { hypot($0.x - cx, $0.y - cy) }
        let avgRadius = radii.reduce(0, +) / CGFloat(radii.count)

        // Need at least 50px radius to be intentional
        guard avgRadius > 30 else { return nil }

        // Radius consistency
        let radiusVariance = radii.map { ($0 - avgRadius) * ($0 - avgRadius) }.reduce(0, +) / CGFloat(radii.count)
        let radiusStdDev = sqrt(radiusVariance)
        guard radiusStdDev / avgRadius < 0.4 else { return nil }

        // Closure check (start near end)
        let start = points.first!
        let end = points.last!
        let closureDist = hypot(end.x - start.x, end.y - start.y)
        guard closureDist < avgRadius * 0.8 else { return nil }

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

        guard abs(totalAngle) > 4.0 else { return nil }

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
