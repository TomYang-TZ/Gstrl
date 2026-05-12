import Vision

enum GestureClassifier {
    static func isPinching(_ obs: VNHumanHandPoseObservation, threshold: CGFloat = 0.035) -> Bool {
        guard let thumb = try? obs.recognizedPoint(.thumbTip),
              let index = try? obs.recognizedPoint(.indexTip),
              thumb.confidence > 0.3, index.confidence > 0.3 else { return false }
        return hypot(thumb.location.x - index.location.x, thumb.location.y - index.location.y) < threshold
    }

    static func countExtendedFingers(_ obs: VNHumanHandPoseObservation) -> Int {
        var count = 0
        let pairs: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
            (.indexTip, .indexPIP), (.middleTip, .middlePIP),
            (.ringTip, .ringPIP), (.littleTip, .littlePIP)
        ]
        for (tip, pip) in pairs {
            if let t = try? obs.recognizedPoint(tip), let p = try? obs.recognizedPoint(pip),
               t.confidence > 0.3, p.confidence > 0.3, t.location.y > p.location.y {
                count += 1
            }
        }
        return count
    }

    static func isFingersCrossed(_ left: VNHumanHandPoseObservation, _ right: VNHumanHandPoseObservation) -> Bool {
        guard let lTip = try? left.recognizedPoint(.indexTip),
              let rTip = try? right.recognizedPoint(.indexTip),
              let lPIP = try? left.recognizedPoint(.indexPIP),
              let rPIP = try? right.recognizedPoint(.indexPIP),
              lTip.confidence > 0.3, rTip.confidence > 0.3,
              lPIP.confidence > 0.3, rPIP.confidence > 0.3 else { return false }

        let tipDistance = hypot(lTip.location.x - rTip.location.x, lTip.location.y - rTip.location.y)
        guard tipDistance < 0.1 else { return false }

        let lDir = lTip.location.x - lPIP.location.x
        let rDir = rTip.location.x - rPIP.location.x
        return lDir * rDir < 0
    }

    static func isTwoFingerPinch(_ obs: VNHumanHandPoseObservation) -> Bool {
        guard let thumb = try? obs.recognizedPoint(.thumbTip),
              let index = try? obs.recognizedPoint(.indexTip),
              let middle = try? obs.recognizedPoint(.middleTip),
              thumb.confidence > 0.3, index.confidence > 0.3, middle.confidence > 0.3 else { return false }
        let thumbToIndex = hypot(thumb.location.x - index.location.x, thumb.location.y - index.location.y)
        let thumbToMiddle = hypot(thumb.location.x - middle.location.x, thumb.location.y - middle.location.y)
        let indexToMiddle = hypot(index.location.x - middle.location.x, index.location.y - middle.location.y)
        // All three fingertips must be close together (not just thumb near each independently)
        return thumbToIndex < 0.05 && thumbToMiddle < 0.05 && indexToMiddle < 0.05
    }

    static func isThumbPinky(_ obs: VNHumanHandPoseObservation) -> Bool {
        guard let thumbTip = try? obs.recognizedPoint(.thumbTip),
              let thumbIP = try? obs.recognizedPoint(.thumbIP),
              let littleTip = try? obs.recognizedPoint(.littleTip),
              let littlePIP = try? obs.recognizedPoint(.littlePIP),
              let indexTip = try? obs.recognizedPoint(.indexTip),
              let indexPIP = try? obs.recognizedPoint(.indexPIP),
              let middleTip = try? obs.recognizedPoint(.middleTip),
              let middlePIP = try? obs.recognizedPoint(.middlePIP),
              thumbTip.confidence > 0.3, littleTip.confidence > 0.3 else { return false }

        let pinkyExtended = littleTip.location.y > littlePIP.location.y
        let indexClosed = indexTip.location.y <= indexPIP.location.y
        let middleClosed = middleTip.location.y <= middlePIP.location.y
        let thumbExtended = hypot(thumbTip.location.x - thumbIP.location.x,
                                  thumbTip.location.y - thumbIP.location.y) > 0.03

        return thumbExtended && pinkyExtended && indexClosed && middleClosed
    }
}
