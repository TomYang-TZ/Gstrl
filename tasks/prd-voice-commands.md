# PRD: Voice Commands During Speech Mode

## Introduction

When speech-to-text is active in iGest, users currently can only dictate text. This feature adds voice command recognition so users can say "press down" to fire a down arrow key event instead of typing the literal words. This solves the directional navigation problem that gesture-based pointing couldn't reliably handle — users can now navigate, edit, and execute shortcuts entirely by voice while in speech mode.

## Goals

- Intercept spoken command keywords and dispatch them as CGEvent key presses
- Use "press" or "command" prefix to disambiguate commands from dictation (no prefix-free shortcuts)
- Show disambiguation UI in the Dynamic Island when recognition is uncertain
- Maintain zero delay for normal dictation (only trigger buffering on recognized prefix words)
- Exit speech mode remains gesture-based (unchanged)

## User Stories

### US-001: Create VoiceCommandParser with command lookup table
**Description:** As a developer, I need a module that determines whether new speech text contains a command or is plain dictation.

**Acceptance Criteria:**
- [ ] New file `Sources/iGest/Speech/VoiceCommandParser.swift`
- [ ] Enum `VoiceCommandResult` with cases `.command(GestureAction, wordCount: Int)` and `.text`
- [ ] Recognizes "press" + keyword: up, down, left, right, delete, enter, tab, escape
- [ ] Recognizes "command" + key: tab, z, c, v, a (maps to Cmd+key)
- [ ] All matching is case-insensitive
- [ ] Parser checks the END of the new text portion (not full cumulative transcript)
- [ ] `swift build` succeeds

### US-002: Integrate VoiceCommandParser into SpeechController
**Description:** As a user, when I say "press down" during speech mode, the down arrow key fires instead of typing "press down".

**Acceptance Criteria:**
- [ ] `SpeechController.onResult` passes new text through `VoiceCommandParser` before typing
- [ ] If command detected: call `InputDispatch.perform()` with the mapped action
- [ ] If command detected: do NOT type the command words
- [ ] If no command: type text as before (existing behavior preserved)
- [ ] `lastTypedLength` tracking correctly accounts for consumed command words
- [ ] `swift build` succeeds

### US-003: Handle partial recognition with disambiguation UI
**Description:** As a user, when I say "press" and the system isn't yet sure if a command follows, I see feedback in the Dynamic Island rather than the word being typed prematurely.

**Acceptance Criteria:**
- [ ] When "press" or "command" is detected at the end of new text, hold it in a buffer
- [ ] Dynamic Island shows a disambiguation indicator (e.g. "⌨️ press ...?") while buffered
- [ ] If the next partial result completes a valid command within 0.5s, dispatch the action
- [ ] If the next partial result does NOT complete a command within 0.5s, type the buffered word(s) as literal text
- [ ] No visible delay for normal dictation that doesn't contain prefix words
- [ ] `swift build` succeeds

### US-004: Visual command feedback in Dynamic Island
**Description:** As a user, I want brief visual confirmation when a voice command is recognized and executed.

**Acceptance Criteria:**
- [ ] When a voice command fires, gesture label briefly shows the command (e.g. "⌨️ ↓ Down Arrow") for 0.5s
- [ ] Returns to "🎤 Listening..." after the flash
- [ ] Normal dictation text display is unchanged
- [ ] `swift build` succeeds

## Functional Requirements

- FR-1: `VoiceCommandParser.parse(newText:)` returns either a command action or signals plain text
- FR-2: "press" prefix maps: up→↑, down→↓, left→←, right→→, delete→⌫, enter→⏎, tab→⇥, escape→⎋
- FR-3: "command" prefix maps: tab→Cmd+Tab, z→Cmd+Z, c→Cmd+C, v→Cmd+V, a→Cmd+A
- FR-4: All prefix words ("press", "command") must precede the keyword — standalone keywords type literally
- FR-5: When a prefix word is detected at end of input, buffer for up to 0.5s before falling back to typing
- FR-6: Dynamic Island shows disambiguation state during buffering and brief feedback on command dispatch
- FR-7: Commands use existing `InputDispatch.perform()` with appropriate `GestureAction` cases

## Non-Goals

- No prefix-free shortcut words (no "undo" without "press" — keeps false positives at zero)
- No repeated command words ("press down down down") in this iteration
- No user-configurable command mappings
- No voice-based exit from speech mode ("stop listening" not supported)
- No support for held/long-press key simulation

## Technical Considerations

- `SFSpeechRecognizer` delivers cumulative partial results — parser must only inspect the delta (new text since last processed)
- The 0.5s buffer timeout must use a `DispatchWorkItem` that can be cancelled when a new partial arrives
- Key codes from `Carbon.HIToolbox`: kVK_DownArrow (125), kVK_UpArrow (126), kVK_LeftArrow (123), kVK_RightArrow (124), kVK_Delete (51), kVK_Return (36), kVK_Tab (48), kVK_Escape (53)
- `InputDispatch` already handles `.pressKey` and `.pressModifiedKey` — no changes needed there
- Thread safety: `SpeechEngine.onResult` fires on a background thread, buffer timer must be on main thread

## Success Metrics

- Commands dispatch with < 100ms latency after final word recognized
- Normal dictation has zero added latency (no false buffering)
- No false positive command triggers during normal speech
- `swift build` passes after all stories complete

## Open Questions

- Should repeated rapid commands (saying "press down" 3 times quickly) each fire independently? (Deferred to future iteration)
- Should there be an audio/haptic feedback on command dispatch in addition to visual?
