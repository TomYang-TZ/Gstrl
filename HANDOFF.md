# Gstrl — Engineering Handoff

## Architecture

```
Sources/Gstrl/
├── GstrlApp.swift                 App entry, window + island panel lifecycle
├── AppState.swift                 @Observable model — all UI-bound state
├── DynamicIslandView.swift        Floating glass overlay (expandable, click-through)
├── MainStatusView.swift           Tabbed settings window (Settings/Agent/Gestures)
├── Camera/
│   └── CameraManager.swift        AVCaptureSession @ 30fps, delivers CVPixelBuffer
├── Tracking/
│   ├── TrackingCoordinator.swift  Orchestrator — frame processing + priority routing
│   ├── AgentController.swift      Speech → silence → claude -p (stream-json) → TTS
│   ├── GestureClassifier.swift    Static: isPinching, isTwoFingerPinch, isThumbPinky
│   ├── SwipeDetector.swift        Velocity-based swipe with grace period + cooldown
│   ├── DeleteController.swift     Escalating delete state machine
│   ├── ScrollController.swift     Relative scroll via wrist Y tracking
│   ├── CursorDragController.swift Right-pinch cursor drag + drag-and-drop
│   ├── SpeechController.swift     Hold countdown + SpeechEngine + transcript fade
│   ├── InputDispatch.swift        GestureAction enum → CGEvent
│   └── TrackingState.swift        Enum: inactive | tracking | pinching
└── Speech/
    ├── SpeechEngine.swift         SFSpeechRecognizer → CGEvent typing
    └── VoiceCommandParser.swift   "press"/"command"/"control" + key → action
```

## Build & Run

```bash
make run       # build + launch
make install   # build + copy to /Applications
make restart   # stop + build + launch
make stop      # kill running instance
```

## Dynamic Island — Current Design

### Panel Structure
- `ClickThroughPanel` (NSPanel, statusBar level, canBecomeKey=false, 300x200)
  - `ClickThroughContainerView` (hitTest returns nil for self → click-through)
    - `ClickThroughHostingView` (SwiftUI content, acceptsFirstMouse=true)

### Layout (DynamicIslandView)
- Single glass container, fixed 280px wide, cornerRadius 14
- `.glassEffect(.regular, in: .rect(cornerRadius: 14))` on macOS 26+
- `.clipShape(RoundedRectangle)` BEFORE `.glassEffect`
- Compact row (32px): hands at edges via `Spacer()`, StatusButton center
- Expanded section: always in tree, height animates via `maxHeight` + `.clipped()`
- `.fixedSize(horizontal: false, vertical: true)` so height fits content (max 150px)
- `.easeOut(duration: 0.2)` animation on `isExpanded` and `responseExpanded`
- `PointerButtonStyle` on all buttons (cursor change + press dim)

### Key Constraints Learned
- `.glassEffect` does NOT clip content — explicit `.clipShape` needed before it
- `.glassEffect` does NOT animate shape changes smoothly — keep width fixed
- Conditional `if` views cause jarring transitions — keep views in tree, animate height
- NSPanel size must accommodate expanded content (300x200 minimum)
- `ClickThroughContainerView.hitTest` returns nil for self → transparent areas pass clicks

## Agent System

- `claude -p --output-format stream-json --verbose`
- `readabilityHandler` on pipe streams events in real-time
- Parses `type: "assistant"` for `tool_use` → live action display in island
- Parses `type: "result"` for final response
- `--add-dir ~/.claude` for user context
- `--add-dir /tmp/gstrl/<session>` for session files
- `--resume <session_id>` for multi-turn
- "No response" or empty results silently dismissed (not shown or spoken)
- Clipboard image only attached if changed within last 60s

## Completed (2026-05-09)

- Agent streaming with live thinking/action display in island
- Dynamic Island redesign: single glass container, expandable downward, content-fit height
- Click-through panel (transparent areas pass clicks to windows below)
- Collapsible chat entries in Agent History tab
- Agent actions tracked from stream-json tool_use blocks
- Terminate agent button (kills claude process)
- STT command flash (3s display in transcript area)
- Delete countdown border properly wired
- Follow-up listening (both fists during response re-enters listening)
- PointerButtonStyle for all interactive elements
- "No response" suppression (not shown, not spoken)

## Next Steps

### Priority: Cursor Jitter Fix
When holding the right hand still in pinch position (cursor drag mode), the cursor jitters/vibrates instead of staying still. This is because Vision framework hand landmark detection has per-frame noise (~1-3px), and CursorDragController directly maps position delta to cursor movement without any smoothing.

**Approach to fix:**
1. Look at `Sources/Gstrl/Tracking/CursorDragController.swift`
2. The `process()` method computes delta from current vs previous palm center position
3. Add a **dead zone** — ignore movement below a threshold (e.g. 0.005 normalized units)
4. Add **exponential smoothing** — blend current position with previous (e.g. `smoothed = 0.7 * current + 0.3 * previous`)
5. Consider a **velocity gate** — only move cursor when velocity exceeds a minimum, stops instantly when below

The key insight: Vision's hand pose estimation has inherent jitter even on a perfectly still hand. The fix is signal processing (smoothing + dead zone), not changing the detection.

### Other Remaining Tasks
- Landing page redesign (color, motion, demo video)
- Launch strategy (Reddit, X, RedNote)
- Two-finger directional hold (needs ML classifier)
- App window resizable (caused layout gaps before)
