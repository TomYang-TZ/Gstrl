import SwiftUI

struct MainStatusView: View {
    @Bindable var appState: AppState
    var onToggle: () -> Void
    var onFPSChanged: ((Int32) -> Void)?
    var onStopSpeaking: (() -> Void)?
    @State private var selectedTab: Tab = .settings

    enum Tab: String, CaseIterable {
        case settings = "Settings"
        case history = "Agent"
        case gestures = "Gestures"
        case voice = "Voice"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Icon toggle + status
            VStack(spacing: 6) {
                AppIconView(isEnabled: appState.isEnabled)
                    .frame(width: 64, height: 64)
                    .contentShape(Circle())
                    .onTapGesture { onToggle() }
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }

                if appState.isEnabled {
                    Text(appState.debugInfo.isEmpty ? "No hands" : appState.debugInfo)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tap to enable")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                if appState.agentSpeaking {
                    Button {
                        onStopSpeaking?()
                    } label: {
                        Text("Stop")
                            .font(.system(size: 10))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)

            // Tab bar
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background {
                                if selectedTab == tab {
                                    Capsule().fill(.quaternary)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()

            // Tab content
            switch selectedTab {
            case .settings:
                settingsContent
            case .history:
                AgentHistoryContent(appState: appState)
                    .frame(height: 280)
            case .gestures:
                gesturesContent
                    .frame(height: 280)
            case .voice:
                voiceCommandsContent
                    .frame(height: 280)
            }
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Settings Tab

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FPS").font(.caption)
                Spacer()
                Picker("", selection: $appState.fps) {
                    ForEach(AppState.FPS.allCases, id: \.self) { fps in
                        Text(fps.rawValue).tag(fps)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: appState.fps) { _, newValue in
                    onFPSChanged?(newValue.timescale)
                }
            }

            HStack {
                Text("Cursor").font(.caption)
                Slider(value: $appState.cursorSensitivity, in: 1.0...10.0, step: 0.5)
                Text(String(format: "%.1fx", appState.cursorSensitivity))
                    .font(.system(.caption2, design: .monospaced))
                    .frame(width: 30)
            }

            HStack {
                Text("Scroll").font(.caption)
                Slider(value: $appState.scrollSensitivity, in: 0.5...3.0, step: 0.25)
                Text(String(format: "%.1fx", appState.scrollSensitivity))
                    .font(.system(.caption2, design: .monospaced))
                    .frame(width: 30)
            }

            Toggle("Natural scroll", isOn: $appState.naturalScroll)
                .font(.caption)

            HStack {
                Text("Speech").font(.caption)
                Spacer()
                Picker("", selection: $appState.speechLanguage) {
                    ForEach(AppState.SpeechLanguage.allCases, id: \.self) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: appState.speechLanguage) { _, _ in
                    onFPSChanged?(0)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Gestures Tab

    private var gesturesContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    sectionHeader("LEFT HAND", color: .orange)
                    gestureRow("👌 Pinch", "Click")
                    gestureRow("☝️ 1-3 fingers (hold)", "Press 1-3")
                    gestureRow("✊ Fist (hold)", "Enter")
                    gestureRow("🤙 Six (hold)", "Escape")
                }

                Divider().padding(.vertical, 4)

                Group {
                    sectionHeader("RIGHT HAND", color: .blue)
                    gestureRow("👌 Pinch + move", "Drag cursor")
                    gestureRow("✊ Fist (hold, no left)", "Speech-to-text")
                    gestureRow("🤙 Six (hold)", "Delete (repeats)")
                    gestureRow("👆 Swipe ↑↓←→", "Arrow keys")
                }

                Divider().padding(.vertical, 4)

                Group {
                    sectionHeader("COMBO", color: .purple)
                    gestureRow("✊✊ Both fists (hold)", "AI Agent")
                    gestureRow("👌+✊ L pinch + R fist", "Scroll")
                    gestureRow("🤙🤙 Both six (hold)", "Delete lines → select all")
                    gestureRow("🖐+← Open left + swipe", "Tab / Shift+Tab")
                }
            }
            .padding(16)
        }
    }

    // MARK: - Voice Commands Tab

    private var voiceCommandsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("COMMANDS", color: .green)
                voiceRow("click / right click / double click", "👆 Click variants")
                voiceRow("press + key", "Press key")
                voiceRow("command + key", "⌘ + key")
                voiceRow("control + key", "⌃ + key")
                voiceRow("shift + direction", "Select text")
                voiceRow("option + direction", "Jump by word")
                voiceRow("command shift + key", "⌘⇧ + key")
            }
            .padding(16)
        }
    }

    private func voiceRow(_ command: String, _ action: String) -> some View {
        HStack {
            Text(command)
                .font(.system(.caption, design: .monospaced))
            Spacer()
            Text(action)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func sectionHeader(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
    }

    private func gestureRow(_ gesture: String, _ action: String) -> some View {
        HStack {
            Text(gesture)
                .font(.system(.caption, design: .rounded))
            Spacer()
            Text(action)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Animated App Icon

struct AppIconView: View {
    let isEnabled: Bool

    @State private var frozenOuter: Double = 0
    @State private var frozenMid: Double = 0
    @State private var frozenInner: Double = 0
    @State private var enabledSince: TimeInterval = 0

    var body: some View {
        TimelineView(.animation(paused: !isEnabled)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let elapsed = isEnabled ? now - enabledSince : 0

            Canvas { ctx, size in
                let s = min(size.width, size.height)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                let orange = Color(red: 1.0, green: 0.58, blue: 0.0)
                let cyan = Color(red: 0.2, green: 0.68, blue: 0.9)

                // Outer ring: radius 0.285s, lineWidth 0.012s, rotation +30deg (CG) = -30deg SwiftUI
                let outerR = s * 0.285
                let outerLw = s * 0.024
                let outerRot = frozenOuter + elapsed * 45
                // Orange arc: CG angles 75°→165° (90° arc)
                drawArc(ctx: &ctx, center: center, radius: outerR, lineWidth: outerLw,
                        startDeg: 75, endDeg: 165, rotation: outerRot, color: orange, opacity: 0.85)
                // Cyan arc: CG angles -15°→75° (90° arc)
                drawArc(ctx: &ctx, center: center, radius: outerR, lineWidth: outerLw,
                        startDeg: -15, endDeg: 75, rotation: outerRot, color: cyan, opacity: 0.85)

                // Mid ring: radius 0.205s, lineWidth 0.008s, rotation -60deg (CG) = +60deg SwiftUI
                let midR = s * 0.205
                let midLw = s * 0.016
                let midRot = frozenMid - elapsed * 30
                // Orange arc: CG -135°→-45°
                drawArc(ctx: &ctx, center: center, radius: midR, lineWidth: midLw,
                        startDeg: -135, endDeg: -45, rotation: midRot, color: orange, opacity: 0.6)
                // Cyan arc: CG 135°→225°
                drawArc(ctx: &ctx, center: center, radius: midR, lineWidth: midLw,
                        startDeg: 135, endDeg: 225, rotation: midRot, color: cyan, opacity: 0.6)

                // Inner ring: radius 0.13s, lineWidth 0.005s, rotation +15deg (CG) = -15deg SwiftUI
                let innerR = s * 0.13
                let innerLw = s * 0.01
                let innerRot = frozenInner + elapsed * 60
                // Orange arc: CG 75°→165°
                drawArc(ctx: &ctx, center: center, radius: innerR, lineWidth: innerLw,
                        startDeg: 75, endDeg: 165, rotation: innerRot, color: orange, opacity: 0.45)
                // Cyan arc: CG -15°→75°
                drawArc(ctx: &ctx, center: center, radius: innerR, lineWidth: innerLw,
                        startDeg: -15, endDeg: 75, rotation: innerRot, color: cyan, opacity: 0.45)

                // Fingertips
                let tipW = s * 0.07
                let tipH = s * 0.1
                let gap = s * 0.012

                // Left (orange) — tilts right (CG rotate -15° = clockwise on screen)
                let lx = center.x - gap - tipW * 0.55
                drawFingertip(ctx: &ctx, center: CGPoint(x: lx, y: center.y),
                              width: tipW, height: tipH, angle: .degrees(15), color: orange)

                // Right (cyan) — tilts left (CG rotate +15° = counter-clockwise on screen)
                let rx = center.x + gap + tipW * 0.55
                drawFingertip(ctx: &ctx, center: CGPoint(x: rx, y: center.y),
                              width: tipW, height: tipH, angle: .degrees(-15), color: cyan)
            }
        }
        .onChange(of: isEnabled) { _, enabled in
            if enabled {
                enabledSince = Date.timeIntervalSinceReferenceDate
            } else {
                let elapsed = Date.timeIntervalSinceReferenceDate - enabledSince
                frozenOuter += elapsed * 45
                frozenMid -= elapsed * 30
                frozenInner += elapsed * 60
            }
        }
    }

    private func drawArc(ctx: inout GraphicsContext, center: CGPoint, radius: CGFloat,
                         lineWidth: CGFloat, startDeg: Double, endDeg: Double,
                         rotation: Double, color: Color, opacity: Double) {
        // CG uses counter-clockwise from right (3 o'clock). Canvas uses same coordinate system.
        let start = Angle.degrees(-startDeg + rotation)
        let end = Angle.degrees(-endDeg + rotation)
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
        ctx.stroke(path, with: .color(color.opacity(opacity)),
                   style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
    }

    private func drawFingertip(ctx: inout GraphicsContext, center: CGPoint,
                               width: CGFloat, height: CGFloat, angle: Angle, color: Color) {
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let cornerRadius = width / 2
        var path = Path(roundedRect: rect, cornerRadius: cornerRadius)
        let transform = CGAffineTransform.identity
            .translatedBy(x: center.x, y: center.y)
            .rotated(by: CGFloat(angle.radians))
        path = path.applying(transform)
        ctx.fill(path, with: .color(color))
    }
}

// MARK: - Agent History Tab (with session tabs)

struct AgentHistoryContent: View {
    @Bindable var appState: AppState
    @State private var selectedSessionIndex: Int = 0

    private var sessions: [(id: String, entries: [AppState.AgentEntry])] {
        var grouped: [(id: String, entries: [AppState.AgentEntry])] = []
        var currentId: String?
        for entry in appState.agentHistory {
            if entry.sessionId == currentId, !grouped.isEmpty {
                grouped[grouped.count - 1].entries.append(entry)
            } else {
                grouped.append((id: entry.sessionId, entries: [entry]))
                currentId = entry.sessionId
            }
        }
        return grouped
    }

    var body: some View {
        VStack(spacing: 0) {
            if appState.agentHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("Hold both fists to ask a question")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Session tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(sessions.enumerated()), id: \.offset) { idx, session in
                            sessionTab(idx, count: session.entries.count)
                        }

                        Spacer()

                        Button {
                            appState.agentHistory.removeAll()
                            selectedSessionIndex = 0
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                                .foregroundStyle(.red.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.vertical, 8)

                Divider()

                // Chat messages for selected session
                if selectedSessionIndex < sessions.count {
                    let entries = sessions[selectedSessionIndex].entries
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                                let isLast = idx == entries.count - 1
                                CollapsibleChatEntry(entry: entry, expandedByDefault: isLast)
                            }
                        }
                        .padding(10)
                    }
                }
            }
        }
    }

    private func sessionTab(_ index: Int, count: Int) -> some View {
        let isSelected = selectedSessionIndex == index
        return Button {
            selectedSessionIndex = index
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? .cyan : .secondary.opacity(0.3))
                    .frame(width: 5, height: 5)
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                Text("(\(count))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(isSelected ? .cyan.opacity(0.12) : .clear)
            }
            .overlay {
                Capsule().strokeBorder(isSelected ? Color.cyan.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func chatBubble(_ entry: AppState.AgentEntry, showActions: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.query)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                    if let path = entry.screenshotPath,
                       let img = NSImage(contentsOfFile: path) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 13))
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.response)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .lineSpacing(2)

                    HStack(spacing: 6) {
                        if entry.turns > 0 {
                            metaTag("↻ \(entry.turns)")
                        }
                        if entry.durationMs > 0 {
                            metaTag("⏱ \(formatDuration(entry.durationMs))")
                        }
                        if entry.costUSD > 0 {
                            metaTag("$\(String(format: "%.3f", entry.costUSD))")
                        }
                        Spacer()
                        Text(timeString(entry.timestamp))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.3)))
    }

    private func metaTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(.quaternary))
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    private func formatDuration(_ ms: Int) -> String {
        if ms < 1000 { return "\(ms)ms" }
        return String(format: "%.1fs", Double(ms) / 1000.0)
    }
}

