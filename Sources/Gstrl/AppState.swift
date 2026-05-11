import SwiftUI
import AppKit

@Observable
final class AppState {
    var isEnabled: Bool = false
    @ObservationIgnored var trackingState: TrackingState = .inactive
    @ObservationIgnored var isCalibrated: Bool = false
    var leftHandDetected: Bool = false
    var rightHandDetected: Bool = false
    @ObservationIgnored var handsCount: Int = 0
    var debugInfo: String = ""
    var gestureLabel: String = ""
    @ObservationIgnored var gestureProgress: Double = 0.0
    var progressMode: ProgressMode = .countdown
    @ObservationIgnored var gestureHand: GestureHand = .none
    var gestureCountdownStart: Date?
    var gestureCountdownDuration: TimeInterval = 1.0

    enum GestureHand {
        case left, right, both, none
    }
    var screenshotPreview: NSImage? = nil
    var speechTranscript: String = ""

    // Agent mode
    var agentActive: Bool = false
    var agentSpeaking: Bool = false
    var agentSilenceStart: Date?
    var agentResponse: String = ""
    var agentTranscript: String = ""
    var agentHistory: [AgentEntry] = []
    var agentSelectedLines: Int = 0
    var agentThinking: String = ""
    var agentCurrentAction: String = ""
    @ObservationIgnored var islandHeight: CGFloat = 36

    struct AgentAction: Identifiable {
        let id = UUID()
        let tool: String
        let summary: String
    }

    struct AgentEntry: Identifiable {
        let id = UUID()
        let sessionId: String
        let query: String
        let response: String
        let screenshotPath: String?
        let durationMs: Int
        let turns: Int
        let costUSD: Double
        let actions: [AgentAction]
        let timestamp: Date

        init(sessionId: String, query: String, response: String, screenshotPath: String? = nil, durationMs: Int = 0, turns: Int = 0, costUSD: Double = 0, actions: [AgentAction] = []) {
            self.sessionId = sessionId
            self.query = query
            self.response = response
            self.screenshotPath = screenshotPath
            self.durationMs = durationMs
            self.turns = turns
            self.costUSD = costUSD
            self.actions = actions
            self.timestamp = Date()
        }
    }

    // User-configurable settings
    var fps: FPS = .thirty
    var cursorSensitivity: Double = 3.5
    var scrollSensitivity: Double = 1.0
    var naturalScroll: Bool = false
    var speechLanguage: SpeechLanguage = .english

    enum ProgressMode {
        case countdown
        case cooldown
    }

    enum SpeechLanguage: String, CaseIterable {
        case english = "EN"
        case chinese = "中文"
        case cantonese = "粵語"
        case spanish = "ES"

        var localeIdentifier: String {
            switch self {
            case .english: return "en-US"
            case .chinese: return "zh-Hans"
            case .cantonese: return "zh-HK"
            case .spanish: return "es-ES"
            }
        }
    }

    enum FPS: String, CaseIterable {
        case fifteen = "15"
        case thirty = "30"
        case sixty = "60"
        case ninety = "90"
        case onetwenty = "120"

        var timescale: Int32 {
            switch self {
            case .fifteen: return 15
            case .thirty: return 30
            case .sixty: return 60
            case .ninety: return 90
            case .onetwenty: return 120
            }
        }
    }
}
