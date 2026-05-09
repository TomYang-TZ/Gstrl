import Foundation
import Vision
import AppKit

final class ScrollController {
    private var anchor: CGFloat?
    private var scrollStartTime: Date?
    private let deadZone: CGFloat = 0.015
    private let baseMaxSpeed: CGFloat = 40.0
    var sensitivityMultiplier: CGFloat = 1.0
    var naturalScroll: Bool = false

    func reset() {
        anchor = nil
        scrollStartTime = nil
    }

    func process(_ hand: VNHumanHandPoseObservation) {
        guard let wrist = try? hand.recognizedPoint(.wrist), wrist.confidence > 0.3 else { return }

        let currentY = wrist.location.y
        if anchor == nil {
            anchor = currentY
            scrollStartTime = Date()
            return
        }

        let displacement = currentY - anchor!

        // Dead zone — small movements don't scroll
        guard abs(displacement) > deadZone else { return }

        // Acceleration: speed multiplier increases over time (1x → 3x over 5 seconds)
        let elapsed = Date().timeIntervalSince(scrollStartTime ?? Date())
        let timeMultiplier = 1.0 + min(2.0, elapsed / 2.5)

        let direction: CGFloat = naturalScroll ? -1 : 1
        let sign: CGFloat = (displacement > 0 ? 1 : -1) * direction
        let magnitude = abs(displacement) - deadZone
        let normalized = magnitude / 0.1
        let maxSpeed = baseMaxSpeed * sensitivityMultiplier
        let speed = min(maxSpeed, normalized * maxSpeed * timeMultiplier)
        let scrollAmount = Int32(sign * speed)

        if scrollAmount != 0 {
            if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: scrollAmount, wheel2: 0, wheel3: 0) {
                event.post(tap: .cghidEventTap)
            }
        }
    }
}
