# iGest 🤌

> Talk to your AI agent with your hands.

Control your computer using hand gestures through your webcam. No special hardware — just your hands.

## Gestures

### One Hand Only

Use your left or right hand alone. These won't fire if the other hand is visible (except click).

```
✋ LEFT                               🤚 RIGHT
───────────────                      ───────────────
👌 Pinch          → Click            👌 Pinch+move  → Move cursor
👌👌 Two-finger    → Right click      🤙 Thumb+pinky → Delete (escalating)
☝️ 1-3 fingers    → Type 1/2/3       👆 Swipe ↑↓←→  → Arrow keys
✊ Fist            → Enter
🤙 Thumb+pinky    → Escape
```

### Both Hands

```
👌+👌 L pinch + R pinch+move → Drag and drop
👌+✊ L pinch + R fist + move → Scroll (left hand up/down)
🖐🖐 Both open               → Speech-to-text
🖐+👆 Open + swipe           → Tab / Shift+Tab
🤙🤙 Both thumb+pinky        → Delete lines (escalates to select all)
✕  Fingers cross            → Ctrl+C ×2 (cancel/kill)
```


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
