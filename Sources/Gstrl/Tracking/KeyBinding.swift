import Foundation
import SwiftUI
import Carbon.HIToolbox

struct KeyBinding: Codable, Equatable {
    let keyCode: UInt16
    let shift: Bool
    let control: Bool
    let option: Bool
    let command: Bool
    let isMediaKey: Bool
    let displayName: String

    static let none = KeyBinding(keyCode: 0, shift: false, control: false, option: false, command: false, isMediaKey: false, displayName: "None")

    var hasModifiers: Bool {
        shift || control || option || command
    }
}

enum GestureSlot: String, CaseIterable, Codable, Identifiable {
    case leftFist
    case leftThumbPinky
    case leftOpenPalm
    case leftOneFinger
    case leftTwoFingers
    case leftThreeFingers
    case swipeLeft
    case swipeRight
    case swipeUp
    case swipeDown
    case swipeLeftWithLeftOpen
    case swipeRightWithLeftOpen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leftFist: return "✊ L Fist (hold)"
        case .leftThumbPinky: return "🤙 L Six (hold)"
        case .leftOpenPalm: return "🖐 L Open palm (hold)"
        case .leftOneFinger: return "☝️ L 1 finger (hold)"
        case .leftTwoFingers: return "✌️ L 2 fingers (hold)"
        case .leftThreeFingers: return "👌 L 3 fingers (hold)"
        case .swipeLeft: return "🖐 R Swipe ←"
        case .swipeRight: return "🖐 R Swipe →"
        case .swipeUp: return "🖐 R Swipe ↑"
        case .swipeDown: return "🖐 R Swipe ↓"
        case .swipeLeftWithLeftOpen: return "🖐+← L Open + R Swipe"
        case .swipeRightWithLeftOpen: return "🖐+→ L Open + R Swipe"
        }
    }

    var section: SlotSection {
        switch self {
        case .leftFist, .leftThumbPinky, .leftOpenPalm,
             .leftOneFinger, .leftTwoFingers, .leftThreeFingers:
            return .leftHold
        case .swipeLeft, .swipeRight, .swipeUp, .swipeDown:
            return .swipe
        case .swipeLeftWithLeftOpen, .swipeRightWithLeftOpen:
            return .swipeCombo
        }
    }

    enum SlotSection: String, CaseIterable {
        case leftHold = "LEFT HAND (hold)"
        case swipe = "RIGHT HAND (swipe)"
        case swipeCombo = "RIGHT SWIPE + LEFT OPEN"

        var color: Color {
            switch self {
            case .leftHold: return .orange
            case .swipe: return .blue
            case .swipeCombo: return .purple
            }
        }
    }

    var defaultBinding: KeyBinding {
        switch self {
        case .leftFist:
            return KeyBinding(keyCode: UInt16(kVK_Return), shift: false, control: false, option: false, command: false, isMediaKey: false, displayName: "Enter")
        case .leftThumbPinky:
            return KeyBinding(keyCode: UInt16(kVK_Escape), shift: false, control: false, option: false, command: false, isMediaKey: false, displayName: "Esc")
        case .leftOpenPalm:
            return KeyBinding(keyCode: UInt16(kVK_Space), shift: false, control: false, option: false, command: false, isMediaKey: false, displayName: "Space")
        case .leftOneFinger:
            return KeyBinding(keyCode: UInt16(kVK_ANSI_1), shift: false, control: false, option: false, command: false, isMediaKey: false, displayName: "1")
        case .leftTwoFingers:
            return KeyBinding(keyCode: UInt16(kVK_ANSI_2), shift: false, control: false, option: false, command: false, isMediaKey: false, displayName: "2")
        case .leftThreeFingers:
            return KeyBinding(keyCode: UInt16(kVK_ANSI_3), shift: false, control: false, option: false, command: false, isMediaKey: false, displayName: "3")
        case .swipeLeft:
            return KeyBinding(keyCode: UInt16(kVK_LeftArrow), shift: false, control: false, option: false, command: false, isMediaKey: false, displayName: "←")
        case .swipeRight:
            return KeyBinding(keyCode: UInt16(kVK_RightArrow), shift: false, control: false, option: false, command: false, isMediaKey: false, displayName: "→")
        case .swipeUp:
            return KeyBinding(keyCode: UInt16(kVK_UpArrow), shift: false, control: false, option: false, command: false, isMediaKey: false, displayName: "↑")
        case .swipeDown:
            return KeyBinding(keyCode: UInt16(kVK_DownArrow), shift: false, control: false, option: false, command: false, isMediaKey: false, displayName: "↓")
        case .swipeLeftWithLeftOpen:
            return KeyBinding(keyCode: UInt16(kVK_Tab), shift: true, control: false, option: false, command: false, isMediaKey: false, displayName: "⇧Tab")
        case .swipeRightWithLeftOpen:
            return KeyBinding(keyCode: UInt16(kVK_Tab), shift: false, control: false, option: false, command: false, isMediaKey: false, displayName: "Tab")
        }
    }
}
