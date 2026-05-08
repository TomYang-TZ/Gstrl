# iGest 🤌

> Talk to your AI agent with your hands.

Control your computer using hand gestures through your webcam. No special hardware — just your hands.

## Gestures

```
✋ LEFT HAND                         🤚 RIGHT HAND
───────────────                      ───────────────
👌 Pinch        → Click              👌 Pinch+move  → Move cursor
☝️ 1-3 fingers  → Type 1/2/3         🤙 Thumb+pinky → Delete
✊ Fist          → Enter                 (hold: chars → words → lines → select all)
🤙 Thumb+pinky  → Escape             👆 Swipe ↑↓←→  → Arrow keys

🙌 BOTH HANDS
───────────────
🖐🖐 Both open    → Speech-to-text
🖐+👆 Open+swipe  → Tab / Shift+Tab
🤙🤙 Both 🤙      → Delete by line (escalates to select all)
✕  Fingers cross → Ctrl+C (cancel)
```

All hold gestures need 1 second to activate. Delete accelerates the longer you hold — the UI warns you before each escalation.

## Dynamic Island

A floating notch at the top of your screen shows what iGest is doing in real time:
- Which hands are detected (orange = left, blue = right)
- Current gesture and countdown progress
- Escalation warnings before destructive actions

Always visible, never steals focus.

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
