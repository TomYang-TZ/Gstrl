# Gstrl — Engineering Handoff

## Architecture

```
Sources/Gstrl/
├── GstrlApp.swift                 App entry, window + island panel lifecycle
├── AppState.swift                 @Observable model — all UI-bound state
├── DynamicIslandView.swift        Floating glass overlay (expandable, click-through)
├── MainStatusView.swift           Tabbed settings window (Settings/Agent/Gestures)
├── KeyRecorderView.swift          Key capture UI + NSEvent monitor (keys/media)
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
│   ├── KeyBinding.swift            GestureSlot enum + KeyBinding struct + defaults
│   ├── GestureActionConfig.swift  Singleton config manager (UserDefaults)
│   ├── InputDispatch.swift        GestureAction enum → CGEvent + media keys
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
- Voice commands: English only (click/right click without prefix, all others require prefix)
  - Chinese/Spanish voice commands removed (too many edge cases with recognizer revisions)
  - Language picker remains for STT dictation language
- Voice tab in app: language-specific command reference, switches with language setting
- TTS language sync: agent responses spoken in matching voice (Tingting/Sinji/Mónica)
- Island tap: whole compact bar opens window, ON/OFF button only toggles
- Island press animation restored (scale 0.95 on press)
- Hand indicator fix: cache reset in empty-results path so indicators update after flicker

## Key Learnings (Speech System)

1. **`CGEventSource.flagsState(.combinedSessionState)` includes our own posted events.** After posting ⌘Z, the combined state retains `.maskCommand`. Next event inherits it. Fix: use `.hidSystemState` for reading physical keys, OR pass `usePhysicalModifiers: false` for voice commands.

2. **`CGEvent(keyboardEventSource: nil)` inherits system state.** Events created with nil source pick up stale modifiers. Fix: use `CGEventSource(stateID: .privateState)` as event source.

3. **`SFSpeechRecognizer` is destroyed when you reassign the property.** Calling `updateLocale()` during an active recognition session kills the session silently. Fix: guard with `!isListening` and `identifier != currentLocale`.

4. **Hand detection can flicker (single-frame drops).** If `results.isEmpty` immediately resets speech, the session dies. Fix: only reset speech in the empty-results path if `!speechController.isActive`, or use a frame counter.

5. **SFSpeechRecognizer partial results are not monotonic.** The cumulative text can revise/shrink. Track `committedSnapshot` (full text at commit time) and skip frames where the prefix no longer matches.

6. **Voice commands must not read physical modifiers.** During speech, no physical keys are held — but system state can be stale from prior CGEvents. Voice path uses `InputDispatch.perform(action, usePhysicalModifiers: false)`.

## Completed (2026-05-11)

- Voice command latency: debounce 0.3s, partial wait 0.5s
- Island repositions on display change (observes `didChangeScreenParametersNotification`)
- Island positioned left of notch on notch Macs
- Landing page: keycap badges + inline SVG icons, gesture emojis in card titles
- Double-click: quick double-pinch gesture + "double click" voice command
- Cursor: double exponential smoothing, removed dead-zone re-anchoring (was causing jumps)
- Scroll: removed time-based acceleration (constant speed), light wrist Y smoothing, FPS-independent
- Screenshot circle detection thresholds relaxed (easier to trigger)
- Screenshot preview: removed pill-shaped glass backdrop
- Modifier key-up fix: up events clear flags to prevent system state contamination
- Private CGEventSource: events don't inherit/pollute system modifier state
- Voice `usePhysicalModifiers: false`: voice commands ignore stale system state
- Partial prefix no longer typed as text (waits silently, discards if no keyword)
- Transcript clears all at once after 2s (no word-by-word fade)
- Agent history: stores selected text, clickable "📄 N lines" opens popover with full context
- Cursor sensitivity default 2.5x, max 10x
- Repo made public, GitHub Pages enabled
- Removed Chinese/Spanish voice commands (English only, kept language picker for STT dictation)

## Key Learnings (2026-05-11)

7. **CGEvent key-up must clear modifier flags.** If `up.flags = flags` (same as down), the system thinks the modifier is still held. Fix: `up.flags = []`.

8. **`CGEvent(keyboardEventSource: nil)` inherits combined session state.** Use `CGEventSource(stateID: .privateState)` to isolate events from each other.

9. **`results.isEmpty` flickers during active hand tracking.** Vision can miss a hand for 1-2 frames. Use a frame counter (`noHandFrames > 10`) before resetting speech — don't kill it on a single empty frame.

10. **Partial prefixes that match common words ("right", "double") add unwanted latency.** Better to rely on the debounce window (0.3s) keeping both words in the same commit, and accept occasional split-word failures.

## Completed (2026-05-12)

- Whip cursor overlay (`WhipOverlay.swift`):
  - Animated GIF (willie-whip from Tenor) displayed above cursor during pinch control
  - HSB-based chroma key removes blue sky background per frame on load
  - Panel tracks real cursor position at 60fps (independent of camera frame rate)
  - Debounced hide (0.15s) to prevent flicker from hand tracking drops
  - Resource bundle added to Makefile build step
  - "Whip cursor" toggle in Settings tab (`appState.whipEnabled`)
- HN Show HN post drafted (`.drafts/launch-posts.md`):
  - Title: "Show HN: I control my Mac with hand gestures using just the webcam"
  - First comment with feature list, design choices, technical challenges
  - Pre-written replies for common HN questions (why not mouse, latency, privacy)
  - HN currently restricting new Show HN posts — needs karma first

## Key Learnings (2026-05-12)

11. **`Bundle.main` doesn't find SPM resources in executable targets.** SPM puts them in `Gstrl_Gstrl.bundle` — must look in `Bundle.main.resourceURL` subdirectory or copy the bundle into the app manually via Makefile.

12. **NSPanel `orderFrontRegardless` must be called on main thread.** Camera callbacks run on `com.gstrl.camera` dispatch queue — calling AppKit UI methods from there crashes with "Must only be used from the main thread".

13. **Code signature changes when bundle contents change.** Adding a resource bundle invalidates the ad-hoc signature → macOS revokes Accessibility/Camera/Screen Recording permissions. Use `tccutil reset` to re-prompt.

## Completed (2026-05-12, continued)

- Fix: Dock magnification now triggers during pinch-cursor (post CGEvent.mouseMoved after CGWarpMouseCursorPosition)
- Fix: Cursor crosses to secondary screen (replaced NSScreen.main clamping with CGDisplayBounds union of all active displays — correct CG coordinate space)

## Key Learnings (2026-05-12, continued)

14. **NSScreen.frame uses AppKit coordinates (origin bottom-left), but CGWarpMouseCursorPosition uses CG coordinates (origin top-left).** Using NSScreen for bounds then clamping warp positions produces wrong results on multi-monitor. Use `CGGetActiveDisplayList` + `CGDisplayBounds` which are already in CG coordinate space.

15. **CGWarpMouseCursorPosition doesn't generate mouseMoved events.** Apps that rely on mouseMoved (Dock magnification, hover states) won't react. Must explicitly post a `CGEvent(.mouseMoved)` after warping.

## Completed (2026-05-16) — feature/gesture-remapping branch

- **Gesture action remapping system:**
  - `KeyBinding.swift`: data model — keyCode + modifiers + isMediaKey + displayName
  - `GestureSlot` enum: 12 remappable slots (left hand holds + right hand swipes)
  - `GestureActionConfig.swift`: singleton config manager, UserDefaults persistence
  - `KeyRecorderView.swift`: NSEvent monitor captures regular keys, F1-F12, media keys (play/pause/next/prev)
  - Settings UI: Gestures tab shows all remappable slots with inline key recorder, per-slot revert button, "Reset All"
  - `fireGesture()` and `handleSwipe()` read from config instead of hardcoded switch
  - `InputDispatch.performMediaKey()`: NX_SYSDEFINED system event posting for media keys
  - Smart default detection: recording the same key as default doesn't store it (no false "modified" state)

- **Open palm (5 fingers) → Space key** gesture added (merged to master already in c13b453)

- **Countdown UX fixes:**
  - Dim orange border shows immediately when gesture is recognized (before countdown starts)
  - Countdown only starts after 15-frame grace period (no more jump from nothing → midway)
  - `leftGestureStartTime` captured as local value before async dispatch (was nil due to threading race)
  - Grace period stability tracking for left hand (stableFrames accumulate during grace)
  - Label shows during grace for speech (🎤), agent (🤖), and left hand gestures
  - `CountdownBorder` has three states: idle border → dim orange border (gesture detected) → filling orange border (countdown active)
  - `isSpeechMode` gated on `gestureCountdownStart == nil` (transcript section doesn't expand during countdown)

- **Agent listening fix:** `handsReleased()` now called in the no-hands path (`results.isEmpty`). Previously agent stayed in "Listening..." forever when both hands dropped with no speech.

- **`rightHandEntryFrames` increment moved before agent/speech grace checks.** Was after them — early returns during grace prevented the counter from incrementing, so grace never ended for both-fists and right-fist gestures.

- **Gesture label fixes:**
  - All labels show "L" or "R" to indicate which hand
  - 3-finger emoji corrected to 👌 (OK sign)
  - Swipe emoji corrected to 🖐 (open palm, not 👆)
  - Cancel gesture labeled "✕ Cross index fingers (hold)"
  - Delete labeled "🤙 R Thumb+pinky (hold)"
  - Duplicate number in finger labels removed ("1☝️ 1" → "☝️ 1")

### What Worked
- Single `CountdownBorder` view handles all gesture states — one fix applies globally
- Capturing timestamps as local values before `DispatchQueue.main.async` eliminates threading races
- Tracking stable frames during grace so countdown starts instantly after grace ends

### What Didn't Work
- Setting `gestureCountdownStart = Date()` inside async block — by the time it runs on main, ms have passed
- Reading `self?.leftGestureStartTime` from main thread async block — property set on background, read as nil
- Grace period `return` before `rightHandEntryFrames += 1` — counter never progressed

### Key Learnings

16. **Grace period early returns block downstream state updates.** Any counter increment or state reset placed AFTER a `return` during grace will never execute. Move shared counters before conditional grace returns.

17. **Threading race with timestamps:** `DispatchQueue.main.async { self?.foo }` reads `foo` later than when it was set on the background queue. Capture as `let val = foo` before the async block and pass `val` in the closure.

18. **SwiftUI view identity for reactive updates from non-observable singletons:** `GestureActionConfig.shared` is not `@Observable`. Use `.id(version)` modifier with a `@State var version: Int` bumped on every mutation to force re-render.

## Next Steps

- Test key recorder with media keys on external keyboard
- Two-finger directional hold (ML classifier)
- GitHub Release with pre-built .app binary
- Consider: per-app gesture profiles
