<p align="center">
  <img src="Sources/Gstrl/Resources/AppIcon.iconset/icon_256x256.png" width="128" alt="Gstrl icon">
</p>

# Gstrl


**Gstrl** adds gesture, voice, and AI agent control to macOS. **Pinch to move cursor. Swipe for arrows. Hold fists to talk to Claude. Circle to screenshot.** All on-device via Apple Vision + SFSpeechRecognizer.

For when you're lying back, vibe coding, presenting, or just tired of gripping a mouse or using trackpad all day.

## Install

```bash
git clone https://github.com/TomYang-TZ/Gstrl.git
cd Gstrl
make install   # builds + installs to /Applications
```

```bash
make run       # build + launch
make restart   # stop + rebuild + launch
make stop      # kill it
```

App auto-opens permission pages on first launch (Camera, Accessibility, Screen Recording, Speech).

## Gestures & Voice

### Left Hand (action hand)

| Gesture | Action |
|---------|--------|
| 👌 Quick pinch (thumb + index) | Click |
| 👌 Long pinch + right hand present (hold 1s) | Right click |
| ☝️ Hold 1–3 fingers | Type 1, 2, or 3 |
| ✊ Hold fist | Enter |
| 🤙 Six (hold) | Escape |

### Right Hand (navigation hand)

| Gesture | Action |
|---------|--------|
| 👌 Pinch + move | Move cursor |
| 👌 Pinch + draw circle | Screenshot circled area → clipboard |
| ✊ Fist (hold, only hand) | Speech-to-text |
| 🖐 Open hand + swipe ↑↓←→ | Arrow keys |
| 🤙 Six (hold) | Delete (chars → words → lines → all) |

### Both Hands (combos)

| Gesture | Action |
|---------|--------|
| ✊✊ Both fists (hold 1s) | AI Agent (ask Claude a question) |
| L pinch + R pinch + move | Drag and drop |
| L pinch + R fist + move | Scroll (velocity-based, accelerates over time) |
| L open + R swipe ←→ | Tab / Shift+Tab |
| Both 🤙 six | Delete lines (escalates to select all) |
| ✕ Both hands held together | Ctrl+C ×2 (cancel/kill) |

### Voice Commands (during speech mode)

Supports **English, 中文, 粵語, and Spanish** — switch in Settings. Say "prefix + keyword" to trigger actions instead of typing:

#### English:

| Command | Action |
|---------|--------|
| click / right click | Click / Right click |
| press up/down/left/right | Arrow keys |
| press enter / tab / escape / delete | Key press |
| command [key] | ⌘+key (e.g. command z, command c) |
| control [key] | ⌃+key (e.g. control c) |
| shift + direction | Select text |
| option + direction | Jump by word |
| command shift [key] | ⌘⇧+key (e.g. command shift z = redo) |

#### 中文:

| 指令 | 动作 |
|------|------|
| 回车 / 确认 / 换行 | Enter |
| 删除 | Backspace |
| 取消 | Escape |
| 点击 / 右键 / 右击 | Click / Right click |
| 撤销 / 复制 / 粘贴 / 全选 / 全删 / 保存 | ⌘Z / ⌘C / ⌘V / ⌘A / ⌘⌫ / ⌘S |
| 按上 / 按下 / 按左 / 按右 | Arrow keys |

#### Español:

| Comando | Acción |
|---------|--------|
| pulsa arriba/abajo/izquierda/derecha | Arrow keys |
| pulsa intro / borrar / eliminar | Enter / Delete |
| clic / clic derecho | Click / Right click |
| comando + key | ⌘+key |
| control + key | ⌃+key |

### AI Agent (both fists) — requires [Claude Code CLI](https://claude.ai/claude-code)

Hold both fists for 1 second to activate the AI agent. Speak your question — after 3 seconds of silence, it sends to Claude Code and reads the response aloud.

- Captures selected text as context (Cmd+C before sending)
- Multi-turn conversations within same session
- Dismiss the response overlay (X) to start a new session
- Full chat history in the app's Agent tab

### "Pro" tips

- **Keyboard + Gesture** — Hold a modifier key while gesturing (not voice). Shift + swipe = select text. Cmd + swipe = jump words.
- **Screenshot → AI** — Circle-capture a region, then hold both fists to ask Claude about what's on screen.
- **Select → AI** — Drag to highlight text (pinch + hold + move), then hold both fists. Claude sees your selection as context.

## Dynamic Island

A floating glass overlay at the top of your screen (macOS 26+ Liquid Glass):
- Expands downward to show live transcription, agent thinking/actions, or response text
- Inline controls: terminate agent, collapse response, dismiss

## Requirements

- macOS 14+ (Liquid Glass needs macOS 26+, falls back gracefully)
- Webcam
- Swift 5.9+

### Optional

- [Claude Code CLI](https://claude.ai/claude-code) — enables the AI agent feature (both-fists hold). Everything else works without it.

## How It Works

Gstrl uses Apple's Vision framework (`VNDetectHumanHandPoseRequest`) to detect hand landmarks from your webcam feed. A gesture classifier maps hand poses to actions — pinch detection via palm center tracking, velocity-based swipe recognition (requires open hand pose), and two-hand combo tracking. Scroll uses velocity-based joystick control. Speech mode uses Apple's `SFSpeechRecognizer` for on-device dictation and voice commands. The AI agent pipes questions to Claude Code CLI and reads responses aloud via macOS system voice. 30fps default, configurable up to 120fps. All gesture/speech processing runs locally with zero network dependency (agent mode requires internet for Claude).

## License

MIT
