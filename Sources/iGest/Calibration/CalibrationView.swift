import SwiftUI
import Vision

struct CalibrationView: View {
    @ObservedObject var engine: CalibrationEngine
    @ObservedObject var gazeCollector: GazeCollector
    let gazeTracker: GazeTracker
    let cameraManager: CameraManager
    let onComplete: () -> Void

    @State private var timer: Timer?

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
                    Button("Done") { onComplete() }
                        .buttonStyle(.borderedProminent)
                }
            } else if let target = engine.currentTarget {
                VStack {
                    Text("Look at the red dot (\(engine.currentPointIndex + 1)/9)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 40)
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
                }
            }
        }
        cameraManager.start()
    }

    private func stopGazeCollection() {
        cameraManager.stop()
    }

    private func startFixationTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if let avgGaze = gazeCollector.average() {
                    engine.recordGazeVector(avgGaze)
                }
                gazeCollector.reset()

                if engine.isComplete {
                    timer?.invalidate()
                    stopGazeCollection()
                }
            }
        }
    }
}
