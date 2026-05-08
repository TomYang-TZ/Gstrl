import SwiftUI
import AppKit

@Observable
final class AppState {
    var isEnabled: Bool = false
    var trackingState: TrackingState = .inactive
    var isCalibrated: Bool = false
    var leftHandDetected: Bool = false
    var rightHandDetected: Bool = false
    var handsCount: Int = 0
    var debugInfo: String = ""
    var gestureLabel: String = ""
    var gestureProgress: Double = 0.0
    var progressMode: ProgressMode = .countdown
    var screenshotPreview: NSImage? = nil

    // User-configurable settings
    var fps: FPS = .sixty
    var cursorSensitivity: Double = 2.5
    var scrollSensitivity: Double = 1.0

    enum ProgressMode {
        case countdown
        case cooldown
    }

    enum FPS: String, CaseIterable {
        case thirty = "30"
        case sixty = "60"
        case ninety = "90"
        case onetwenty = "120"

        var timescale: Int32 {
            switch self {
            case .thirty: return 30
            case .sixty: return 60
            case .ninety: return 90
            case .onetwenty: return 120
            }
        }
    }
}
