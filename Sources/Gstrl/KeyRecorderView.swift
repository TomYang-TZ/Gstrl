import SwiftUI
import AppKit
import Carbon.HIToolbox

struct KeyRecorderView: View {
    let slot: GestureSlot
    @Binding var isRecording: Bool
    var onRecord: (KeyBinding) -> Void

    @State private var displayText: String = ""

    var body: some View {
        Button {
            isRecording = true
            displayText = "Press any key..."
        } label: {
            Text(isRecording ? displayText : GestureActionConfig.shared.binding(for: slot).displayName)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(isRecording ? .orange : .primary)
                .frame(minWidth: 70)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(isRecording ? Color.orange.opacity(0.1) : Color.secondary.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(isRecording ? .orange : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .background {
            if isRecording {
                KeyCaptureRepresentable { binding in
                    onRecord(binding)
                    isRecording = false
                } onCancel: {
                    isRecording = false
                }
            }
        }
    }
}

struct KeyCaptureRepresentable: NSViewRepresentable {
    var onCapture: (KeyBinding) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {}
}

class KeyCaptureNSView: NSView {
    var onCapture: ((KeyBinding) -> Void)?
    var onCancel: (() -> Void)?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startMonitoring()
    }

    override func removeFromSuperview() {
        stopMonitoring()
        super.removeFromSuperview()
    }

    private func startMonitoring() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .systemDefined]) { [weak self] event in
            guard let self else { return event }

            if event.type == .keyDown {
                if event.keyCode == UInt16(kVK_Escape) && !event.modifierFlags.contains(.shift) {
                    self.onCancel?()
                    self.stopMonitoring()
                    return nil
                }
                let binding = self.bindingFromKeyEvent(event)
                self.onCapture?(binding)
                self.stopMonitoring()
                return nil
            }

            if event.type == .systemDefined && event.subtype.rawValue == 8 {
                let data = event.data1
                let keyCode = UInt16((data & 0xFFFF0000) >> 16)
                let flags = data & 0x0000FFFF
                let isDown = (flags & 0x0100) == 0
                if isDown {
                    let binding = self.mediaBinding(keyCode)
                    self.onCapture?(binding)
                    self.stopMonitoring()
                    return nil
                }
            }

            return event
        }
    }

    private func stopMonitoring() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
    }

    private func bindingFromKeyEvent(_ event: NSEvent) -> KeyBinding {
        let mods = event.modifierFlags
        let shift = mods.contains(.shift)
        let control = mods.contains(.control)
        let option = mods.contains(.option)
        let command = mods.contains(.command)
        let displayName = buildDisplayName(keyCode: event.keyCode, shift: shift, control: control, option: option, command: command)

        return KeyBinding(
            keyCode: event.keyCode,
            shift: shift,
            control: control,
            option: option,
            command: command,
            isMediaKey: false,
            displayName: displayName
        )
    }

    private func mediaBinding(_ keyCode: UInt16) -> KeyBinding {
        let name: String = switch keyCode {
        case 16: "▶︎ Play/Pause"
        case 17: "⏭ Next"
        case 18: "⏮ Previous"
        case 19: "⏩ Fast Forward"
        case 20: "⏪ Rewind"
        default: "Media \(keyCode)"
        }
        return KeyBinding(keyCode: keyCode, shift: false, control: false, option: false, command: false, isMediaKey: true, displayName: name)
    }

    private func buildDisplayName(keyCode: UInt16, shift: Bool, control: Bool, option: Bool, command: Bool) -> String {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option { parts.append("⌥") }
        if shift { parts.append("⇧") }
        if command { parts.append("⌘") }

        let keyName = keyCodeToName(keyCode)
        parts.append(keyName)
        return parts.joined()
    }

    private func keyCodeToName(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Return: return "Enter"
        case kVK_Tab: return "Tab"
        case kVK_Space: return "Space"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "Fwd Del"
        case kVK_Escape: return "Esc"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "PgUp"
        case kVK_PageDown: return "PgDn"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        default: return "Key\(keyCode)"
        }
    }
}
