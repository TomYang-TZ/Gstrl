# iGest

Control your Mac with hand gestures. No mouse needed.

iGest uses your webcam to detect hand poses via Apple Vision and translates them into mouse clicks, cursor movement, keyboard input, and speech-to-text — enabling fully hands-free computer interaction.

## How It Works

| Gesture | Action |
|---------|--------|
| **Left hand pinch** (thumb + index) | Click |
| **Right hand pinch + move** | Drag cursor (relative movement) |
| **Left hand 1-3 fingers** (hold 1s) | Press number key 1-3 |
| **Left hand fist** (hold 1s) | Press Enter |
| **Left hand 🤙** thumb + pinky (hold 1s) | Press Escape |
| **Both hands fist** (hold 1s) | Start speech-to-text (types as you speak) |
| **Drop both hands** | Stop speech-to-text |

## Setup

1. Build with Xcode (`xcodebuild -scheme iGest -configuration Release build`)
2. Grant **Camera**, **Microphone**, **Speech Recognition**, and **Accessibility** permissions
3. Click **Enable** in the app window
4. Use gestures to control your Mac

Works great alongside macOS **Head Pointer** (Accessibility → Pointer Control) for cursor movement via head tracking + iGest for clicking.

## Requirements

- macOS 14+
- Built-in or external webcam
- Apple Silicon or Intel Mac

## Tech Stack

- Swift / AppKit
- Apple Vision framework (VNDetectHumanHandPoseRequest)
- Speech framework (SFSpeechRecognizer)
- CGEvent for input simulation
