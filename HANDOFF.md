# iGest — Engineering Handoff

## Architecture

```
Sources/iGest/
├── iGestApp.swift                 App entry, window + island + menu bar lifecycle
├── AppState.swift                 @Observable model — all UI-bound state
├── DynamicIslandView.swift        Floating notch overlay (NotchShape + SwiftUI)
├── MainStatusView.swift           Settings window with gesture reference
├── Camera/
│   └── CameraManager.swift        AVCaptureSession @ 30fps, delivers CVPixelBuffer
├── Tracking/
│   ├── TrackingCoordinator.swift  Orchestrator — frame processing + priority routing
│   ├── GestureClassifier.swift    Static: isPinching, isTwoFingerPinch, isThumbPinky, etc.
│   ├── SwipeDetector.swift        Velocity-based swipe with grace period + cooldown
│   ├── DeleteController.swift     Escalating delete state machine (chars→words→lines→all)
│   ├── ScrollController.swift     Relative scroll via wrist Y tracking
│   ├── CursorDragController.swift Right-pinch cursor drag + drag-and-drop (mouse down)
│   ├── SpeechController.swift     Countdown + SpeechEngine lifecycle
│   ├── InputDispatch.swift        GestureAction enum → CGEvent (keys, click, right-click)
│   └── TrackingState.swift        Enum: inactive | tracking | pinching
└── Speech/
    └── SpeechEngine.swift         SFSpeechRecognizer → CGEvent character typing
```

## Data Flow

```
Camera (30fps CVPixelBuffer)
  → TrackingCoordinator.processFrame()
    → VNDetectHumanHandPoseRequest (up to 2 hands)
    → Chirality separation (left/right)
    → Gesture priority chain:
        1. Fingers crossed (X)? → Ctrl+C ×2
        2. L pinch + R fist? → Scroll (left hand Y movement)
        3. Both hands 🤙? → Delete lines (escalating)
        4. Both hands open? → Speech countdown/activation
        5. Right hand pinch? → Cursor drag (+ drag-and-drop if L pinching)
        6. Right hand 🤙? → Delete chars (accelerating)
        7. Right hand open? → Velocity-based swipe detection
        8. Left two-finger pinch? → Right click
        9. Left hand pinch? → Click
       10. Left hand fingers? → Hold-to-fire (numbers/enter/escape)
    → AppState updates (main thread)
    → UI reacts (SwiftUI observation)
```

## Build & Run

```bash
make run       # build + launch
make install   # build + copy to /Applications
make restart   # stop + build + launch
make stop      # kill running instance
make clean     # remove build artifacts
```

Requires Accessibility permission — app prompts on first enable.

## Key Design Decisions

**Velocity-based swipe detection** — Displacement-based was tried first but failed because the natural finger return-to-origin after a swipe would trigger a reverse swipe. Velocity-based detection ignores the slow wind-up and return.

**Grace period on hand entry** — When a hand enters the frame, the upward motion of raising it registers as velocity. A 5-frame grace period suppresses detection until the hand settles.

**Single-hand isolation** — Hold gestures (left hand numbers/enter/escape, right hand 🤙 delete) are disabled when both hands are detected. Prevents accidental triggers during two-hand combos.

**Scroll via left wrist tracking** — Left pinch + right fist activates scroll. Left hand Y movement drives scroll events. This keeps the right hand as a "mode selector" while left hand (already committed to pinch) provides the motion.

**Drag-and-drop** — Left pinch while right hand is pinch-dragging posts mouseDown at start, leftMouseDragged events during movement, and mouseUp on release.

**Two-finger pinch = right click** — Index + middle both touching thumb. Checked before regular pinch so it takes priority.

## Gesture Parameters

| Parameter | Value | Location |
|-----------|-------|----------|
| `holdDuration` | 1.0s | TrackingCoordinator |
| `swipeCooldown` | 1.0s | SwipeDetector |
| `velocityThreshold` | 0.6 | SwipeDetector |
| `handEntryGraceFrames` | 5 | SwipeDetector, TrackingCoordinator |
| `rightThumbPinkyFrames` | 5 | DeleteController |
| `sensitivity` (cursor) | 2.5 | CursorDragController |
| `sensitivity` (scroll) | 1500 | ScrollController |
| `pinchThreshold` | 0.06 | GestureClassifier |
| `twoFingerPinchThreshold` | 0.07 | GestureClassifier |

## Known Issues

- `countExtendedFingers` uses tip.y > pip.y which fails when hand is sideways
- Speech partial results can occasionally repeat (mitigated by lastTypedLength tracking)
- Scroll sensitivity may need per-app tuning (1500 is aggressive)

## Next Steps

- ~~**SEO for GitHub search** — add relevant topics/tags to the repo (hand-tracking, gesture-control, macos, accessibility, vision-framework, hands-free), write a compelling repo description, add social preview image~~
- ~~**SEO for Google search** — optimize README with searchable keywords (e.g. "control mac with hand gestures", "hands-free mac cursor", "webcam gesture recognition macos"), add a GitHub Pages landing page with structured data, submit to macOS tool directories and HN/Product Hunt~~
- **Two-finger directional hold** — point index+middle in a direction to fire accelerating arrow key repeats. Attempted but detection was unreliable (conflicts with swipe, hard to distinguish from 1-finger or fist in various orientations). Needs a fundamentally different approach — possibly using wrist angle + finger count, or a dedicated ML classifier trained on pointing poses
- ~~**Voice commands during speech mode** — when speech-to-text is active, recognize command keywords and execute them instead of typing.~~
- ~~**Dynamic Island visual redesign** — redesigned with Apple Liquid Glass (.glassEffect on macOS 26+, thinMaterial fallback). SF Symbols for hand indicators, adaptive colors for glass/dark backgrounds.~~
- ~~**Circle-to-screenshot gesture** — right-hand pinch + draw a circle captures the enclosed screen region. Shows floating preview thumbnail for 3s, then copies to clipboard.~~
