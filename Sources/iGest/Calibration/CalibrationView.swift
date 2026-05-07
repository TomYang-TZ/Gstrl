import SwiftUI
import Vision

struct CalibrationView: View {
    @ObservedObject var engine: CalibrationEngine
    @ObservedObject var gazeCollector: GazeCollector
    let gazeTracker: GazeTracker
    let cameraManager: CameraManager
    let onComplete: () -> Void

    @State private var timer: Timer?
    @State private var samplesThisPoint: Int = 0

    var body: some View {
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
                    Text("Press any key or click to dismiss")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onComplete()
                    }
                }
            } else if let target = engine.currentTarget {
                VStack {
                    Text("Look at the red dot (\(engine.currentPointIndex + 1)/9)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 40)

                    Text("Samples: \(samplesThisPoint)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)

                    Spacer()
                }

                Circle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                    .position(target)
                    .animation(.easeInOut(duration: 0.3), value: target)
            }
        }
        .onAppear {
            startGazeCollection()
            startFixationTimer()
        }
        .onDisappear {
            stopGazeCollection()
            timer?.invalidate()
        }
    }

    private func startGazeCollection() {
        cameraManager.onFrame = { [gazeCollector, gazeTracker] pixelBuffer in
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            let faceRequest = VNDetectFaceLandmarksRequest()
            try? handler.perform([faceRequest])

            if let faceObs = faceRequest.results?.first,
               let result = gazeTracker.processFrame(pixelBuffer, faceObservation: faceObs) {
                DispatchQueue.main.async {
                    gazeCollector.add(result.rawGazeVector)
                    self.samplesThisPoint += 1
                }
            }
        }
        cameraManager.start()
    }

    private func stopGazeCollection() {
        cameraManager.stop()
    }

    private func startFixationTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            DispatchQueue.main.async {
                advancePoint()
            }
        }
    }

    private func advancePoint() {
        let gazeVector: CGPoint
        if let avg = gazeCollector.average() {
            gazeVector = avg
        } else {
            // Fallback: use the normalized screen position of the target as a stand-in
            let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
            if let target = engine.currentTarget {
                gazeVector = CGPoint(
                    x: target.x / screenSize.width,
                    y: target.y / screenSize.height
                )
            } else {
                gazeVector = CGPoint(x: 0.5, y: 0.5)
            }
        }

        engine.recordGazeVector(gazeVector)
        gazeCollector.reset()
        samplesThisPoint = 0

        if engine.isComplete {
            timer?.invalidate()
            stopGazeCollection()
        }
    }
}
