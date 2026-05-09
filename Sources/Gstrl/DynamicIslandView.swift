import SwiftUI

struct DynamicIslandView: View {
    @Bindable var appState: AppState
    var onToggle: () -> Void
    var onTap: (() -> Void)?
    @State private var isPressed = false

    private var isExpanded: Bool {
        !appState.gestureLabel.isEmpty
    }

    private var isSpeechMode: Bool {
        appState.gestureLabel.contains("🎤") || appState.gestureLabel.contains("⌨️")
    }

    private var contentSize: CGSize {
        if isSpeechMode {
            return CGSize(width: 320, height: 60)
        }
        return isExpanded
            ? CGSize(width: 280, height: 60)
            : CGSize(width: 160, height: 36)
    }

    var body: some View {
        VStack(spacing: 8) {
            islandContent
                .contentShape(Capsule())
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in isPressed = true }
                        .onEnded { _ in
                            isPressed = false
                            onTap?()
                        }
                )

            if let preview = appState.screenshotPreview {
                screenshotThumbnail(preview)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.screenshotPreview != nil)
    }

    private func screenshotThumbnail(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 240, maxHeight: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .modifier(LiquidGlassModifier())
            .padding(4)
    }

    private var islandContent: some View {
        ZStack {
            compactContent
                .frame(width: 160, height: 36)
                .opacity(isExpanded ? 0 : 1)
                .allowsHitTesting(!isExpanded)
            expandedContent
                .frame(width: isSpeechMode ? 320 : 280, height: 60)
                .opacity(isExpanded ? 1 : 0)
                .allowsHitTesting(isExpanded)
        }
        .frame(width: contentSize.width, height: contentSize.height)
        .clipped()
        .modifier(LiquidGlassModifier())
    }

    private var compactContent: some View {
        HStack(spacing: 12) {
            handIndicator(
                detected: appState.leftHandDetected,
                symbol: "hand.raised.fill",
                color: .orange
            )

            statusIndicator

            handIndicator(
                detected: appState.rightHandDetected,
                symbol: "hand.raised.fill",
                color: .cyan
            )
            .scaleEffect(x: -1, y: 1)
        }
        .padding(.horizontal, 16)
    }

    @State private var toggleHovered = false

    private var statusIndicator: some View {
        let lineColor: Color = appState.isEnabled ? .green : .white.opacity(0.7)

        return Button { onToggle() } label: {
            Text(appState.isEnabled ? "ON" : "OFF")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(lineColor)
                .tracking(toggleHovered ? 3 : 1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay {
                    Capsule()
                        .strokeBorder(lineColor, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .onHover { toggleHovered = $0 }
        .animation(.easeInOut(duration: 0.3), value: toggleHovered)
        .animation(.easeInOut(duration: 0.2), value: appState.isEnabled)
    }

    private func handIndicator(detected: Bool, symbol: String, color: Color) -> some View {
        Image(systemName: detected ? symbol : "hand.raised")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(detected ? color : .primary.opacity(0.35))
            .animation(.easeInOut(duration: 0.2), value: detected)
    }

    private var expandedContent: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                handIndicator(
                    detected: appState.leftHandDetected,
                    symbol: "hand.raised.fill",
                    color: .orange
                )

                Text(appState.gestureLabel)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())

                handIndicator(
                    detected: appState.rightHandDetected,
                    symbol: "hand.raised.fill",
                    color: .cyan
                )
                .scaleEffect(x: -1, y: 1)
            }
            .padding(.horizontal, 20)

            if appState.gestureProgress > 0 {
                progressBar
            }
        }
    }

    private var progressBar: some View {
        let isCountdown = appState.progressMode == .countdown
        let barColor: Color = isCountdown ? .orange : .green

        return GeometryReader { geo in
            ZStack(alignment: isCountdown ? .leading : .trailing) {
                Capsule()
                    .fill(.white.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [barColor.opacity(0.7), barColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * appState.gestureProgress)
                    .shadow(color: barColor.opacity(0.4), radius: 2)
                    .animation(.linear(duration: 0.1), value: appState.gestureProgress)
            }
        }
        .frame(width: 200, height: 3)
    }
}

struct LiquidGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .environment(\.colorScheme, .dark)
                .background {
                    Capsule().fill(.ultraThinMaterial)
                }
                .clipShape(Capsule())
        }
    }
}

