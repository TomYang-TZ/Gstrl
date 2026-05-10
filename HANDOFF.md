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

### Panel Structure (GstrlApp.swift)
```
NSPanel (300x200, statusBar level, ignoresMouseEvents=true initially)
  └── ClickThroughHostingView (SwiftUI content)
        - Global NSEvent monitor toggles ignoresMouseEvents
        - When mouse is over island area → accepts clicks
        - When mouse is elsewhere → passes through to apps below
```

### Click-Through Mechanism (CRITICAL LEARNING)
The panel uses `ignoresMouseEvents = true` by default. A **global event monitor** (`NSEvent.addGlobalMonitorForEvents`) tracks mouse position and toggles `ignoresMouseEvents` based on whether the cursor is over the island content area.

**Why this approach:**
- NSPanel `hitTest` overrides DON'T WORK for SwiftUI — `super.hitTest` returns the hosting view itself (not subviews) because SwiftUI renders into the hosting view directly
- `ClickThroughContainerView.hitTest` returning nil for self doesn't help — the hosting view child still claims the full rect
- Only `ignoresMouseEvents` + global monitor correctly separates "island clickable" from "background passthrough"

**Dynamic hit area:**
- Uses `appState.islandHeight` (set via GeometryReader in DynamicIslandView)
- Hit rect: 280 x islandHeight at top center of panel
- Automatically grows/shrinks as island expands/collapses

### Layout (DynamicIslandView.swift)
```
VStack(spacing: 0) {
    compactContent         // 32px, hands at edges via Spacer(), StatusButton center
    expandedSection        // height 0→150 animated, .clipped(), opacity toggle
}
.frame(width: 280)
.modifier(IslandGlassModifier(cornerRadius: 14))
```

- Fixed 280px width — glass shape never changes width
- `.glassEffect(.regular, in: .rect(cornerRadius: 14))` on macOS 26+
- `.clipShape(RoundedRectangle)` BEFORE `.glassEffect` — glass doesn't clip content
- `.fixedSize(horizontal: false, vertical: true)` so height fits content (max 150px)
- `.easeOut(duration: 0.2)` animation
- `PointerButtonStyle` on all buttons (cursor + press dim)

### Key Constraints (Hard-Won Learnings)

1. **`.glassEffect` does NOT clip content** — must add explicit `.clipShape` before it
2. **`.glassEffect` does NOT animate shape changes** — any width/radius animation causes jarring pop. Keep dimensions fixed or only animate height
3. **Conditional `if` views cause jarring transitions** — keep views in tree, animate height/opacity instead
4. **NSHostingView hitTest always returns self** — SwiftUI doesn't create NSView subviews for buttons. Can't use hitTest to distinguish interactive vs empty areas
5. **`ignoresMouseEvents = true` blocks tracking areas too** — can't use NSTrackingArea to toggle it back. Must use global event monitor
6. **NSPanel size must accommodate expanded content** — 300x200 minimum
7. **Panel at statusBar level blocks everything below** — the 300x200 rect eats ALL clicks unless `ignoresMouseEvents = true`

## Agent System

- `claude -p --output-format stream-json --verbose`
- `readabilityHandler` streams events in real-time (thinking, tool_use, result)
- `--add-dir ~/.claude` for user context
- `--add-dir /tmp/gstrl/<session>` for session files
- `--resume <session_id>` for multi-turn
- "No response" or empty results silently dismissed
- Clipboard image only attached if changed within last 60s
- Terminate button kills `claudeProcess` reference

## Completed (2026-05-09)

- Agent streaming with live thinking/action display
- Dynamic Island redesign: single glass, fixed width, expandable height
- Click-through panel with global event monitor
- Collapsible chat entries in Agent History
- Agent actions parsed from stream-json tool_use blocks
- Terminate agent button
- STT command flash (3s)
- Delete countdown border
- Follow-up listening (both fists during response)
- PointerButtonStyle for all elements
- "No response" suppression

## Completed (2026-05-09, continued)

- Cursor jitter fix in `CursorDragController.swift`:
  - Exponential smoothing (0.7 current + 0.3 previous) on palm position
  - Dead zone (0.002 normalized) with continuous re-anchoring to prevent exit jumps
  - Velocity gate (0.001 minimum) to suppress sub-pixel noise
  - Thresholds tuned low since smoothing handles most noise — gates only catch residual

## Next Steps

### Other
- Landing page redesign
- Launch strategy (Reddit, X, RedNote)
- Two-finger directional hold (ML classifier)
