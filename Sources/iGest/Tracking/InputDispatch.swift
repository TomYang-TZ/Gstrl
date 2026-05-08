import Foundation
import AppKit
import Carbon.HIToolbox

enum GestureAction {
    case pressKey(UInt16)
    case pressModifiedKey(UInt16, shift: Bool, control: Bool, option: Bool, command: Bool)
    case click
}

enum InputDispatch {
    static func perform(_ action: GestureAction) {
        switch action {
        case .pressKey(let keyCode):
            postKey(keyCode: keyCode, flags: [])
        case .pressModifiedKey(let keyCode, let shift, let control, let option, let command):
            var flags: CGEventFlags = []
            if shift { flags.insert(.maskShift) }
            if control { flags.insert(.maskControl) }
            if option { flags.insert(.maskAlternate) }
            if command { flags.insert(.maskCommand) }
            postKey(keyCode: keyCode, flags: flags)
        case .click:
            postClick()
        }
    }

    private static func postKey(keyCode: UInt16, flags: CGEventFlags) {
        DispatchQueue.main.async {
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }
            down.flags = flags
            up.flags = flags
            down.post(tap: .cghidEventTap)
            usleep(30000)
            up.post(tap: .cghidEventTap)
        }
    }

    private static func postClick() {
        DispatchQueue.main.async {
            guard let pos = CGEvent(source: nil)?.location else { return }
            guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left),
                  let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left) else { return }
            down.post(tap: .cghidEventTap)
            usleep(50000)
            up.post(tap: .cghidEventTap)
        }
    }
}
