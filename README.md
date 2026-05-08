# iGest 🤌

> Talk to your AI agent with your hands.

Control your computer using hand gestures through your webcam. No special hardware — just your hands.

## Gestures

### One Hand Only

Use your left or right hand alone. These won't fire if the other hand is visible (except click).

```
✋ LEFT                               🤚 RIGHT
───────────────                      ───────────────
👌 Pinch        → Click              👌 Pinch+move  → Move cursor
☝️ 1-3 fingers  → Type 1/2/3         🤙 Thumb+pinky → Delete
✊ Fist          → Enter                 (hold: chars → words → lines → select all)
🤙 Thumb+pinky  → Escape             👆 Swipe ↑↓←→  → Arrow keys
```

### Both Hands

Raise both hands. Single-hand gestures are suppressed — only these combos fire.

```
🖐🖐 Both open    → Speech-to-text
🖐+👆 Open+swipe  → Tab / Shift+Tab
🤙🤙 Both 🤙      → Delete by line (escalates to select all)
✕  Fingers cross → Ctrl+C (cancel)
```

### Delete Behavior

All hold gestures need 1 second to activate. Delete gets more aggressive the longer you hold — the UI warns you before each escalation.

**One hand 🤙** (gradual):
```
0-5s   char by char (accelerating)
5-8s   word by word
8-11s  line by line
11s+   select all + delete
```

**Both hands 🤙🤙** (aggressive):
```
0-5s   line by line
5s+    select all + delete
```

Release anytime to stop. The progress bar shows how close you are to the next level.

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
