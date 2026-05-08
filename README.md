# iGest — Hands-Free Mac Control via Webcam Hand Gestures

> macOS hand gesture recognition app: control your cursor, click, type, scroll, and dictate — all without touching your keyboard or mouse.

iGest turns any webcam into a gesture controller for macOS. It uses Apple Vision's real-time hand pose detection to translate pinches, swipes, finger counts, and hand poses into mouse clicks, cursor movement, keyboard shortcuts, and speech-to-text input. No special hardware required — just your built-in webcam.

**Use cases:** accessibility, RSI relief, hands-free presentations, touchless kiosk control, creative workflows, distance interaction.

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

- macOS 14+ (Sonoma or later)
- Built-in or external webcam
- Apple Silicon or Intel Mac

## Tech Stack

- Swift / AppKit / SwiftUI
- Apple Vision framework (VNDetectHumanHandPoseRequest)
- Speech framework (SFSpeechRecognizer)
- CGEvent for input simulation
- Velocity-based swipe detection with return-to-origin filtering

## Keywords

hand gesture recognition macOS, webcam hand tracking, hands-free computer control, touchless Mac input, accessibility gesture control, Apple Vision hand pose, gesture-to-keyboard, air gesture mouse control, RSI-friendly input, macOS hand gesture app
