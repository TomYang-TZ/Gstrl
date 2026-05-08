import SwiftUI

@Observable
final class AppState {
    var isEnabled: Bool = false
    var trackingState: TrackingState = .inactive
    var sensitivity: Sensitivity = .medium
    var isCalibrated: Bool = false
    var leftHandDetected: Bool = false
    var rightHandDetected: Bool = false
    var handsCount: Int = 0
    var debugInfo: String = ""
    var gestureLabel: String = ""
    var gestureProgress: Double = 0.0
    var progressMode: ProgressMode = .countdown

    enum ProgressMode {
        case countdown  // filling up to activate
        case cooldown   // draining after action fired
    }

    enum Sensitivity: String, CaseIterable, Equatable {
        case low, medium, high

        var alpha: Double {
            switch self {
            case .low: return 0.15
            case .medium: return 0.3
            case .high: return 0.5
            }
        }
    }
}
