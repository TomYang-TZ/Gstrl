import SwiftUI

struct DynamicIslandView: View {
    @Bindable var appState: AppState
    var onToggle: () -> Void

    private var isExpanded: Bool {
        !appState.gestureLabel.isEmpty
    }

    private var contentSize: CGSize {
        isExpanded
            ? CGSize(width: 280, height: 60)
            : CGSize(width: 160, height: 36)
    }

    var body: some View {
        ZStack {
            islandBackground
            compactContent
                .opacity(isExpanded ? 0 : 1)
            expandedContent
                .opacity(isExpanded ? 1 : 0)
        }
        .frame(width: contentSize.width, height: contentSize.height)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isExpanded)
        .onTapGesture { onToggle() }
    }

    private var islandBackground: some View {
        ZStack {
            // Deep black base matching Apple's Dynamic Island
            Color.black

            // Subtle inner glow at edges when active
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(appState.isEnabled ? 0.12 : 0.06),
                            .white.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        }
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
        }
        .padding(.horizontal, 16)
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(appState.isEnabled
                    ? Color.green
                    : Color.white.opacity(0.25))
                .frame(width: 6, height: 6)
                .shadow(color: appState.isEnabled ? .green.opacity(0.6) : .clear, radius: 4)

            if appState.isEnabled {
                Text("ON")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isEnabled)
    }

    private func handIndicator(detected: Bool, symbol: String, color: Color) -> some View {
        Image(systemName: detected ? symbol : "hand.raised")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(detected ? color : .white.opacity(0.2))
            .shadow(color: detected ? color.opacity(0.5) : .clear, radius: 3)
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
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())

                handIndicator(
                    detected: appState.rightHandDetected,
                    symbol: "hand.raised.fill",
                    color: .cyan
                )
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
