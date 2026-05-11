# Launch Posts

## Video recommendation

Record a 30-60s screencast: webcam feed in corner showing your hands, main screen showing the cursor/actions happening in real-time. Show this sequence:
1. Pinch to move cursor around
2. Pinch to click something
3. Draw a circle to screenshot
4. Swipe for arrow keys
5. Hold fist → dictate some text
6. Both fists → ask Claude a question → hear the response

Post as a short video on Reddit (dramatically higher engagement than text-only) and as the primary RedNote content.

---

## Reddit Posts

### r/macapps — Primary launch post

**Title:** I control my Mac with hand gestures through the webcam — no extra hardware

**Body:**

I code lying down a lot and got tired of reaching for the trackpad, so I built this.

Gstrl uses your Mac's built-in webcam to detect hand gestures and turns them into actual input:
- Pinch to move the cursor, click, drag
- Draw a circle in the air → screenshots that region
- Open hand swipe → arrow keys
- Hold a fist → speech-to-text (say "press enter", "command z", etc.)
- Hold both fists → talk to Claude, it speaks back

No Leap Motion, no depth sensor. Just the camera + Apple Vision framework running at 30fps. All on-device.

Also works for presenting, accessibility, or days when your wrists just need a break.

Open source, MIT. Give it a try: https://tomyang-tz.github.io/Gstrl

[video/gif]

---

### r/sideproject

**Title:** Gstrl — control your Mac with hand gestures through your webcam

**Body:**

Built this because I code from my couch and hate the trackpad dance. It watches your hands through the webcam and maps gestures to input.

