import SwiftUI

struct DynamicIslandView: View {
    @Bindable var appState: AppState
    var onToggle: () -> Void
    var onTap: (() -> Void)?
    var onAgentDismiss: (() -> Void)?
    var onStopSpeaking: (() -> Void)?
    var onAgentTerminate: (() -> Void)?
    @State private var isPressed = false
    @State private var responseExpanded = true

    private var isExpanded: Bool {
        hasTranscript || !appState.agentResponse.isEmpty || appState.agentActive || isSpeechMode
    }

    private var isSpeechMode: Bool {
        !appState.gestureLabel.isEmpty &&
        (appState.gestureLabel.contains("🎤") || appState.gestureLabel.contains("⌨️")) &&
        appState.gestureCountdownStart == nil
    }

    private var isAgentMode: Bool {
        appState.agentActive || !appState.agentResponse.isEmpty
    }

    private var hasTranscript: Bool {
        (isAgentMode && !appState.agentTranscript.isEmpty) ||
        (isSpeechMode && !appState.speechTranscript.isEmpty) ||
        !appState.agentThinking.isEmpty ||
        !appState.agentCurrentAction.isEmpty
    }

    private var activeTranscript: String {
        if !appState.agentCurrentAction.isEmpty {
            return "⚡ " + appState.agentCurrentAction
        }
        if !appState.agentThinking.isEmpty {
            return "💭 " + appState.agentThinking
        }
        let full = isAgentMode ? appState.agentTranscript : appState.speechTranscript
        let words = full.split(separator: " ", omittingEmptySubsequences: true)
        if words.count > 8 {
            return "..." + words.suffix(8).joined(separator: " ")
        }
        return full
    }


    var body: some View {
        VStack(spacing: 8) {
            islandContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func screenshotThumbnail(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 240, maxHeight: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
            .padding(4)
    }

    private enum IslandMode {
        case compact, transcript, response
    }

    private var islandMode: IslandMode {
        if !appState.agentResponse.isEmpty { return .response }
        if hasTranscript { return .transcript }
        return .compact
    }

    private var islandContent: some View {
        VStack(spacing: 0) {
            compactContent
                .frame(height: 32)
                .contentShape(Rectangle())
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeOut(duration: 0.1), value: isPressed)
                .onTapGesture { onTap?() }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in isPressed = true }
                        .onEnded { _ in isPressed = false }
                )

            if isExpanded {
                expandedSection
                    .frame(maxWidth: .infinity, maxHeight: 150)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let preview = appState.screenshotPreview {
                screenshotThumbnail(preview)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 280)
        .modifier(IslandGlassModifier(cornerRadius: 14))
        .background(GeometryReader { geo in
            Color.clear.onChange(of: geo.size.height) { _, newHeight in
                appState.islandHeight = newHeight
            }
            .onAppear { appState.islandHeight = geo.size.height }
        })
        .animation(.easeOut(duration: 0.2), value: isExpanded)
        .animation(.easeOut(duration: 0.2), value: responseExpanded)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: appState.screenshotPreview != nil)
    }

    private var expandedSection: some View {
        Group {
            if islandMode == .response {
                agentResponseBody
            } else {
                transcriptBody
            }
        }
    }

