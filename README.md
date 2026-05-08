# iGest 🤌

> Control your Mac with hand gestures — no keyboard, no mouse, just your webcam.

**iGest** is a hands-free Mac cursor and gesture control app that turns your webcam into an input device. Point, pinch, swipe, and speak to navigate your computer using real-time hand tracking powered by Apple's Vision framework.

Use it to control your Mac with hand gestures, move the cursor hands-free, click and scroll without touching anything, or dictate text with speech-to-text — all through webcam gesture recognition on macOS. No special hardware required.

**Use cases:** accessibility, RSI relief, presentations, standing-desk workflows, or just keeping your hands off a dirty keyboard.

## Gestures

### Left Hand (action hand)

| Gesture | Action |
|---------|--------|
| 👌 Pinch (thumb + index) | Click |
| 👌👌 Two-finger pinch (thumb + index + middle) | Right click |
| ☝️ Hold 1–3 fingers | Type 1, 2, or 3 |
| ✊ Hold fist | Enter |
| 🤙 Six (hold) | Escape |

### Right Hand (navigation hand)

| Gesture | Action |
|---------|--------|
| 👌 Pinch + move | Move cursor |
| 👆 Swipe ↑↓←→ | Arrow keys |
| 🤙 Six (hold) | Delete (chars → words → lines → all) |

### Both Hands (combos)

| Gesture | Action |
|---------|--------|
| L pinch + R pinch + move | Drag and drop |
| L pinch + R fist + move | Scroll up/down |
| Both fists | Speech-to-text |
| L open + R swipe ←→ | Tab / Shift+Tab |
| Both 🤙 six | Delete lines (escalates to select all) |
| ✕ Cross index fingers | Ctrl+C ×2 (cancel/kill) |


## Dynamic Island

A floating notch at the top of your screen shows what iGest is doing in real time:
- Which hands are detected (orange = left, blue = right)
- Current gesture and countdown progress
- Escalation warnings before destructive actions

Always visible, never steals focus.

## Install

```bash
git clone https://github.com/TomYang-TZ/iGest.git
cd iGest
make install   # builds and copies to /Applications
```

Then launch from Applications, or:

```bash
make run       # build + launch
make restart   # stop + build + launch
make stop      # kill running instance
```

Grant Camera, Microphone, Accessibility, and Speech Recognition permissions when prompted.

## Requirements

- macOS 14+
- Webcam
- Swift 5.9+

## How It Works

iGest uses Apple's Vision framework (`VNDetectHumanHandPoseRequest`) to detect hand landmarks at 30fps from your webcam feed. A gesture classifier maps hand poses to actions — pinch detection, finger counting, velocity-based swipe recognition, and two-hand combo tracking. All processing runs locally on-device with zero network dependency.

## License

MIT
