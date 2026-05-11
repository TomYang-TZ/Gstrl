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
- Screenshot preview moved inside island glass (was floating separately)
- Spring transition animation on screenshot appear/dismiss

## Completed (2026-05-10)

- Agent system prompt added (`AgentController.swift`): G.S.T.R.L. identity, tool list, safety guardrails
- Landing page redesign (`docs/index.html`):
  - CSS 3D interactive title (mouse-follow tilt, clamped ±20°)
  - Scroll-snap sections, animated gesture cards (left/right/scale reveals)
  - Terminal chrome on install block, gradient progress bar
  - Noise overlay, animated SVG logo with rotating arcs
  - Warm cream theme with DM Sans typography

## Completed (2026-05-10, continued)

- Multilingual speech: language picker (EN/中文/粵語/ES) in Settings tab
  - `SpeechEngine.updateLocale()` swaps recognizer (only when locale changes AND not listening)
  - `SpeechController` and `AgentController` both sync via `TrackingCoordinator.syncSettings()`
- Chinese voice commands (suffix-matching, no prefix needed):
  - 回车/确认/换行, 删除, 取消, 点击, 右键, 撤销, 复制, 粘贴, 全选, 全删, 保存
  - Trailing 键 stripped before matching (回车键 → 回车)
- Spanish voice commands: pulsa/presiona prefix, arriba/abajo/izquierda/derecha, clic/clic derecho
- English: click/right click without prefix, all others require prefix (press/command/control/shift/option)
- Voice tab in app: language-specific command reference, switches with language setting
- TTS language sync: agent responses spoken in matching voice (Tingting/Sinji/Mónica)
- Island tap: whole compact bar opens window, ON/OFF button only toggles
- Island press animation restored (scale 0.95 on press)
- Hand indicator fix: cache reset in empty-results path so indicators update after flicker
- Launch posts drafted (.drafts/launch-posts.md): Reddit (6 subs) + RedNote (3 posts)

## Key Learnings (Speech System)

1. **`CGEventSource.flagsState(.combinedSessionState)` includes our own posted events.** After posting ⌘Z, the combined state retains `.maskCommand`. Next event inherits it. Fix: use `.hidSystemState` for reading physical keys, OR pass `usePhysicalModifiers: false` for voice commands.

2. **`CGEvent(keyboardEventSource: nil)` inherits system state.** Events created with nil source pick up stale modifiers. Fix: use `CGEventSource(stateID: .privateState)` as event source.

3. **`SFSpeechRecognizer` is destroyed when you reassign the property.** Calling `updateLocale()` during an active recognition session kills the session silently. Fix: guard with `!isListening` and `identifier != currentLocale`.

4. **Hand detection can flicker (single-frame drops).** If `results.isEmpty` immediately resets speech, the session dies. Fix: only reset speech in the empty-results path if `!speechController.isActive`, or use a frame counter.

5. **SFSpeechRecognizer partial results are not monotonic.** The cumulative text can revise/shrink. Track `committedSnapshot` (full text at commit time) and skip frames where the prefix no longer matches.

6. **Voice commands must not read physical modifiers.** During speech, no physical keys are held — but system state can be stale from prior CGEvents. Voice path uses `InputDispatch.perform(action, usePhysicalModifiers: false)`.

## Next Steps

- Two-finger directional hold (ML classifier)
- Video demo for launch