    private var transcriptBody: some View {
        HStack(spacing: 6) {
            if !appState.agentCurrentAction.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: toolIcon(appState.agentCurrentAction))
                        .font(.system(size: 9))
                        .foregroundStyle(.purple)
                    Text(appState.agentCurrentAction)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.purple)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if !appState.agentThinking.isEmpty {
                Text("💭 \(appState.agentThinking)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let full = isAgentMode ? appState.agentTranscript : appState.speechTranscript
                let display: String = {
                    let words = full.split(separator: " ", omittingEmptySubsequences: true)
                    if words.count > 8 { return "..." + words.suffix(8).joined(separator: " ") }
                    return full
                }()
                Text(display)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if appState.agentSelectedLines > 0 && isAgentMode {
                selectionBadge
            }

            if isAgentProcessing {
                Button { onAgentTerminate?() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                        .padding(5)
                        .background(Circle().fill(.red.opacity(0.12)))
                }
                .buttonStyle(PointerButtonStyle())
            } else if isAgentMode {
                sendCircle
            } else {
                AnimatedWaveform()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var agentResponseBody: some View {
        HStack(alignment: .top, spacing: 6) {
            ScrollView {
                Text(appState.agentResponse)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(responseExpanded ? nil : 1)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            HStack(spacing: 6) {
                if appState.agentSpeaking {
                    Button { onStopSpeaking?() } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.red)
                            .padding(4)
                            .background(Circle().fill(.red.opacity(0.12)))
                    }
                    .buttonStyle(PointerButtonStyle())
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { responseExpanded.toggle() }
                } label: {
                    Image(systemName: responseExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PointerButtonStyle())
                Button {
                    onStopSpeaking?()
                    appState.agentResponse = ""
                    appState.gestureLabel = ""
                    appState.agentActive = false
                    responseExpanded = true
                    onAgentDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PointerButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var compactContent: some View {
        HStack {
            handIndicator(
                detected: appState.leftHandDetected,
                symbol: "hand.raised.fill",
                color: .orange
            )

            Spacer()

            StatusButton(
                isEnabled: appState.isEnabled,
                gestureLabel: appState.gestureLabel,
                countdownStart: appState.gestureCountdownStart,
                countdownDuration: appState.gestureCountdownDuration,
                isCountdown: appState.progressMode == .countdown,
                onToggle: onToggle
            )

            Spacer()

            handIndicator(
                detected: appState.rightHandDetected,
                symbol: "hand.raised.fill",
                color: .cyan
            )
            .scaleEffect(x: -1, y: 1)
        }
        .padding(.horizontal, 20)
    }

    // Kept for backward compat but no longer used directly
    private var statusIndicator: some View {
        let lineColor: Color = appState.isEnabled ? .green : .white.opacity(0.7)

        return Button { onToggle() } label: {
            Text(appState.isEnabled ? "ON" : "OFF")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(lineColor)
                .tracking(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(lineColor, lineWidth: 1.5)
                }
        }
        .buttonStyle(PointerButtonStyle())
    }

    private func handIndicator(detected: Bool, symbol: String, color: Color) -> some View {
        Image(systemName: detected ? symbol : "hand.raised")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(detected ? color : .primary.opacity(0.35))
    }

    private var expandedContent: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                handIndicator(detected: appState.leftHandDetected, symbol: "hand.raised.fill", color: .orange)

                Text(appState.gestureLabel)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .animation(nil, value: appState.gestureLabel)

                if isAgentMode {
                    sendCircle
                } else {
                    handIndicator(detected: appState.rightHandDetected, symbol: "hand.raised.fill", color: .cyan)
                        .scaleEffect(x: -1, y: 1)
                }
            }
            .padding(.horizontal, 20)

            if appState.gestureCountdownStart != nil && !isAgentMode {
                progressBar
            }
        }
    }

    private var progressBar: some View {
        ProgressBarView(
            start: appState.gestureCountdownStart,
            duration: appState.gestureCountdownDuration,
            isCountdown: appState.progressMode == .countdown
        )
    }

    private var isAgentProcessing: Bool {
        appState.gestureLabel.contains("Thinking") || !appState.agentThinking.isEmpty || !appState.agentCurrentAction.isEmpty
    }


    private func toolIcon(_ action: String) -> String {
        let tool = action.split(separator: " ").first.map(String.init) ?? action
        switch tool {
        case "Read": return "doc.text"
        case "Write", "Edit": return "pencil"
        case "Bash": return "terminal"
        case "Grep", "Glob": return "magnifyingglass"
        case "WebSearch", "WebFetch": return "globe"
        default: return "wrench"
        }
    }

    @State private var thinkingAngle: Double = 0

    private var sendCircle: some View {
        let isThinking = appState.gestureLabel.contains("Thinking")
        let ringColor: Color = isThinking ? .cyan : .orange

        return TimelineView(.animation(paused: isThinking || appState.agentSilenceStart == nil)) { timeline in
            let progress: Double = {
                guard !isThinking, let start = appState.agentSilenceStart else { return 0 }
                return max(0, 1.0 - timeline.date.timeIntervalSince(start) / 3.0)
            }()

            ZStack {
                Circle()
                    .strokeBorder(ringColor.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 18, height: 18)

                if isThinking {
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .frame(width: 18, height: 18)
                        .rotationEffect(.degrees(thinkingAngle))
                        .onAppear {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                thinkingAngle = 360
                            }
                        }
                        .onDisappear { thinkingAngle = 0 }
                } else if progress > 0 {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .frame(width: 18, height: 18)
                        .rotationEffect(.degrees(-90))
                }

                Image(systemName: isThinking ? "ellipsis" : "arrow.up")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(ringColor)
            }
        }
    }


    private var selectionBadge: some View {
        Group {
            if appState.agentSelectedLines > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 9))
                    Text("\(appState.agentSelectedLines) lines")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.cyan)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(.cyan.opacity(0.15)))
            }
        }
    }

}

