import Foundation
import AppKit
import Carbon.HIToolbox

enum GestureAction {
    case pressKey(UInt16)
    case pressModifiedKey(UInt16, shift: Bool, control: Bool, option: Bool, command: Bool)
    case click
    case rightClick
    case commandClick
}

enum InputDispatch {
    private static let eventSource: CGEventSource? = CGEventSource(stateID: .privateState)

    private static var physicalModifiers: CGEventFlags {
        let flags = CGEventSource.flagsState(.hidSystemState)
        return flags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand])
    }

    static func perform(_ action: GestureAction, usePhysicalModifiers: Bool = true) {
        let mods: CGEventFlags = usePhysicalModifiers ? physicalModifiers : []
        switch action {
        case .pressKey(let keyCode):
            postKey(keyCode: keyCode, flags: mods)
        case .pressModifiedKey(let keyCode, let shift, let control, let option, let command):
            var flags: CGEventFlags = mods
            if shift { flags.insert(.maskShift) }
            if control { flags.insert(.maskControl) }
            if option { flags.insert(.maskAlternate) }
            if command { flags.insert(.maskCommand) }
            postKey(keyCode: keyCode, flags: flags)
        case .click:
            postClick(button: .left, modifiers: mods)
        case .rightClick:
            postClick(button: .right, modifiers: mods)
        case .commandClick:
            postClick(button: .left, modifiers: mods.union(.maskCommand))
        }
    }

    private static func postKey(keyCode: UInt16, flags: CGEventFlags) {
        DispatchQueue.main.async {
            guard let down = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) else { return }
            down.flags = flags
            up.flags = flags
            down.post(tap: .cghidEventTap)
            usleep(30000)
            up.post(tap: .cghidEventTap)
        }
    }

    private static func postClick(button: CGMouseButton, modifiers: CGEventFlags) {
        DispatchQueue.main.async {
            guard let pos = CGEvent(source: nil)?.location else { return }
            let downType: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
            let upType: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp
            guard let down = CGEvent(mouseEventSource: eventSource, mouseType: downType, mouseCursorPosition: pos, mouseButton: button),
                  let up = CGEvent(mouseEventSource: eventSource, mouseType: upType, mouseCursorPosition: pos, mouseButton: button) else { return }
            down.flags = modifiers
            up.flags = modifiers
            down.post(tap: .cghidEventTap)
            usleep(50000)
            up.post(tap: .cghidEventTap)
        }
    }
}
