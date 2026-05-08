# iGest 🤌

> Talk to your AI agent with your hands.

Control your computer using hand gestures through your webcam. No special hardware — just your hands.

## Gestures

```
✋ LEFT HAND                         🤚 RIGHT HAND
───────────────                      ───────────────
👌 Pinch        → Click              👌 Pinch+move  → Move cursor
☝️ 1-3 fingers  → Type 1/2/3         🤙 Thumb+pinky → Delete (accelerates)
✊ Fist          → Enter              👆 Swipe ↑↓←→  → Arrow keys
🤙 Thumb+pinky  → Escape

🙌 BOTH HANDS
───────────────
🖐🖐 Both open    → Speech-to-text
🖐+👆 Open+swipe  → Tab / Shift+Tab
🤙🤙 Both 🤙      → Delete lines (fast)
✕  Fingers cross → Ctrl+C (cancel)
```

All hold gestures need 1 second to activate. You'll see a progress bar.

## Quick Start

```bash
git clone https://github.com/TomYang-TZ/iGest.git
cd iGest
./restart.sh
```

Grant Camera, Microphone, and Accessibility permissions when prompted.

## Requirements

- macOS 14+
- Webcam
- Xcode (to build)
