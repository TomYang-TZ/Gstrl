# Gstrl 🤌

> Your webcam is now an input device. Yes, really.

**Gstrl** adds gesture and voice control on top of your Mac. **Pinch to move cursor. Swipe for arrows. Circle to screenshot. Speak to run commands.** All on-device via Apple Vision + SFSpeechRecognizer.

Not a mouse replacement — a mouse *supplement*. For when your hands are holding coffee, you're across the room, or you just think pinching is cool.

## Gestures & Voice

### Left Hand (action hand)

| Gesture | Action |
|---------|--------|
| 👌 Pinch | Click |
| 👌 Hold pinch 1s | Right click |
| ☝️ Hold 1–3 fingers | Type 1, 2, or 3 |
| ✊ Fist | Enter |
| 🤙 Six | Escape |

### Right Hand (navigation hand)

| Gesture | Action |
|---------|--------|
| 👌 Pinch + move | Move cursor |
| 👌 Pinch + draw circle | Screenshot area → clipboard |
| 🖐 Open hand + swipe | Arrow keys |
| 🤙 Six (hold) | Delete (escalates: chars → words → lines → all) |

### Both Hands

| Gesture | Action |
|---------|--------|
| L pinch + R pinch + move | Drag and drop |
| L pinch + R fist + move | Scroll (accelerates over time) |
| Both fists | Speech-to-text |
| L open + R swipe ←→ | Tab / Shift+Tab |
| Both 🤙 | Nuclear delete (select all + delete) |
| ✕ Cross fingers | Ctrl+C ×2 (kill it with fire) |

### Voice Commands (during speech mode)

Say "press" or "command" + keyword:

| Say this | Does this |
|----------|-----------|
| press up/down/left/right | Arrow keys |
| press enter / press tab | Enter / Tab |
| press delete / press escape | Backspace / Escape |
| command tab/z/c/v | Cmd+Tab / Undo / Copy / Paste |

## Dynamic Island

Floating glass pill at the top of your screen (Liquid Glass on macOS 26+):
- Shows which hands are detected
- Current gesture + progress bar
- Screenshot preview on circle capture

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

Vision framework hand pose detection → gesture classifier → CGEvent dispatch. Palm center tracking for cursor, displacement-based swipe detection, velocity joystick for scroll. Speech via SFSpeechRecognizer with command keyword parsing. 30fps default, configurable up to 120fps. Zero network calls.

## License

MIT
