# iGest Handoff

## Current State (2025-05-07)

Working macOS app that detects hand gestures via webcam and translates them to mouse/keyboard input.

## Working Features

| Gesture | Action | Status |
|---------|--------|--------|
| Left pinch | Click | ✅ Working |
| Right pinch + move | Drag cursor (relative) | ✅ Working |
| Left 1-3 fingers (hold 1s) | Press number 1-3 | ✅ Working |
| Left fist (hold 1s) | Enter | ✅ Working |
| Left 🤙 thumb+pinky (hold 1s) | Escape | ✅ Working |
| Both fists (hold 1s) | Speech-to-text | ✅ Working |
| Left 4+ fingers | Idle (no action) | ✅ Working |

## Next Up: Right Hand Swipe Navigation

Detect quick directional swipes of the right hand index finger:
- **Swipe up** = Up arrow (or scroll/Page Up)
- **Swipe down** = Down arrow (or scroll/Page Down)
- **Swipe left** = Shift+Tab
- **Swipe right** = Tab

Also open-hand vertical swipe for Page Up/Down.

**Implementation approach:** Track right hand index tip position over last 0.3s. If displacement exceeds threshold in one dominant direction, fire the key. Cooldown of 0.5s between swipes.

## Build & Run

```bash
cd /Users/tomyang/iGest
xcodegen generate
rm -rf iGest.app
xcodebuild -project iGest.xcodeproj -scheme iGest -configuration Release build
cp -R ~/Library/Developer/Xcode/DerivedData/iGest-*/Build/Products/Release/iGest.app ./iGest.app
codesign --force --sign - iGest.app
open iGest.app
```

Then add `/Users/tomyang/iGest/iGest.app` to **System Settings → Privacy & Security → Accessibility**.

## Architecture

```
Sources/iGest/
├── iGestApp.swift           # AppDelegate, menu bar, main window
├── AppState.swift           # @Observable shared state
├── MainStatusView.swift     # SwiftUI status window
├── Camera/CameraManager.swift    # AVCaptureSession 30fps
├── Cursor/CursorController.swift # CGEvent mouse posting
├── Tracking/
│   ├── TrackingCoordinator.swift # Main logic — gesture detection + actions
│   ├── HandTracker.swift         # Pinch/finger classification (debounced)
│   └── TrackingState.swift       # Enum: inactive/tracking/pinching
└── Speech/SpeechEngine.swift     # SFSpeechRecognizer real-time typing
```

## Key Gotchas

- **Accessibility permission resets on rebuild** — always codesign adhoc and add the SAME path to Accessibility
- **Info.plist must have NSMicrophoneUsageDescription** or app crashes instantly when requesting mic
- **CGEvent needs Accessibility** — clicks silently fail without it
- **Don't use CGWarpMouseCursorPosition with stale data** — causes cursor to jump
- **Escape key kills iGest if window focused** — by design (local monitor only)
- **Both fists conflicts with single fist Enter** — `bothFists` check runs first and takes priority
- **Hand chirality** — Apple Vision `.left`/`.right` is from subject's perspective; fallback uses wrist.x position

## Repo

https://github.com/TomYang-TZ/iGest (private)
