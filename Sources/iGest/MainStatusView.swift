import SwiftUI

struct MainStatusView: View {
    @Bindable var appState: AppState
    var onToggle: () -> Void
    var onRecalibrate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: statusIcon)
                .font(.system(size: 48))
                .foregroundStyle(statusColor)

            Text(statusText)
                .font(.headline)

            HStack(spacing: 12) {
                Button(appState.isEnabled ? "Disable" : "Enable") {
                    onToggle()
                }
                .buttonStyle(.borderedProminent)

                Button("Recalibrate") {
                    onRecalibrate()
                }
                .disabled(!appState.isEnabled)
            }
        }
        .padding(24)
        .frame(width: 320, height: 200)
    }

    private var statusIcon: String {
        guard appState.isEnabled else { return "eye.slash" }
        switch appState.trackingState {
        case .inactive: return "eye"
        case .tracking: return "eye.fill"
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
        case .inactive: return "Ready — waiting for hand"
        case .tracking: return "Tracking gaze"
        case .pinching: return "Pinching — click!"
        }
    }
}
