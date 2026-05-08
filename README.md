# Gstrl 🤌

> Sometimes a pinch is faster than reaching for the mouse.

**Gstrl** adds gesture and voice control to macOS. **Pinch to move cursor. Swipe for arrows. Circle to screenshot. Speak to run commands.** All on-device via Apple Vision + SFSpeechRecognizer.

For when you're lying back, presenting, or just tired of reaching across your desk.

## Gestures & Voice

### Left Hand (action hand)

| Gesture | Action |
|---------|--------|
| 👌 Quick pinch (thumb + index) | Click |
| 👌 Long pinch (hold 1s) | Right click |
| ☝️ Hold 1–3 fingers | Type 1, 2, or 3 |
| ✊ Hold fist | Enter |
| 🤙 Six (hold) | Escape |

### Right Hand (navigation hand)

| Gesture | Action |
|---------|--------|
| 👌 Pinch + move | Move cursor |
| 👌 Pinch + draw circle | Screenshot circled area → clipboard |
| 🖐 Open hand + swipe ↑↓←→ | Arrow keys |
| 🤙 Six (hold) | Delete (chars → words → lines → all) |

### Both Hands (combos)

| Gesture | Action |
|---------|--------|
| L pinch + R pinch + move | Drag and drop |
| L pinch + R fist + move | Scroll (velocity-based, accelerates over time) |
| Both fists | Speech-to-text |
| L open + R swipe ←→ | Tab / Shift+Tab |
| Both 🤙 six | Delete lines (escalates to select all) |
| ✕ Both hands held together | Ctrl+C ×2 (cancel/kill) |

### Voice Commands (during speech mode)

While speech-to-text is active, say "press" + keyword to execute actions instead of typing:

| Command | Action |
|---------|--------|
| press down/up/left/right | Arrow keys |
| press enter / press tab | Enter / Tab |
| press delete / press escape | Backspace / Escape |
| command tab/z/c/v/a | Cmd+Tab / Undo / Copy / Paste / Select All |
| command click | Cmd+Click (at current cursor position) |

### "Pro" tip: Keyboard + Gesture

Hold a modifier key while gesturing — they combine. Shift + swipe = select text. Cmd + swipe = jump words. Go wild.

## Dynamic Island

A floating pill at the top of your screen with Apple Liquid Glass styling (macOS 26+):
- SF Symbol hand indicators (orange = left, cyan = right)
- Current gesture label and progress bar
- Screenshot preview thumbnail on circle capture

Always visible, never steals focus.

## Install

```bash
git clone https://github.com/TomYang-TZ/Gstrl.git
cd Gstrl
make install   # builds + installs to /Applications
```

```bash
make run       # build + launch
make restart   # stop + rebuild + launch
make stop      # kill it
```

App auto-opens permission pages on first launch (Camera, Accessibility, Screen Recording, Speech).

## Requirements

- macOS 14+ (Liquid Glass needs macOS 26+, falls back gracefully)
- Webcam
- Swift 5.9+

## How It Works

Gstrl uses Apple's Vision framework (`VNDetectHumanHandPoseRequest`) to detect hand landmarks from your webcam feed. A gesture classifier maps hand poses to actions — pinch detection via palm center tracking, displacement-based swipe recognition (requires open hand pose), and two-hand combo tracking. Scroll uses velocity-based joystick control. Speech mode uses Apple's `SFSpeechRecognizer` for on-device dictation and voice commands. 30fps default, configurable up to 120fps. All processing runs locally with zero network dependency.

## License

MIT
