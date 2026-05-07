import Vision
import Foundation

final class HandTracker {
    private var lastState: TrackingState = .inactive
    private var lastTransitionTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.15

    struct HandLandmarks {
        let thumbTip: CGPoint
        let indexTip: CGPoint
        let middleTip: CGPoint
        let ringTip: CGPoint
        let littleTip: CGPoint
        let thumbIP: CGPoint
        let indexPIP: CGPoint
        let middlePIP: CGPoint
        let ringPIP: CGPoint
        let littlePIP: CGPoint
        let confidence: Float
    }

    @discardableResult
    func classify(handLandmarks: HandLandmarks?, elapsed: TimeInterval = 0.033) -> TrackingState {
        guard let landmarks = handLandmarks, landmarks.confidence > 0.3 else {
            return applyDebounce(.inactive, elapsed: elapsed)
        }

        let pinchDistance = hypot(
            landmarks.thumbTip.x - landmarks.indexTip.x,
            landmarks.thumbTip.y - landmarks.indexTip.y
        )

        // Hysteresis: enter pinch at < 0.06, exit pinch at > 0.10
        if lastState == .pinching {
            if pinchDistance < 0.10 {
                return applyDebounce(.pinching, elapsed: elapsed)
            }
        } else {
            if pinchDistance < 0.06 {
                return applyDebounce(.pinching, elapsed: elapsed)
            }
        }

        let fingersExtended = landmarks.indexTip.y > landmarks.indexPIP.y
            && landmarks.middleTip.y > landmarks.middlePIP.y

        if fingersExtended {
            return applyDebounce(.tracking, elapsed: elapsed)
        }

        return applyDebounce(.inactive, elapsed: elapsed)
    }

    private func applyDebounce(_ newState: TrackingState, elapsed: TimeInterval) -> TrackingState {
        lastTransitionTime += elapsed
        if newState != lastState && lastTransitionTime >= debounceInterval {
            lastState = newState
            lastTransitionTime = 0
        }
        return lastState
    }

    func processObservation(_ observation: VNHumanHandPoseObservation) -> HandLandmarks? {
        guard let thumbTip = try? observation.recognizedPoint(.thumbTip),
              let indexTip = try? observation.recognizedPoint(.indexTip),
              let middleTip = try? observation.recognizedPoint(.middleTip),
              let ringTip = try? observation.recognizedPoint(.ringTip),
              let littleTip = try? observation.recognizedPoint(.littleTip),
              let thumbIP = try? observation.recognizedPoint(.thumbIP),
              let indexPIP = try? observation.recognizedPoint(.indexPIP),
              let middlePIP = try? observation.recognizedPoint(.middlePIP),
              let ringPIP = try? observation.recognizedPoint(.ringPIP),
              let littlePIP = try? observation.recognizedPoint(.littlePIP)
        else { return nil }

        return HandLandmarks(
            thumbTip: CGPoint(x: thumbTip.location.x, y: thumbTip.location.y),
            indexTip: CGPoint(x: indexTip.location.x, y: indexTip.location.y),
            middleTip: CGPoint(x: middleTip.location.x, y: middleTip.location.y),
            ringTip: CGPoint(x: ringTip.location.x, y: ringTip.location.y),
            littleTip: CGPoint(x: littleTip.location.x, y: littleTip.location.y),
            thumbIP: CGPoint(x: thumbIP.location.x, y: thumbIP.location.y),
            indexPIP: CGPoint(x: indexPIP.location.x, y: indexPIP.location.y),
            middlePIP: CGPoint(x: middlePIP.location.x, y: middlePIP.location.y),
            ringPIP: CGPoint(x: ringPIP.location.x, y: ringPIP.location.y),
            littlePIP: CGPoint(x: littlePIP.location.x, y: littlePIP.location.y),
            confidence: thumbTip.confidence
        )
    }
}
