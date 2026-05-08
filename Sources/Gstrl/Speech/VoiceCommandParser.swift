import Foundation
import Carbon.HIToolbox

enum VoiceCommandResult {
    case command(GestureAction, wordCount: Int, displayName: String)
    case partial(prefix: String, wordCount: Int)
    case text
}

enum VoiceCommandParser {
    private static let pressCommands: [String: UInt16] = [
        "up": UInt16(kVK_UpArrow),
        "down": UInt16(kVK_DownArrow),
        "left": UInt16(kVK_LeftArrow),
        "right": UInt16(kVK_RightArrow),
        "delete": UInt16(kVK_Delete),
        "enter": UInt16(kVK_Return),
        "tab": UInt16(kVK_Tab),
        "escape": UInt16(kVK_Escape),
        "1": UInt16(kVK_ANSI_1), "one": UInt16(kVK_ANSI_1),
        "2": UInt16(kVK_ANSI_2), "two": UInt16(kVK_ANSI_2),
        "3": UInt16(kVK_ANSI_3), "three": UInt16(kVK_ANSI_3),
        "4": UInt16(kVK_ANSI_4), "four": UInt16(kVK_ANSI_4),
        "5": UInt16(kVK_ANSI_5), "five": UInt16(kVK_ANSI_5),
        "6": UInt16(kVK_ANSI_6), "six": UInt16(kVK_ANSI_6),
        "7": UInt16(kVK_ANSI_7), "seven": UInt16(kVK_ANSI_7),
        "8": UInt16(kVK_ANSI_8), "eight": UInt16(kVK_ANSI_8),
        "9": UInt16(kVK_ANSI_9), "nine": UInt16(kVK_ANSI_9),
        "0": UInt16(kVK_ANSI_0), "zero": UInt16(kVK_ANSI_0),
    ]

    private static let commandKeys: [String: UInt16] = [
        "tab": UInt16(kVK_Tab),
        "z": 6,
        "c": 8,
        "v": 9,
        "a": 0,
        "delete": UInt16(kVK_Delete),
        "click": 0xFF,
    ]

    private static let pressDisplayNames: [String: String] = [
        "up": "↑ Up Arrow",
        "down": "↓ Down Arrow",
        "left": "← Left Arrow",
        "right": "→ Right Arrow",
        "delete": "⌫ Delete",
        "enter": "↵ Enter",
        "tab": "⇥ Tab",
        "escape": "⎋ Escape",
        "1": "1", "one": "1",
        "2": "2", "two": "2",
        "3": "3", "three": "3",
        "4": "4", "four": "4",
        "5": "5", "five": "5",
        "6": "6", "six": "6",
        "7": "7", "seven": "7",
        "8": "8", "eight": "8",
        "9": "9", "nine": "9",
        "0": "0", "zero": "0",
    ]

    private static let commandDisplayNames: [String: String] = [
        "tab": "⌘⇥ Cmd+Tab",
        "z": "⌘Z Undo",
        "c": "⌘C Copy",
        "v": "⌘V Paste",
        "a": "⌘A Select All",
        "delete": "⌘⌫ Cmd+Delete",
        "click": "⌘ Cmd+Click",
    ]

    private static let pressAliases: Set<String> = ["press", "pres", "prex"]
    private static let commandAliases: Set<String> = ["command", "commend", "commence", "come and", "comet"]

    private static func normalizePrefix(_ word: String) -> String? {
        let w = word.lowercased()
        if pressAliases.contains(w) { return "press" }
        if commandAliases.contains(w) { return "command" }
        return nil
    }

    static func displayName(prefix: String, keyword: String) -> String? {
        let p = normalizePrefix(prefix) ?? prefix.lowercased()
        let k = keyword.lowercased()
        if p == "press" {
            return pressDisplayNames[k]
        } else if p == "command" {
            return commandDisplayNames[k]
        }
        return nil
    }

    static func parse(newText: String) -> VoiceCommandResult {
        let words = newText.split(separator: " ", omittingEmptySubsequences: true)
        guard !words.isEmpty else { return .text }

        // Check for complete command (prefix + keyword)
        if words.count >= 2 {
            let rawPrefix = words[words.count - 2].lowercased()
            let keyword = words[words.count - 1].lowercased()

            if let normalized = normalizePrefix(rawPrefix) {
                if normalized == "press", let keyCode = pressCommands[keyword] {
                    let name = pressDisplayNames[keyword] ?? keyword
                    return .command(.pressKey(keyCode), wordCount: 2, displayName: name)
                }
                if normalized == "command", commandKeys[keyword] != nil {
                    let name = commandDisplayNames[keyword] ?? keyword
                    if keyword == "click" {
                        return .command(.commandClick, wordCount: 2, displayName: name)
                    }
                    let keyCode = commandKeys[keyword]!
                    return .command(.pressModifiedKey(keyCode, shift: false, control: false, option: false, command: true), wordCount: 2, displayName: name)
                }
            }
        }

        // Check for partial prefix at end (just "press" or "command" with no keyword yet)
        let lastWord = words[words.count - 1].lowercased()
        if normalizePrefix(lastWord) != nil {
            return .partial(prefix: lastWord, wordCount: 1)
        }

        return .text
    }
}
