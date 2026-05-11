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
        "delete": UInt16(kVK_Delete),
        "click": 0xFF,
    ]

    private static let letterKeyCodes: [String: UInt16] = [
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
        "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45,
        "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32,
        "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
    ]

    private static let letterAliases: [String: String] = [
        "and": "n", "end": "n", "in": "n",
        "are": "r", "our": "r",
        "be": "b", "bee": "b",
        "see": "c", "sea": "c",
        "tea": "t", "tee": "t",
        "you": "u",
        "why": "y",
        "hey": "a", "ay": "a",
        "oh": "o", "owe": "o",
        "eye": "i",
        "jay": "j",
        "kay": "k", "ok": "k",
        "el": "l",
        "em": "m",
        "ex": "x",
        "cue": "q", "queue": "q",
        "we": "w", "wee": "w",
        "dee": "d",
        "gee": "g",
        "pee": "p",
        "fee": "f",
        "es": "s",
        "vee": "v",
        "zed": "z", "zee": "z",
    ]

    private static func normalizeKeyword(_ word: String) -> String {
        letterAliases[word] ?? word
    }

    private static func commandKeyCode(_ keyword: String) -> UInt16? {
        let normalized = normalizeKeyword(keyword)
        if let code = commandKeys[normalized] { return code }
        if let code = letterKeyCodes[normalized] { return code }
        if let code = pressCommands[normalized] { return code }
        return nil
    }

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

    private static let shiftAliases: Set<String> = ["shift", "shipped", "chef", "shaft", "swift"]
    private static let optionAliases: Set<String> = ["option", "optional", "alt", "opt"]

    private static func isModifier(_ word: String) -> Bool {
        shiftAliases.contains(word) || optionAliases.contains(word)
    }

    private static func normalizeModifier(_ word: String) -> String? {
        if shiftAliases.contains(word) { return "shift" }
        if optionAliases.contains(word) { return "option" }
        return nil
    }

    private static let pressAliases: Set<String> = ["press", "pres", "prex", "breast", "rest"]
    private static let commandAliases: Set<String> = ["command", "commander", "commend", "commence", "comet", "comment", "come in", "come on", "common", "comma"]
    private static let controlAliases: Set<String> = ["control", "controls", "controlled", "ctrl"]

    private static func normalizePrefix(_ word: String) -> String? {
        let w = word.lowercased()
        if pressAliases.contains(w) { return "press" }
        if commandAliases.contains(w) { return "command" }
        if controlAliases.contains(w) { return "control" }
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

        // Check for 3-word modifier combos (e.g. "command shift z", "shift option left", "option shift right")
        if words.count >= 3 {
            let w1 = words[words.count - 3].lowercased()
            let w2 = words[words.count - 2].lowercased()
            let keyword = words[words.count - 1].lowercased()

            let isW1Command = normalizePrefix(w1) == "command"
            let isW1Modifier = isModifier(w1)
            let isW2Modifier = isModifier(w2)

            if (isW1Command || isW1Modifier) && isW2Modifier {
                let normalizedKey = normalizeKeyword(keyword)
                let keyCode = pressCommands[normalizedKey] ?? commandKeyCode(keyword)
                if let keyCode, keyCode != 0xFF {
                    let command = isW1Command
                    let mod1 = isW1Modifier ? normalizeModifier(w1) : nil
                    let mod2 = normalizeModifier(w2)
                    let shift = mod1 == "shift" || mod2 == "shift"
                    let option = mod1 == "option" || mod2 == "option"
                    let name = "\(command ? "⌘" : "")\(shift ? "⇧" : "")\(option ? "⌥" : "")\(normalizedKey)"
                    return .command(.pressModifiedKey(keyCode, shift: shift, control: false, option: option, command: command), wordCount: 3, displayName: name)
                }
            }
        }

        // Check for standalone modifier + key (e.g. "option left", "shift down")
        if words.count >= 2 {
            let modWord = words[words.count - 2].lowercased()
            let keyword = words[words.count - 1].lowercased()

            if isModifier(modWord) {
                let normalizedKey = normalizeKeyword(keyword)
                let keyCode = pressCommands[normalizedKey] ?? commandKeyCode(keyword)
                if let keyCode, keyCode != 0xFF {
                    let mod = normalizeModifier(modWord)
                    let shift = mod == "shift"
                    let option = mod == "option"
                    let name = "\(shift ? "⇧" : "")\(option ? "⌥" : "")\(normalizedKey)"
                    return .command(.pressModifiedKey(keyCode, shift: shift, control: false, option: option, command: false), wordCount: 2, displayName: name)
                }
            }
        }

        // Check for complete command (prefix + keyword)
        if words.count >= 2 {
            let rawPrefix = words[words.count - 2].lowercased()
            let keyword = words[words.count - 1].lowercased()

            if let normalized = normalizePrefix(rawPrefix) {
                if normalized == "press" && keyword == "click" {
                    return .command(.click, wordCount: 2, displayName: "👆 Click")
                }
                if normalized == "press", let keyCode = pressCommands[keyword] {
                    let name = pressDisplayNames[keyword] ?? keyword
                    return .command(.pressKey(keyCode), wordCount: 2, displayName: name)
                }
                if normalized == "command", let keyCode = commandKeyCode(keyword) {
                    let normalizedKey = normalizeKeyword(keyword)
                    let name = commandDisplayNames[normalizedKey] ?? "⌘\(normalizedKey)"
                    if normalizedKey == "click" {
                        return .command(.commandClick, wordCount: 2, displayName: name)
                    }
                    return .command(.pressModifiedKey(keyCode, shift: false, control: false, option: false, command: true), wordCount: 2, displayName: name)
                }
                if normalized == "control", let keyCode = commandKeyCode(keyword) {
                    let normalizedKey = normalizeKeyword(keyword)
                    let name = "⌃\(normalizedKey)"
                    return .command(.pressModifiedKey(keyCode, shift: false, control: true, option: false, command: false), wordCount: 2, displayName: name)
                }
            }
        }

        // Check for partial: "command shift" / "control shift" / "shift option" / "option" etc waiting for keyword
        if words.count >= 2 {
            let secondLast = words[words.count - 2].lowercased()
            let last = words[words.count - 1].lowercased()
            let norm = normalizePrefix(secondLast)
            let isSecondLastPrefix = norm == "command" || norm == "control" || isModifier(secondLast)
            if isSecondLastPrefix && isModifier(last) {
                return .partial(prefix: "\(secondLast) \(last)", wordCount: 2)
            }
        }

        let lastW = words[words.count - 1].lowercased()
        if isModifier(lastW) {
            return .partial(prefix: lastW, wordCount: 1)
        }

        // Check for partial prefix at end (just "press" or "command" with no keyword yet)
        let lastWord = words[words.count - 1].lowercased()
        if normalizePrefix(lastWord) != nil {
            return .partial(prefix: lastWord, wordCount: 1)
        }

        // "click" / "right click" / "double click" works without prefix
        if words.count == 2 {
            let first = words[0].lowercased()
            if first == "right" && lastWord == "click" {
                return .command(.rightClick, wordCount: 2, displayName: "👆 Right Click")
            }
            if first == "double" && lastWord == "click" {
                return .command(.doubleClick, wordCount: 2, displayName: "👆👆 Double Click")
            }
        }
        if lastWord == "click" {
            return .command(.click, wordCount: 1, displayName: "👆 Click")
        }

        return .text
    }

}
