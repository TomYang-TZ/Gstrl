import Foundation
import AppKit
import Carbon.HIToolbox
import IOKit.hid

enum GestureAction {
    case pressKey(UInt16)
    case pressModifiedKey(UInt16, shift: Bool, control: Bool, option: Bool, command: Bool)
    case click
    case doubleClick
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
        case .doubleClick:
            postDoubleClick(modifiers: mods)
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
            up.flags = []
            down.post(tap: .cghidEventTap)
            usleep(30000)
            up.post(tap: .cghidEventTap)
        }
    }

    private static func postDoubleClick(modifiers: CGEventFlags) {
        DispatchQueue.main.async {
            guard let pos = CGEvent(source: nil)?.location else { return }
            guard let down1 = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left),
                  let up1 = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left),
                  let down2 = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left),
                  let up2 = CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left) else { return }
            down1.setIntegerValueField(.mouseEventClickState, value: 1)
            up1.setIntegerValueField(.mouseEventClickState, value: 1)
            down2.setIntegerValueField(.mouseEventClickState, value: 2)
            up2.setIntegerValueField(.mouseEventClickState, value: 2)
            down1.flags = modifiers
            up1.flags = []
            down2.flags = modifiers
            up2.flags = []
            down1.post(tap: .cghidEventTap)
            usleep(30000)
            up1.post(tap: .cghidEventTap)
            usleep(30000)
            down2.post(tap: .cghidEventTap)
            usleep(30000)
            up2.post(tap: .cghidEventTap)
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
            up.flags = []
            down.post(tap: .cghidEventTap)
            usleep(50000)
            up.post(tap: .cghidEventTap)
        }
    }

    static func performMediaKey(_ keyCode: UInt16) {
        DispatchQueue.main.async {
            func postMediaEvent(_ keyCode: UInt16, keyDown: Bool) {
                let flags: UInt32 = keyDown ? 0xa00 : 0xb00
                let data = (UInt32(keyCode) << 16) | UInt32(flags)
                let event = NSEvent.otherEvent(
                    with: .systemDefined,
                    location: .zero,
                    modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
                    timestamp: 0,
                    windowNumber: 0,
                    context: nil,
                    subtype: 8,
                    data1: Int(data),
                    data2: -1
                )
                event?.cgEvent?.post(tap: .cghidEventTap)
            }
            postMediaEvent(keyCode, keyDown: true)
            usleep(50000)
            postMediaEvent(keyCode, keyDown: false)
        }
    }
}