A few things that were fun to figure out:
- Velocity-based swipe detection (not position threshold — you don't need to "reset" your hand)
- Exponential smoothing on cursor to kill jitter
- Escalating delete — hold the shaka and it goes char → word → line → select all
- Draw a circle while pinching → screenshots that region
- Hold both fists → ask Claude a question → get a spoken answer

Turns out it's useful beyond the couch — presenting, RSI days, accessibility.

All on-device, Apple Vision + SFSpeechRecognizer. Open source.

https://tomyang-tz.github.io/Gstrl

---

### r/swift

**Title:** Built a full gesture control system for macOS using VNDetectHumanHandPoseRequest — some notes

**Body:**

Made an app that turns webcam hand gestures into system input (cursor, clicks, drags, scrolling, arrow keys, speech, AI agent). Some things I learned along the way:

- `VNDetectHumanHandPoseRequest` gives you 21 joints per hand per frame
- Pinch detection: thumb tip → index tip distance relative to palm center is way more robust than absolute distance (handles different hand sizes / distances from camera)
- Swipe detection: velocity-based, gated by open-hand pose first (otherwise everything triggers it)
- Cursor smoothing: exponential smoothing (0.7/0.3) + dead zone (0.002 normalized) + velocity gate
- Two-hand combos need priority routing — both-fists vs left-fist-right-pinch gets ambiguous frame-by-frame
- 30fps is plenty for gesture recognition; higher fps helps cursor feel but costs CPU

No ML model needed for core poses — finger joint geometry is enough. ~8% CPU on M1 at 30fps.

https://tomyang-tz.github.io/Gstrl

---

### r/ClaudeAI

**Title:** Hold both fists → talk to Claude → hear the answer. Built it into a gesture control app.

**Body:**

Made a macOS app (Gstrl) that does gesture control via webcam. The Claude part: hold both fists for 1s → speak your question → 3s silence → sends to Claude Code CLI → response spoken back via TTS.

It grabs context automatically — selected text or a screenshot you just took gets attached to the prompt. My most-used workflow: circle-gesture to screenshot something, both fists, "what's wrong with this?"

Multi-turn works — session stays alive until you dismiss the overlay. Under the hood it's `claude -p --output-format stream-json --verbose`, streaming thinking/tool_use/result into a Dynamic Island overlay.

The gesture control part is actually the main feature (cursor, clicking, scrolling, speech-to-text) but the Claude integration is what makes it feel like the future.

https://tomyang-tz.github.io/Gstrl

---

### r/accessibility

**Title:** Hands-free Mac control with webcam gestures + voice — open source, looking for feedback

**Body:**

Made an open-source macOS app (Gstrl) that lets you control your computer through hand gestures via webcam + voice commands. No special hardware — works with your MacBook's built-in camera, all on-device.

What you can do:
- Gestures for cursor, clicking, scrolling, arrow keys, drag-and-drop
- Voice commands: "press enter", "press tab", "command z", "control c", "shift left" for selection, etc.
- Mix both — move cursor with gestures, trigger actions with voice

Where it might help:
- Limited arm/hand mobility but can still do finger movements (pinch, open/close fist)
- RSI/carpal tunnel days — alternative input to rest your wrists
- Voice commands cover what gestures can't
- Open source (Swift) so gesture thresholds are tunable

Honest limitations:
- Need at least one hand visible to the webcam
- Needs decent lighting
- No switch-access style input — requires hand/finger movement
- macOS only (Apple Vision framework)

https://tomyang-tz.github.io/Gstrl

Would genuinely appreciate feedback on what would make this more useful.

---

### r/InteractionDesign (also cross-post to r/HCI)

**Title:** Designed a webcam gesture system for macOS — some interaction decisions that surprised me

**Body:**

Built a macOS app that maps hand gestures (webcam, Apple Vision, 30fps) to system input. Some design choices I landed on:

**Asymmetric hand roles:** Left = action (click, enter, escape), Right = navigation (cursor, swipe, scroll). Mirrors how we naturally split tasks between hands. Also makes recognition way less ambiguous.

**Escalating actions:** The delete gesture (shaka) starts with characters, after 1s escalates to words, then lines, then select-all. Hold longer = bigger scope. One gesture, variable power.

**Mode via posture:** Fist = speech mode. Both fists = AI agent. The gesture IS the mode switch — no button or keyword to enter/exit.

**Velocity not position:** Swipes trigger on velocity threshold with an open hand, not crossing a position boundary. You can swipe from anywhere without resetting.

**Combo disambiguation:** Both hands visible → is this "left fist + right pinch" (scroll) or two independent gestures? Priority routing frame-by-frame with debounce.

The biggest open problem: gesture discoverability. They're invisible until you know them. Curious how others would approach that.

https://tomyang-tz.github.io/Gstrl

---

## RedNote (小红书) Posts

### Post 1 — Main launch (视频笔记)

**标题:** 用手势操控 Mac 摄像头就行 不用额外硬件

**正文:**

写了个 macOS app 用自带摄像头识别手势控制电脑

捏合移动光标 画圈截图 挥手翻页 握拳语音输入 双拳跟 AI 对话

语音输入支持中文 可以直接用中文听写 语音指令用英语（say "press enter" "command z"）

手势和语音都在本地跑 不传数据（AI 对话走 Claude）

适合躺着写代码 演示 demo 手腕累了换个方式 或者单纯觉得好玩

感兴趣来试试：tomyang-tz.github.io/Gstrl

#手势控制 #macOS #开源项目 #效率工具 #程序员日常 #HCI #无障碍 #独立开发 #sideproject

---

### Post 2 — 技术向

**标题:** 普通 webcam 做手势识别 不用深度摄像头 附代码

**正文:**

分享下我这个手势控制 app 的技术方案

核心是 Apple Vision 的 VNDetectHumanHandPoseRequest
每帧 21 个手部关节点 30fps M1 上 CPU ~8% 不需要训练模型 纯几何就够

几个关键点：
1. 捏合检测 拇指到食指距离除以掌心半径 比绝对距离鲁棒得多
2. 光标平滑 指数滤波 + 死区 + 速度门限 三层去抖
3. 滑动检测 基于速度不是位置 不用"回到起点"
4. 双手组合 优先级路由 + 消抖 逐帧判断

比较有意思的设计：
- 左手动作（点击回车）右手导航（光标滑动）
- 删除手势 🤙 按住越久删越多 字符→词→行→全选
- 画圈截图 捏合画圆 识别闭合后截图

代码：tomyang-tz.github.io/Gstrl

#手势识别 #ComputerVision #Apple #Swift开发 #macOS开发 #开源 #HCI #独立开发者

---

### Post 3 — 生活方式向

**标题:** 往椅子里一摊 用手势 vibe code 吧

**正文:**

事情是这样的 躺着写代码触控板根本够不到 蓝牙鼠标滑得到处都是 每次都是姿势越来越抽象最后被迫坐起来

所以我写了个 macOS app 摄像头识别手势 + 语音识别 直接隔空操作

🤏 捏合移动 = 控制光标
🤏 快捏一下 = 点击
✊ 握拳 = 语音输入
✊✊ 双拳 = AI 对话

语音输入支持中文 语音指令用英语（"press enter" "command z" "click"）

直接葛优躺 键盘往腿上一搁 开始 vibe coding

手势和语音都在本地跑 不传数据

感兴趣的话来试试：tomyang-tz.github.io/Gstrl

#躺平工作 #牛马生活 #脆皮牛马 #打工人 #vibe coding #程序员 #效率 #macOS #远程办公 #居家办公 #手势控制 #躺平开发
