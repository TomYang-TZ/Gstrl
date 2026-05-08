import Foundation
import Vision
import AppKit

final class ScrollController {
    private var anchor: CGFloat?
    private let sensitivity: CGFloat = 1500.0

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

        let delta = currentY - anchor!
        let scrollAmount = Int32(delta * sensitivity)
        if scrollAmount != 0 {
            anchor = currentY
            if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: scrollAmount, wheel2: 0, wheel3: 0) {
                event.post(tap: .cghidEventTap)
            }
        }
    }
}