struct CollapsibleChatEntry: View {
    let entry: AppState.AgentEntry
    let expandedByDefault: Bool
    @State private var isExpanded: Bool = false
    @State private var showingSelectedText: Bool = false

    private func showSelectedText(_ text: String) {
        showingSelectedText = true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text(entry.query)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(isExpanded ? nil : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if let path = entry.screenshotPath,
                       let img = NSImage(contentsOfFile: path) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(.leading, 26)
                    }

                    if !entry.actions.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(entry.actions) { action in
                                HStack(spacing: 4) {
                                    Image(systemName: toolIcon(action.tool))
                                        .font(.system(size: 8))
                                        .foregroundStyle(.purple)
                                        .frame(width: 12)
                                    Text(action.tool)
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.purple)
                                    if !action.summary.isEmpty {
                                        Text(action.summary)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.purple.opacity(0.05)))
                        .padding(.horizontal, 10)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "cpu")
                            .font(.system(size: 11))
                            .foregroundStyle(.cyan)
                        Text(entry.response)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 10)

                    HStack(spacing: 6) {
                        if entry.selectedLines > 0 {
                            if let text = entry.selectedText {
                                Button { showSelectedText(text) } label: {
                                    metaTag("📄 \(entry.selectedLines) lines")
                                }
                                .buttonStyle(.plain)
                            } else {
                                metaTag("📄 \(entry.selectedLines) lines")
                            }
                        }
                        if entry.turns > 0 {
                            metaTag("↻ \(entry.turns)")
                        }
                        if entry.durationMs > 0 {
                            metaTag("⏱ \(formatDuration(entry.durationMs))")
                        }
                        if entry.costUSD > 0 {
                            metaTag("$\(String(format: "%.3f", entry.costUSD))")
                        }
                        if !entry.actions.isEmpty {
                            metaTag("⚡ \(entry.actions.count) actions")
                        }
                        Spacer()
                        Text(timeString(entry.timestamp))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
                .transition(.opacity)
            }
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.3)))
        .onAppear { isExpanded = expandedByDefault }
        .popover(isPresented: $showingSelectedText) {
            if let text = entry.selectedText {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Context (\(entry.selectedLines) lines)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                    Divider()

                    ScrollView(.vertical, showsIndicators: true) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(text)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .lineSpacing(2)
                                .padding(12)
                        }
                    }
                }
                .frame(width: 340, height: 240)
            }
        }
    }

    private func toolIcon(_ tool: String) -> String {
        switch tool {
        case "Read": return "doc.text"
        case "Write", "Edit": return "pencil"
        case "Bash": return "terminal"
        case "Grep", "Glob": return "magnifyingglass"
        case "WebSearch", "WebFetch": return "globe"
        default: return "wrench"
        }
    }

    private func metaTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(.quaternary))
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    private func formatDuration(_ ms: Int) -> String {
        if ms < 1000 { return "\(ms)ms" }
        return String(format: "%.1fs", Double(ms) / 1000.0)
    }
}
