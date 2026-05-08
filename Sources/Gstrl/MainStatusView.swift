import SwiftUI

struct MainStatusView: View {
    @Bindable var appState: AppState
    var onToggle: () -> Void
    var onFPSChanged: ((Int32) -> Void)?
    @State private var gesturesExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.system(size: 36))
                .foregroundStyle(statusColor)

            Text(statusText)
                .font(.headline)

            HStack(spacing: 20) {
                VStack {
                    Text("Left (click/keys)")
                        .font(.caption)
                    Image(systemName: appState.isEnabled && appState.leftHandDetected ? "hand.raised.fill" : "hand.raised.slash")
                        .foregroundStyle(appState.isEnabled && appState.leftHandDetected ? .orange : .gray)
                }
                VStack {
                    Text("Right (cursor/swipe)")
                        .font(.caption)
                    Image(systemName: appState.isEnabled && appState.rightHandDetected ? "hand.raised.fill" : "hand.raised.slash")
                        .foregroundStyle(appState.isEnabled && appState.rightHandDetected ? .blue : .gray)
                        .scaleEffect(x: -1, y: 1)
                }
            }

            VStack(spacing: 4) {
                Text(appState.isEnabled && !appState.gestureLabel.isEmpty ? appState.gestureLabel : "—")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(appState.gestureLabel.isEmpty ? .quaternary : .primary)
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
            .frame(height: 50)

            Text(appState.debugInfo)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(height: 14)

            Button(appState.isEnabled ? "Disable" : "Enable") {
                onToggle()
            }
            .buttonStyle(.borderedProminent)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        gesturesExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text("Gestures")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(gesturesExpanded ? 90 : 0))
                    }
                }
                .buttonStyle(.plain)

                if gesturesExpanded {
                    gestureReferenceView
                        .transition(.opacity)
                }
            }
            .clipped()

            Divider()

            settingsView
        }
        .padding(20)
        .frame(width: 340)
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings").font(.caption.bold()).foregroundStyle(.secondary)

            HStack {
                Text("FPS").font(.caption)
                Spacer()
                Picker("", selection: $appState.fps) {
                    ForEach(AppState.FPS.allCases, id: \.self) { fps in
                        Text(fps.rawValue).tag(fps)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: appState.fps) { _, newValue in
                    onFPSChanged?(newValue.timescale)
                }
            }

            HStack {
                Text("Cursor").font(.caption)
                Slider(value: $appState.cursorSensitivity, in: 1.0...5.0, step: 0.5)
                Text(String(format: "%.1fx", appState.cursorSensitivity))
                    .font(.system(.caption2, design: .monospaced))
                    .frame(width: 30)
            }

            HStack {
                Text("Scroll").font(.caption)
                Slider(value: $appState.scrollSensitivity, in: 0.5...3.0, step: 0.25)
                Text(String(format: "%.1fx", appState.scrollSensitivity))
                    .font(.system(.caption2, design: .monospaced))
                    .frame(width: 30)
            }

            Toggle("Natural scroll", isOn: $appState.naturalScroll)
                .font(.caption)
        }
    }

    private var gestureReferenceView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                Text("LEFT HAND").font(.system(.caption2, design: .monospaced)).foregroundStyle(.orange)
                gestureRow("👌 Pinch", "Click")
                gestureRow("☝️ 1-3 fingers (hold)", "Press 1-3")
                gestureRow("✊ Fist (hold)", "Enter")
                gestureRow("🤙 Six (hold)", "Escape")
                gestureRow("✊✊ Both fists (hold)", "Speech-to-text")
            }

            Group {
                Text("RIGHT HAND").font(.system(.caption2, design: .monospaced)).foregroundStyle(.blue)
                gestureRow("👌 Pinch + move", "Drag cursor")
                gestureRow("🤙 Six (hold)", "Delete (repeats)")
                gestureRow("👆 Swipe ↑", "Up arrow")
                gestureRow("👇 Swipe ↓", "Down arrow")
                gestureRow("👈 Swipe ←", "Left arrow")
                gestureRow("👉 Swipe →", "Right arrow")
            }

            Group {
                Text("COMBO").font(.system(.caption2, design: .monospaced)).foregroundStyle(.purple)
                gestureRow("👌+✊ L pinch + R fist move", "Scroll")
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
