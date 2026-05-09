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

### Structure
- `ClickThroughPanel` (NSPanel, statusBar level, canBecomeKey=false, 300x200)
  - `ClickThroughContainerView` (hitTest returns nil for self → click-through)
    - `ClickThroughHostingView` (SwiftUI content)

### Layout (DynamicIslandView)
```
┌──────────────────────────────────────┐  280px fixed, cornerRadius 14
│  🖐         [ON/gesture]         🖐  │  32px compact row (always visible)
│──────────────────────────────────────│
│  expanded content (fits to content)  │  max 150px, sizes to text
└──────────────────────────────────────┘
```

- Single glass container, fixed 280px width, `.glassEffect(.regular, in: .rect(cornerRadius: 14))`
- `.clipShape(RoundedRectangle)` BEFORE `.glassEffect` — glass doesn't clip content
- Compact row always at top, hands at edges via `Spacer()`
- Expanded section appears/disappears with `.easeInOut(0.25)` animation
- Uses `.fixedSize(horizontal: false, vertical: true)` so height fits content (max 150px cap)
- `PointerButtonStyle` on all buttons — cursor change + press dim

### Island Modes
- **compact**: just top row
- **transcript**: top row + HStack (text + waveform/sendCircle/stopButton)
- **response**: top row + HStack (text + chevron + xmark, alignment: .top)

### Key Constraints
- `.glassEffect` does NOT animate shape changes — width must stay fixed
- NSPanel must be large enough (300x200) for expanded content
- `ClickThroughContainerView.hitTest` returns nil for self → transparent areas pass clicks through

## Agent System

- Uses `claude -p --output-format stream-json --verbose`
- `readabilityHandler` on pipe streams events in real-time
- Parses `type: "assistant"` messages for `tool_use` blocks → live action display
- Parses `type: "result"` for final response
- `--add-dir ~/.claude` for user context
- `--add-dir /tmp/gstrl/<session>` for session files
- `--resume <session_id>` for multi-turn
- Clipboard image only attached if clipboard changed within last 60s

## Completed (This Session — 2026-05-09)

- **Island follow-up listening** — both fists during response clears response, re-enters listening
- **Collapsible chat entries** — `CollapsibleChatEntry` in Agent History, latest expanded by default
- **Agent actions in history** — tool_use blocks parsed from stream-json, shown with purple icons
- **Live agent activity in island** — thinking/action events stream to island in real-time
- **Terminate agent button** — kills running claude process
- **STT command flash** — voice commands show in transcript for 3s
- **Delete countdown border** — properly sets gestureCountdownStart
- **Island redesign** — single glass container, expandable downward, fixed width
- **Click-through panel** — ClickThroughContainerView + ClickThroughPanel
- **PointerButtonStyle** — all buttons show pointing hand cursor on hover
- **Clipboard freshness** — only attaches images < 60s old

## Remaining Tasks

1. **Landing page redesign** — color, motion, personality, demo video hero
2. **Launch strategy** — Reddit, X, RedNote posts with demo GIF
3. **Two-finger directional hold** — needs ML classifier approach
4. **App window resizable** — needs proper approach (caused layout gaps before)
