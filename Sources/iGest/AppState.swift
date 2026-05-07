import SwiftUI

@Observable
final class AppState {
    var isEnabled: Bool = false
    var trackingState: TrackingState = .inactive
    var sensitivity: Sensitivity = .medium
    var isCalibrated: Bool = false

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
