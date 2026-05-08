# Gstrl 🤌

> Augment your Mac with hand gestures — use alongside your keyboard and mouse, not instead of them.

**Gstrl** adds a gesture layer on top of your normal workflow. **Pinch and drag to move your cursor.** Swipe for arrows, circle to screenshot, speak to type or execute commands. Powered by real-time hand tracking via Apple's Vision framework. Your webcam becomes an extra input channel.

This isn't about replacing your keyboard and mouse. It's about having **another way to interact** when your hands are busy, far from your desk, or when a gesture is simply faster than a click.

**Use cases:** quick screenshots by circling content, swiping through pages one-handed, navigating slides during presentations, RSI relief by alternating input methods, accessibility, or hands-free control from across the room.

## Gestures & Voice

### Left Hand (action hand)

| Gesture | Action |
|---------|--------|
| 👌 Quick pinch (thumb + index) | Click |
| 👌 Long pinch (hold 1s) | Right click |
| ☝️ Hold 1–3 fingers | Type 1, 2, or 3 |
| ✊ Hold fist | Enter |
| 🤙 Six (hold) | Escape |

### Right Hand (navigation hand)

| Gesture | Action |
|---------|--------|
| 👌 Pinch + move | Move cursor |
| 👌 Pinch + draw circle | Screenshot circled area → clipboard |
| 🖐 Open hand + swipe ↑↓←→ | Arrow keys |
| 🤙 Six (hold) | Delete (chars → words → lines → all) |

### Both Hands (combos)

| Gesture | Action |
|---------|--------|
| L pinch + R pinch + move | Drag and drop |
| L pinch + R fist + move | Scroll (velocity-based, accelerates over time) |
| Both fists | Speech-to-text |
| L open + R swipe ←→ | Tab / Shift+Tab |
| Both 🤙 six | Delete lines (escalates to select all) |
| ✕ Cross index fingers | Ctrl+C ×2 (cancel/kill) |


### Voice Commands (during speech mode)

While speech-to-text is active, say "press" + keyword to execute actions instead of typing:

| Command | Action |
|---------|--------|
| press down/up/left/right | Arrow keys |
| press enter / press tab | Enter / Tab |
| press delete / press escape | Backspace / Escape |
| command tab / command z / command c / command v | Cmd+Tab / Undo / Copy / Paste |

## Dynamic Island

A floating pill at the top of your screen with Apple Liquid Glass styling (macOS 26+):
- SF Symbol hand indicators (orange = left, cyan = right)
- Current gesture label and progress bar
- Screenshot preview thumbnail on circle capture

Always visible, never steals focus.

## Install

```bash
git clone https://github.com/TomYang-TZ/Gstrl.git
cd Gstrl
make install   # builds and copies to /Applications
```

Then launch from Applications, or:

```bash
make run       # build + launch
make restart   # stop + build + launch
make stop      # kill running instance
```

Grant Camera, Microphone, Accessibility, Screen Recording, and Speech Recognition permissions when prompted (app opens the settings pages automatically on first launch).

## Requirements

- macOS 14+ (Liquid Glass requires macOS 26+, falls back to frosted material on older versions)
- Webcam
- Swift 5.9+

## How It Works

Gstrl uses Apple's Vision framework (`VNDetectHumanHandPoseRequest`) to detect hand landmarks at 60fps from your webcam feed. A gesture classifier maps hand poses to actions — pinch detection via palm center tracking, displacement-based swipe recognition (requires open hand pose), and two-hand combo tracking. Scroll uses velocity-based joystick control. All processing runs locally on-device with zero network dependency.

## License

MIT
