import Foundation
import Carbon.HIToolbox

enum VoiceCommandResult {
    case command(GestureAction, wordCount: Int)
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

    private static let prefixes: Set<String> = ["press", "command"]

    static func parse(newText: String) -> VoiceCommandResult {
        let words = newText.split(separator: " ", omittingEmptySubsequences: true)
        guard !words.isEmpty else { return .text }

        // Check for complete command (prefix + keyword)
        if words.count >= 2 {
            let prefix = words[words.count - 2].lowercased()
            let keyword = words[words.count - 1].lowercased()

            if prefix == "press", let keyCode = pressCommands[keyword] {
                return .command(.pressKey(keyCode), wordCount: 2)
            }

            if prefix == "command", let keyCode = commandKeys[keyword] {
                return .command(.pressModifiedKey(keyCode, shift: false, control: false, option: false, command: true), wordCount: 2)
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
