import SwiftUI

struct CalibrationView: View {
    @ObservedObject var engine: CalibrationEngine
    @ObservedObject var gazeCollector: GazeCollector
    let gazeTracker: GazeTracker
    let onComplete: () -> Void

    @State private var timer: Timer?
    @State private var samplesThisPoint: Int = 0
    @State private var rawGazePosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var dwellTime: Double = 0
    private let requiredDwell: Double = 3.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if engine.isComplete {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("Calibration Complete")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onComplete()
                        }
                    }
                } else if let target = engine.currentTarget {
                    // Instructions
                    VStack {
                        Text("Look at the red dot (\(engine.currentPointIndex + 1)/9)")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.top, 40)

                        Text("Hold gaze steady — \(String(format: "%.1f", max(0, requiredDwell - dwellTime)))s remaining")
                            .font(.headline)
                            .foregroundColor(dwellTime > 0 ? .green : .gray)
                            .padding(.top, 8)

                        Text("Samples: \(samplesThisPoint)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 4)

                        Spacer()
                    }

                    // Progress ring around target
                    Circle()
                        .trim(from: 0, to: min(1.0, dwellTime / requiredDwell))
                        .stroke(Color.green, lineWidth: 4)
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .position(target)
                        .animation(.linear(duration: 0.1), value: dwellTime)

                    // Target red dot
                    Circle()
                        .fill(Color.red)
                        .frame(width: 24, height: 24)
                        .position(target)

                    // Gaze indicator — cyan dot
                    Circle()
                        .fill(Color.cyan.opacity(0.8))
                        .frame(width: 18, height: 18)
                        .position(
                            x: rawGazePosition.x * geo.size.width,
                            y: (1.0 - rawGazePosition.y) * geo.size.height
                        )

                    // Eye emoji label
                    Text("👁")
                        .font(.system(size: 10))
                        .position(
                            x: rawGazePosition.x * geo.size.width,
                            y: (1.0 - rawGazePosition.y) * geo.size.height - 14
                        )
                }
            }
        }
        .onAppear {
            startGazeCollection()
            startDwellTimer()
        }
        .onDisappear {
            stopGazeCollection()
            timer?.invalidate()
        }
    }

    private func startGazeCollection() {
        // Poll the gaze tracker socket at 30fps
        Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if let result = gazeTracker.getLatestGaze() {
                    gazeCollector.add(result.rawGazeVector)
                    self.samplesThisPoint += 1
                    self.rawGazePosition = result.rawGazeVector
                }
            }
        }
    }

    private func stopGazeCollection() {
        // Socket-based — no camera to stop here
    }

    private func startDwellTimer() {
        dwellTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                guard samplesThisPoint > 0 else { return }
                guard let target = engine.currentTarget else { return }

                // Only count dwell time if gaze dot is near the red target
                let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
                let gazeScreenX = rawGazePosition.x * screenSize.width
                let gazeScreenY = (1.0 - rawGazePosition.y) * screenSize.height

                let dist = hypot(gazeScreenX - target.x, gazeScreenY - target.y)
                let threshold: CGFloat = 200 // pixels — must be within 200px of target

                if dist < threshold {
                    dwellTime += 0.1
                } else {
                    // Reset if gaze wanders away
                    dwellTime = max(0, dwellTime - 0.05)
                }

                if dwellTime >= requiredDwell {
                    advancePoint()
                }
            }
        }
    }

    private func advancePoint() {
        guard let avg = gazeCollector.average() else {
            // No data — reset and wait
            dwellTime = 0
            return
        }

        engine.recordGazeVector(avg)
        gazeCollector.reset()
        samplesThisPoint = 0
        dwellTime = 0

        if engine.isComplete {
            timer?.invalidate()
            stopGazeCollection()
        }
    }
}
