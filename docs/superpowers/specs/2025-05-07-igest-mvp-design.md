# iGest MVP Design Spec

## Overview

iGest is a macOS menu-bar app that controls the cursor using eye tracking (gaze direction via webcam) and hand gesture recognition (pinch to click). All processing is on-device using Apple Vision framework. No external hardware required.

**Target users:** Developers and RSI sufferers who want to reduce mouse usage.

**Platform:** macOS (native Swift/SwiftUI)

**Framework:** Apple Vision framework only (VNDetectFaceLandmarksRequest, VNDetectHumanHandPoseRequest)

## Interaction Model

| Input | Action |
|-------|--------|
| Palm up (open hand visible to webcam) | Activate gaze tracking — cursor follows eye position with smoothing |
| Palm down / hand not visible | Tracking deactivated — cursor stays in place, user can look freely |
| Pinch (thumb tip meets index tip) | Mouse down (begins press) |
| Pinch release (thumb separates from index) | Mouse up (completes click) |
| Escape key (global hotkey) | Emergency kill — instantly disables tracking, returns cursor control to physical input |

A "click" is the full pinch + release cycle. The split into down/up enables drag support in future versions.

### Gaze Tracking Behavior

- While palm is up, cursor continuously follows gaze position
- Exponential moving average smoothing applied (~200ms window) to reduce jitter
- Gaze position mapped to screen coordinates via calibration polynomial transform
- When palm drops, cursor freezes at last tracked position

### Gesture Detection

- Palm open: all five fingers extended, hand facing camera
- Pinch: distance between thumb tip and index finger tip below threshold
- Debouncing applied to prevent flicker between states (~50ms)

## Architecture

```
┌─────────────────────────────────────────────────┐
│  iGest (macOS Menu Bar App)                     │
│                                                 │
│  ├── AppDelegate / SwiftUI App                  │
│  │   └── Menu bar icon + dropdown menu          │
│  │                                              │
│  ├── CameraManager                              │
│  │   ├── AVCaptureSession (30fps, 720p)         │
│  │   └── Dispatches frames to trackers          │
│  │                                              │
│  ├── GazeTracker                                │
│  │   ├── VNDetectFaceLandmarksRequest           │
│  │   ├── Eye region crop + pupil detection      │
│  │   ├── 2nd-order polynomial calibration       │
│  │   └── EMA smoothing filter                   │
│  │                                              │
│  ├── HandTracker                                │
│  │   ├── VNDetectHumanHandPoseRequest           │
│  │   ├── Palm-open classifier                   │
│  │   ├── Pinch classifier                       │
│  │   └── State debouncer                        │
│  │                                              │
│  ├── CalibrationEngine                          │
│  │   ├── 9-point calibration wizard UI          │
│  │   ├── Gaze vector collection per point       │
│  │   ├── Polynomial transform computation       │
│  │   └── Persistence (UserDefaults)             │
│  │                                              │
│  └── CursorController                           │
│      ├── CGEvent mouse move                     │
│      ├── CGEvent mouse down/up                  │
│      └── Coordinate mapping to screen space     │
└─────────────────────────────────────────────────┘
```

## Components

### CameraManager

- Initializes AVCaptureSession with built-in webcam
- Captures at 30fps, 720p resolution
- Runs on a dedicated background queue
- Creates one VNImageRequestHandler per frame with both VNDetectFaceLandmarksRequest and VNDetectHumanHandPoseRequest attached — Apple's recommended pattern for multi-request processing
- Processes both requests sequentially on the same handler (thread-safe per frame)
- Drops incoming frames if previous frame is still processing (backpressure, no queuing)
- Handles camera permission request flow

### GazeTracker

- Receives video frames from CameraManager
- Runs VNDetectFaceLandmarksRequest to extract face landmarks (eye contours, not raw pupil)
- **Pupil estimation approach:** Apple Vision provides eye contour landmarks (inner/outer corners, upper/lower lids) but NOT pupil center. To estimate gaze direction:
  1. Extract the eye region bounding box from face landmarks
  2. Crop the eye region from the video frame
  3. Apply thresholding + contour detection on the cropped eye region to locate the dark pupil blob
  4. Compute pupil position as a ratio within the eye bounding box (0.0 = looking left, 1.0 = looking right)
  5. Combine left and right eye estimates for robustness
- Computes normalized gaze vector (horizontal + vertical offset from eye center)
- Applies calibration transform: gaze vector → screen point (x, y)
- Uses 2nd-order polynomial mapping (12 parameters) rather than affine for better accuracy at screen edges — still solvable with 9 calibration points via least squares
- Applies EMA smoothing: `smoothed = α * new + (1-α) * previous` where α ≈ 0.3
- Publishes screen coordinate to CursorController when tracking is active
- Drops frames if previous frame is still processing (backpressure — never queues)

