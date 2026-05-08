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
                        Text("Right (cursor/swipe)")
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
                            HStack(spacing: 4) {
                                Text(appState.progressMode == .countdown ? "HOLD" : "COOL")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(appState.progressMode == .countdown ? .orange : .green)
                                ProgressView(value: appState.gestureProgress)
                                    .tint(appState.progressMode == .countdown ? .orange : .green)
                                    .frame(width: 120)
                                    .animation(.linear(duration: 0.1), value: appState.gestureProgress)
                            }
                        }
                    }
                }

                Text(appState.debugInfo)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)

                Divider()

                gestureReferenceView
            }

            Button(appState.isEnabled ? "Disable" : "Enable") {
                onToggle()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(width: 340, height: appState.isEnabled ? 520 : 280)
    }

    private var gestureReferenceView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Gestures")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Group {
                Text("LEFT HAND").font(.system(.caption2, design: .monospaced)).foregroundStyle(.orange)
                gestureRow("👌 Pinch", "Click")
                gestureRow("☝️ 1-3 fingers (hold)", "Press 1-3")
                gestureRow("✊ Fist (hold)", "Enter")
                gestureRow("🤙 Thumb+pinky (hold)", "Escape")
                gestureRow("🖐🖐 Both open (hold)", "Speech-to-text")
            }

            Group {
                Text("RIGHT HAND").font(.system(.caption2, design: .monospaced)).foregroundStyle(.blue)
                gestureRow("👌 Pinch + move", "Drag cursor")
                gestureRow("🤙 Thumb+pinky (hold)", "Delete (repeats)")
                gestureRow("👆 Swipe ↑", "Up arrow")
                gestureRow("👇 Swipe ↓", "Down arrow")
                gestureRow("👈 Swipe ←", "Left arrow")
                gestureRow("👉 Swipe →", "Right arrow")
            }

            Group {
                Text("COMBO").font(.system(.caption2, design: .monospaced)).foregroundStyle(.purple)
                gestureRow("🖐+👈 Open left + swipe ←", "Shift+Tab")
                gestureRow("🖐+👉 Open left + swipe →", "Tab")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func gestureRow(_ gesture: String, _ action: String) -> some View {
        HStack {
            Text(gesture)
                .font(.system(.caption2, design: .rounded))
            Spacer()
            Text(action)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
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
