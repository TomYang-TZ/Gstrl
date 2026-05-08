# iGest — Engineering Handoff

## Architecture

```
Sources/iGest/
├── iGestApp.swift                 App entry, window + island panel lifecycle
├── AppState.swift                 @Observable model — all UI-bound state
├── DynamicIslandView.swift        Floating notch overlay (NotchShape + SwiftUI)
├── MainStatusView.swift           Settings window with gesture reference
├── Camera/
│   └── CameraManager.swift        AVCaptureSession @ 30fps, delivers CVPixelBuffer
├── Cursor/
│   └── CursorController.swift     (Legacy — cursor logic moved into TrackingCoordinator)
├── Tracking/
│   ├── TrackingCoordinator.swift  Core gesture engine — frame processing + action dispatch
│   ├── HandTracker.swift          (Legacy — classification moved into TrackingCoordinator)
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
    → Gesture state machine (priority order):
        1. Fingers crossed (X)? → Ctrl+C (cancel)
        2. Both hands 🤙? → Delete lines (escalating)
        3. Both hands open? → Speech countdown/activation
        4. Right hand pinch? → Relative cursor drag
        5. Right hand 🤙? → Delete chars (accelerating)
        6. Right hand open? → Velocity-based swipe detection
        7. Left hand pinch? → Click (CGEvent)
        8. Left hand fingers? → Hold-to-fire (numbers/enter/escape)
    → AppState updates (main thread)
    → UI reacts (SwiftUI observation)
```

## Key Design Decisions

**Velocity-based swipe detection** — Displacement-based was tried first but failed because the natural finger return-to-origin after a swipe would trigger a reverse swipe. Velocity-based detection ignores the slow wind-up and return, only firing on 2+ consecutive frames of fast, directional motion.

**Grace period on hand entry** — When a hand enters the frame, the upward motion of raising it into view registers as velocity. A 5-frame grace period (`handEntryGraceFrames`) suppresses detection until the hand settles. Same grace applies after releasing a pinch (finger opening motion would otherwise trigger swipe).

**Single-hand isolation** — Hold gestures (left hand numbers/enter/escape, right hand 🤙 delete) are disabled when both hands are detected. This prevents accidental triggers during two-hand combos. Left pinch (click) is the exception — always active.

**Right 🤙 debounce** — `isThumbPinky` can false-positive during fast swipes (fingers curl momentarily). Requires 5 consecutive frames (`rightThumbPinkyFrames`) before starting the delete timer.

**Speech typing fix** — CGEvent with `virtualKey: 0` maps to the A key. If any modifier flag leaked from a prior gesture keypress, it fired Cmd+A (select all). Fixed by using `virtualKey: 49` (space, harmless) with explicit `flags = []`.

## Gesture Parameters

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `holdDuration` | 1.0s | Time to hold before gesture fires |
| `swipeCooldown` | 1.0s | Minimum time between swipes |
| `velocityThreshold` | 0.6 | Min speed (normalized units/sec) to count as swipe |
| `handEntryGraceFrames` | 5 | Frames to ignore after hand appears / pinch releases |
| `rightThumbPinkyFrames` | 5 | Consecutive 🤙 frames required before delete starts |
| `sensitivity` | 2.5 | Cursor movement multiplier for pinch-drag |
| `deleteRepeat` | 0.5→0.1s | Accelerating delete (chars 0-5s, words 5-8s, lines 8-11s, select-all 11s+) |

## Window Architecture

- **Main window** — NSWindow with SwiftUI content. Enable/disable toggle + gesture reference table.
- **Island panel** — NSPanel (borderless, nonactivating, stationary, `.statusBar` level). 400×100 frame, content clipped to NotchShape. Sits at top-center of screen across all spaces.

## Build

```bash
./restart.sh   # kills running app, builds, codesigns, relaunches
```

Requires Accessibility permission at `/Users/tomyang/iGest/iGest.app` — persists across rebuilds if path and ad-hoc signature stay the same.

## Refactor Tasks

1. **Delete dead code** — `CursorController.swift`, `HandTracker.swift`, and the `private let handTracker` line in TrackingCoordinator. All logic lives inline now.
2. **Break up TrackingCoordinator (795 lines)** — Extract into focused types:
   - `SwipeDetector` — velocity tracking, grace period, cooldown
   - `DeleteController` — escalation state machine (chars→words→lines→all)
   - `SpeechController` — countdown + SpeechEngine lifecycle
   - `GestureClassifier` — `isPinching`, `isThumbPinky`, `countExtendedFingers`, `isFingersCrossed`
   - Keep `TrackingCoordinator` as the orchestrator that delegates to these
3. **Typed gesture events** — Replace the scattered `pressKey`/`pressKeyWithModifiers` calls with a `GestureAction` enum that gets dispatched centrally. Makes testing and logging trivial.
4. **Progress bar driven by SwiftUI Timer** — Currently progress is set per-frame from the camera callback (30fps). Smoother approach: set target + duration, let SwiftUI `TimelineView` or `withAnimation` interpolate.
5. **`countExtendedFingers` reliability** — tip.y > pip.y fails when hand is sideways or tilted. Could use angle between joints instead of raw Y comparison.

## Known Issues

- **Accessibility permission resets** if you move the .app or change signing identity
- **Escape key kills tracking** when iGest window is focused (local event monitor)
- **Camera runs on background thread** — all AppState writes dispatch to main
- **`isThumbPinky` false positives** during fast motion — mitigated by frame debounce but not eliminated
- **Speech partial results** can occasionally repeat or shorten — `lastTypedLength` tracking handles it but edge cases exist