### HandTracker

- Receives video frames from CameraManager
- Runs VNDetectHumanHandPoseRequest
- Extracts joint positions for all five fingers + thumb
- Classifies gestures:
  - **Palm open:** All finger tips above their respective PIP joints (fingers extended), confidence > 0.7
  - **Pinch:** Euclidean distance between thumb tip and index tip < threshold (normalized), confidence > 0.7
- Applies debouncing (50ms minimum state duration) to prevent flicker
- Publishes state changes: `.inactive` → `.tracking` → `.pinching`

### CalibrationEngine

- Presents fullscreen overlay window with calibration dots
- Sequence: 9 points in grid pattern (corners, edges, center)
- Each point: dot appears → user fixates for 2 seconds → collects gaze vectors
- After all points collected, computes 2nd-order polynomial mapping (least squares, 12 parameters)
- Stores calibration coefficients in UserDefaults
- Can be re-triggered from menu bar

### CursorController

- Receives screen coordinates from GazeTracker + gesture state from HandTracker
- State machine:
  - HandTracker state = `.tracking` (palm up) → post CGEvent mouseMoved to gaze point
  - HandTracker state = `.pinching` → post CGEvent leftMouseDown (once, on transition)
  - HandTracker state transitions `.pinching` → `.tracking` → post CGEvent leftMouseUp
  - HandTracker state transitions `.pinching` → `.inactive` → post CGEvent leftMouseUp (safety release — prevents stuck mouse-down)
  - HandTracker state = `.inactive` → do nothing (cursor frozen)
- **Emergency kill:** Global hotkey (Escape or Cmd+Shift+G) instantly sets state to `.inactive`, fires mouseUp if currently pinching, and disables all tracking until re-enabled from menu bar
- Uses CGEvent with Quartz Event Services
- Requires Accessibility permission

## Menu Bar UI

- **Icon:** Eye symbol (SF Symbol: `eye`)
- **States:**
  - Gray: disabled/off
  - Green: active and ready (camera running, waiting for hand)
  - Blue: tracking active (palm detected, cursor following gaze)
- **Menu items:**
  - Toggle On/Off
  - Recalibrate
  - Sensitivity (submenu: Low / Medium / High — adjusts smoothing α)
  - Emergency Kill Hotkey: Escape (shown as reminder)
  - Quit

## Permissions

| Permission | Why | Prompt |
|-----------|-----|--------|
| Camera | Webcam access for face/hand detection | System privacy dialog on first launch |
| Accessibility | Posting synthetic mouse events via CGEvent | Directs user to System Preferences → Privacy & Security → Accessibility |

## Data Flow

```
Webcam frame (30fps)
    ├──→ GazeTracker → gaze screen point (smoothed)
    └──→ HandTracker → gesture state (.inactive/.tracking/.pinching)
                            │
                            ▼
                    CursorController
                    ├── if .tracking: move cursor to gaze point
                    ├── if .pinching: mouseDown
                    └── if .inactive: do nothing
```

## MVP Scope

### In Scope
- Palm-up activates continuous gaze tracking with smoothing
- Pinch-to-click (down on pinch, up on release)
- 9-point manual calibration wizard
- Menu bar icon with on/off toggle
- Sensitivity adjustment (smoothing level)
- Single monitor support

### Explicitly Out of Scope (Future)
- Scrolling (hand tilt or two-finger gesture)
- Drag support (pinch-hold + gaze move)
- Right-click (two-finger pinch or other gesture)
- Multi-gesture (zoom, swipe between spaces)
- Auto-calibration / adaptive learning
- Floating overlay / debug visualization
- Multi-monitor support
- Apple system gestures integration (zoom, Mission Control)
- iPad as camera source
- Preferences window beyond menu items

## Technical Risks

| Risk | Mitigation |
|------|-----------|
| Webcam gaze accuracy limited (~2-5° error) | 9-point calibration + heavy smoothing. Accept ~100px landing accuracy — good enough for coarse targeting |
| Apple Vision face landmarks may not provide accurate pupil direction | Test early. If insufficient, pivot to MediaPipe iris tracking in v2 |
| Hand detection latency on older Macs | Profile on target hardware. Can reduce camera resolution or frame rate if needed |
| Lighting sensitivity (webcam quality varies) | Document recommended setup (face well-lit, avoid backlighting). No software fix for MVP |
| Accessibility permission friction | Clear onboarding guidance with direct link to System Preferences |

## Success Criteria

MVP is validated if a user can:
1. Complete calibration in under 30 seconds
2. Move cursor to a target region (e.g., a large button) within 2 seconds
3. Click the target via pinch gesture
4. Repeat this reliably (>70% hit rate on ~100px targets)
5. Complete a 5-minute workflow (e.g., navigate a website, click links) with natural rest breaks (palm down to pause between actions)
