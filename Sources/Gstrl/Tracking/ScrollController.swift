import Foundation
import Vision
import AppKit

final class ScrollController {
    private var anchor: CGFloat?
    private let deadZone: CGFloat = 0.015
    private let maxSpeed: CGFloat = 20.0

    func reset() {
        anchor = nil
    }

    func process(_ hand: VNHumanHandPoseObservation) {
        guard let wrist = try? hand.recognizedPoint(.wrist), wrist.confidence > 0.3 else { return }

        let currentY = wrist.location.y
        if anchor == nil {
            anchor = currentY
            return
        }

        let displacement = currentY - anchor!

        // Dead zone — small movements don't scroll
        guard abs(displacement) > deadZone else { return }

        let sign: CGFloat = displacement > 0 ? 1 : -1
        let magnitude = abs(displacement) - deadZone
        let normalized = magnitude / 0.1  // 0.1 units = full speed
        let speed = min(maxSpeed, normalized * maxSpeed)
        let scrollAmount = Int32(sign * speed)

        if scrollAmount != 0 {
            if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: scrollAmount, wheel2: 0, wheel3: 0) {
                event.post(tap: .cghidEventTap)
            }
        }
    }
}
