# iGest 🤌

> Talk to your AI agent with your hands.

Control your computer using hand gestures through your webcam. No special hardware — just your hands.

## Gestures

### Left Hand (action hand)

| Gesture | Action |
|---------|--------|
| 👌 Pinch (thumb + index) | Click |
| 👌👌 Two-finger pinch (thumb + index + middle) | Right click |
| ☝️ Hold 1–3 fingers | Type 1, 2, or 3 |
| ✊ Hold fist | Enter |
| 🤙 Hold thumb + pinky | Escape |

### Right Hand (navigation hand)

| Gesture | Action |
|---------|--------|
| 👌 Pinch + move | Move cursor |
| ✌️ Two-finger point + hold | Arrow keys (accelerating repeat) |
| 👆 Swipe ↑↓←→ | Arrow key (single press) |
| 🤙 Hold thumb + pinky | Delete (chars → words → lines → all) |

### Both Hands (combos)

| Gesture | Action |
|---------|--------|
| L pinch + R pinch + move | Drag and drop |
| L pinch + R fist + move | Scroll up/down |
| Both hands open | Speech-to-text |
| L open + R swipe ←→ | Tab / Shift+Tab |
| Both 🤙 | Delete lines (escalates to select all) |
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
