import Foundation
import Vision
import AppKit

final class ScrollController {
    private var anchor: CGFloat?
    private var lastFrameTime: Date?
    private var smoothedY: CGFloat?
    private let deadZone: CGFloat = 0.015
    private let baseMaxSpeed: CGFloat = 40.0
    var sensitivityMultiplier: CGFloat = 1.0
    var naturalScroll: Bool = false

    func reset() {
        anchor = nil
        lastFrameTime = nil
        smoothedY = nil
    }

    func process(_ hand: VNHumanHandPoseObservation) {
        guard let wrist = try? hand.recognizedPoint(.wrist), wrist.confidence > 0.3 else { return }

        let rawY = wrist.location.y
        let currentY = smoothedY.map { 0.6 * rawY + 0.4 * $0 } ?? rawY
        smoothedY = currentY
        if anchor == nil {
            anchor = currentY
            return
        }

        let displacement = currentY - anchor!

        guard abs(displacement) > deadZone else { return }

        let direction: CGFloat = naturalScroll ? -1 : 1
        let sign: CGFloat = (displacement > 0 ? 1 : -1) * direction
        let now = Date()
        let dt = lastFrameTime.map { now.timeIntervalSince($0) } ?? (1.0 / 30.0)
        lastFrameTime = now
        let frameScale = dt / (1.0 / 30.0)

        let magnitude = abs(displacement) - deadZone
        let normalized = magnitude / 0.1
        let maxSpeed = baseMaxSpeed * sensitivityMultiplier
        let speed = min(maxSpeed, normalized * maxSpeed) * frameScale
        let scrollAmount = Int32(sign * speed)

        if scrollAmount != 0 {
            if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: scrollAmount, wheel2: 0, wheel3: 0) {
                event.post(tap: .cghidEventTap)
            }
        }
    }
}
