# iGest

Control your Mac with hand gestures. No mouse needed.

iGest uses your webcam to detect hand poses via Apple Vision and translates them into mouse clicks, cursor movement, keyboard input, and speech-to-text — enabling fully hands-free computer interaction.

## How It Works

### Single Hand (left or right alone)

| Gesture | Action |
|---------|--------|
| **Left pinch** (thumb + index) | Click |
| **Right pinch + move** | Drag cursor (relative) |
| **Left 1-3 fingers** (hold 1s) | Press number key 1-3 |
| **Left fist** (hold 1s) | Enter |
| **Left 🤙** thumb+pinky (hold 1s) | Escape |
| **Right 🤙** thumb+pinky (hold 1s) | Delete (accelerates: chars → words → lines → select all) |
| **Right swipe ↑↓** | Up/Down arrow |
| **Right swipe ←→** | Left/Right arrow |

### Two Hands

| Gesture | Action |
|---------|--------|
| **Left open + right swipe ←→** | Shift+Tab / Tab |
| **Both hands open** (hold 1s) | Speech-to-text |
| **Change gesture** | Stop speech |

Single-hand hold gestures (numbers, enter, escape) are disabled when both hands are detected to prevent accidental triggers.

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

- macOS 14+
- Built-in or external webcam
- Apple Silicon or Intel Mac

## Tech Stack

- Swift / AppKit / SwiftUI
- Apple Vision framework (VNDetectHumanHandPoseRequest)
- Speech framework (SFSpeechRecognizer)
- CGEvent for input simulation
- Velocity-based swipe detection with return-to-origin filtering
