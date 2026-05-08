# iGest 🤌

> Talk to your AI agent with your hands.

iGest turns your webcam into a gesture interface for controlling AI agents. Pinch to click, swipe to navigate, hold to confirm, wave to dictate — no keyboard or mouse needed. Just your hands and a webcam.

Built with Apple Vision's real-time hand pose detection. No special hardware required.

## Gestures

```
LEFT HAND 🖐                          RIGHT HAND 🖐
─────────────────────────────         ─────────────────────────────
👌 Pinch         → Click              👌 Pinch+move   → Drag cursor
☝️ 1-3 fingers   → Number 1-3         🤙 Thumb+pinky  → Delete ⌫
✊ Fist           → Enter ⏎               (accelerates: char→word→line→all)
🤙 Thumb+pinky   → Escape ⎋           👆 Swipe ↑↓     → Arrow Up/Down
                                      👆 Swipe ←→     → Arrow Left/Right

BOTH HANDS 🖐🖐
─────────────────────────────
🖐+👆 Left open + Right swipe ←→  → Tab / Shift+Tab
🖐🖐  Both open (hold 1s)          → Speech-to-text 🎤
     Change gesture                → Stop speech
```

> **Hold gestures** require 1s to activate (progress bar fills up).
> Single-hand holds are disabled when both hands are visible.

## Dynamic Island

A floating notch-style overlay at the top of your screen shows:
- Hand detection status (orange dot = left, blue dot = right)
- Active gesture label with progress bar
- Cooldown indicator after swipe actions

## Setup

```bash
./restart.sh
```

Or manually:
1. `xcodebuild -project iGest.xcodeproj -scheme iGest -configuration Release build`
2. Copy and codesign the app
3. Grant **Camera**, **Microphone**, **Speech Recognition**, and **Accessibility** permissions
4. Click **Enable** in the app window

## Requirements

- macOS 14+ (Sonoma or later)
- Built-in or external webcam
- Apple Silicon or Intel Mac

## Tech Stack

- Swift / AppKit / SwiftUI
- Apple Vision framework (VNDetectHumanHandPoseRequest)
- Speech framework (SFSpeechRecognizer)
- CGEvent for input simulation
- Velocity-based swipe detection with return-to-origin filtering

