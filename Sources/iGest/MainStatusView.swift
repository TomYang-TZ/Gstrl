import SwiftUI

struct MainStatusView: View {
    @Bindable var appState: AppState
    var onToggle: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.system(size: 36))
                .foregroundStyle(statusColor)

            Text(statusText)
                .font(.headline)

            if appState.isEnabled {
                HStack(spacing: 20) {
                    VStack {
                        Text("Left (click/keys)")
                            .font(.caption)
                        Image(systemName: appState.leftHandDetected ? "hand.raised.fill" : "hand.raised.slash")
                            .foregroundStyle(appState.leftHandDetected ? .orange : .gray)
                    }
                    VStack {
                        Text("Right (cursor)")
                            .font(.caption)
                        Image(systemName: appState.rightHandDetected ? "hand.raised.fill" : "hand.raised.slash")
                            .foregroundStyle(appState.rightHandDetected ? .blue : .gray)
                    }
                }

                if !appState.gestureLabel.isEmpty {
                    VStack(spacing: 4) {
                        Text(appState.gestureLabel)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        if appState.gestureProgress > 0 {
                            let remaining = 1.0 * (1.0 - appState.gestureProgress)
                            Text(String(format: "%.1fs", remaining))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.orange)
                            ProgressView(value: appState.gestureProgress)
                                .tint(.orange)
                                .frame(width: 150)
                        }
                    }
                }

                Text(appState.debugInfo)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Button(appState.isEnabled ? "Disable" : "Enable") {
                onToggle()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(width: 320, height: 280)
    }

    private var statusIcon: String {
        guard appState.isEnabled else { return "hand.point.up" }
        switch appState.trackingState {
        case .inactive: return "hand.raised"
        case .tracking: return "hand.raised.fill"
        case .pinching: return "hand.pinch.fill"
        }
    }

    private var statusColor: Color {
        guard appState.isEnabled else { return .gray }
        switch appState.trackingState {
        case .inactive: return .green
        case .tracking: return .blue
        case .pinching: return .orange
        }
    }

    private var statusText: String {
        guard appState.isEnabled else { return "Disabled" }
        switch appState.trackingState {
        case .inactive: return "Waiting for hand..."
        case .tracking: return "Hand detected"
        case .pinching: return "Click!"
        }
    }
}
