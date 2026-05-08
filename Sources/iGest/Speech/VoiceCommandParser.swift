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
    ]

    private static let commandKeys: [String: UInt16] = [
        "tab": UInt16(kVK_Tab),
        "z": 6,
        "c": 8,
        "v": 9,
        "a": 0,
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
    ]

    private static let commandDisplayNames: [String: String] = [
        "tab": "⌘⇥ Cmd+Tab",
        "z": "⌘Z Undo",
        "c": "⌘C Copy",
        "v": "⌘V Paste",
        "a": "⌘A Select All",
    ]

    private static let prefixes: Set<String> = ["press", "command"]

    static func displayName(prefix: String, keyword: String) -> String? {
        let p = prefix.lowercased()
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
            let prefix = words[words.count - 2].lowercased()
            let keyword = words[words.count - 1].lowercased()

            if prefix == "press", let keyCode = pressCommands[keyword] {
                let name = pressDisplayNames[keyword] ?? keyword
                return .command(.pressKey(keyCode), wordCount: 2, displayName: name)
            }

            if prefix == "command", let keyCode = commandKeys[keyword] {
                let name = commandDisplayNames[keyword] ?? keyword
                return .command(.pressModifiedKey(keyCode, shift: false, control: false, option: false, command: true), wordCount: 2, displayName: name)
            }
        }

        // Check for partial prefix at end (just "press" or "command" with no keyword yet)
        let lastWord = words[words.count - 1].lowercased()
        if prefixes.contains(lastWord) {
            return .partial(prefix: lastWord, wordCount: 1)
        }

        return .text
    }
}
