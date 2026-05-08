import SwiftUI

struct DynamicIslandView: View {
    @Bindable var appState: AppState

    private var isExpanded: Bool {
        !appState.gestureLabel.isEmpty
    }

    private var shape: NotchShape {
        isExpanded ? .opened : .closed
    }

    private var contentSize: CGSize {
        isExpanded
            ? CGSize(width: 260, height: 56)
            : CGSize(width: 140, height: 34)
    }

    var body: some View {
        Color.black
            .frame(width: contentSize.width, height: contentSize.height)
            .overlay(alignment: .center) {
                compactContent
                    .opacity(isExpanded ? 0 : 1)
            }
            .overlay(alignment: .center) {
                expandedContent
                    .opacity(isExpanded ? 1 : 0)
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.45, dampingFraction: 0.88), value: isExpanded)
    }

    private var compactContent: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(appState.leftHandDetected ? .orange : .white.opacity(0.12))
                .frame(width: 9, height: 9)

            if appState.handsCount > 0 {
                Text("●")
                    .font(.system(size: 5))
                    .foregroundStyle(.green.opacity(0.9))
            } else {
                Text("○")
                    .font(.system(size: 5))
                    .foregroundStyle(.white.opacity(0.2))
            }

            Circle()
                .fill(appState.rightHandDetected ? .blue : .white.opacity(0.12))
                .frame(width: 9, height: 9)
        }
    }

    private var expandedContent: some View {
        VStack(spacing: 5) {
            HStack(spacing: 10) {
                Circle()
                    .fill(appState.leftHandDetected ? .orange : .white.opacity(0.12))
                    .frame(width: 9, height: 9)

                Text(appState.gestureLabel)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)

                Circle()
                    .fill(appState.rightHandDetected ? .blue : .white.opacity(0.12))
                    .frame(width: 9, height: 9)
            }
            .padding(.horizontal, 16)

            if appState.gestureProgress > 0 {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.white.opacity(0.12))
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(.white.opacity(0.85))
                                .frame(width: geo.size.width * appState.gestureProgress)
                                .animation(.linear(duration: 0.1), value: appState.gestureProgress)
                        }
                }
                .frame(width: 180, height: 3)
            }
        }
    }
}

struct NotchShape: Shape, Animatable {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    static let closed = NotchShape(topRadius: 6, bottomRadius: 17)
    static let opened = NotchShape(topRadius: 14, bottomRadius: 28)

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let tr = min(topRadius, min(w, h) / 2)
        let br = min(bottomRadius, min(w, h) / 2)

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: tr, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: tr),
            control: CGPoint(x: 0, y: 0)
        )

        path.addLine(to: CGPoint(x: 0, y: h - br))
        path.addQuadCurve(
            to: CGPoint(x: br, y: h),
            control: CGPoint(x: 0, y: h)
        )

        path.addLine(to: CGPoint(x: w - br, y: h))
        path.addQuadCurve(
            to: CGPoint(x: w, y: h - br),
            control: CGPoint(x: w, y: h)
        )

        path.addLine(to: CGPoint(x: w, y: tr))
        path.addQuadCurve(
            to: CGPoint(x: w - tr, y: 0),
            control: CGPoint(x: w, y: 0)
        )

        path.closeSubpath()
        return path
    }
}
