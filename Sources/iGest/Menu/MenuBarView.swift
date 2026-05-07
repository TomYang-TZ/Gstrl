import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            Toggle(appState.isEnabled ? "Disable iGest" : "Enable iGest",
                   isOn: Bindable(appState).isEnabled)
            Divider()
            Button("Recalibrate") {
                NotificationCenter.default.post(name: Notification.Name("igest.recalibrate"), object: nil)
            }
            .disabled(!appState.isEnabled)
            Menu("Sensitivity") {
                ForEach(AppState.Sensitivity.allCases, id: \.self) { level in
                    Button {
                        appState.sensitivity = level
                    } label: {
                        HStack {
                            Text(level.rawValue.capitalized)
                            if appState.sensitivity == level {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Divider()
            Text("Kill: ⎋ Escape")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