struct StatusButton: View {
    let isEnabled: Bool
    let gestureLabel: String
    let countdownStart: Date?
    let countdownDuration: TimeInterval
    let isCountdown: Bool
    let onToggle: () -> Void

    private var displayText: String {
        if !gestureLabel.isEmpty { return gestureLabel }
        return isEnabled ? "ON" : "OFF"
    }

    private var borderColor: Color {
        if !gestureLabel.isEmpty { return .orange }
        return isEnabled ? .green : .white.opacity(0.7)
    }

    var body: some View {
        Button { onToggle() } label: {
            Text(displayText)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(borderColor)
                .tracking(gestureLabel.isEmpty ? 1 : 0)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .overlay {
                    CountdownBorder(
                        start: countdownStart,
                        duration: countdownDuration,
                        isCountdown: isCountdown,
                        idleColor: borderColor,
                        hasGesture: !gestureLabel.isEmpty
                    )
                }
        }
        .buttonStyle(PointerButtonStyle())
    }
}

struct CountdownBorder: View {
    let start: Date?
    let duration: TimeInterval
    let isCountdown: Bool
    let idleColor: Color
    let hasGesture: Bool

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            let progress: Double = {
                guard let s = start else { return 0 }
                let elapsed = timeline.date.timeIntervalSince(s)
                guard elapsed > 0, duration > 0 else { return 0 }
                return isCountdown ? min(1.0, elapsed / duration) : max(0, 1.0 - elapsed / duration)
            }()

            if progress > 0 {
                RoundedRectangle(cornerRadius: 3)
                    .trim(from: 0, to: progress)
                    .stroke(isCountdown ? Color.orange : Color.green, lineWidth: 1.5)
            } else if hasGesture {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1.5)
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(idleColor, lineWidth: 1.5)
            }
        }
    }
}

struct AnimatedWaveform: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    let height = 4.0 + 8.0 * abs(sin(t * 3 + Double(i) * 0.8))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.orange)
                        .frame(width: 2.5, height: height)
                }
            }
            .frame(width: 20, height: 16)
        }
    }
}

struct CompactProgressRing: View {
    let start: Date?
    let duration: TimeInterval
    let isCountdown: Bool

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            let progress: Double = {
                guard let s = start else { return 0 }
                let elapsed = timeline.date.timeIntervalSince(s)
                return isCountdown ? min(1.0, elapsed / duration) : max(0, 1.0 - elapsed / duration)
            }()

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isCountdown ? Color.orange : Color.green,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(-90))
                .opacity(progress > 0 ? 1 : 0)
        }
    }
}

struct ProgressBarView: View {
    let start: Date?
    let duration: TimeInterval
    let isCountdown: Bool

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            let progress: Double = {
                guard let s = start else { return 0 }
                let elapsed = timeline.date.timeIntervalSince(s)
                return isCountdown ? min(1.0, elapsed / duration) : max(0, 1.0 - elapsed / duration)
            }()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(isCountdown ? Color.orange : Color.green)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(width: 200, height: 3)
        }
    }
}

struct IslandGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

struct LiquidGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .clipShape(Capsule())
        }
    }
}

struct PointerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
    }
}
