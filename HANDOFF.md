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
