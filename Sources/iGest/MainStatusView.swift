import SwiftUI

struct MainStatusView: View {
    @Bindable var appState: AppState
    var onToggle: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: statusIcon)
                .font(.system(size: 48))
                .foregroundStyle(statusColor)

            Text(statusText)
                .font(.headline)

            Text("Works with macOS Head Pointer")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(appState.isEnabled ? "Disable" : "Enable") {
                onToggle()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 300, height: 180)
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
