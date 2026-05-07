import Vision
import Foundation

final class TrackingCoordinator {
    private let cameraManager = CameraManager()
    private let handTracker = HandTracker()
    private let gazeTracker: GazeTracker
    private let cursorController: CursorController
    private let smoothingFilter: SmoothingFilter
    private let appState: AppState
    private let gazeOverlay = GazeOverlay()
    private var frameCount = 0

    init(appState: AppState, mapper: PolynomialMapper) {
        self.appState = appState
        self.gazeTracker = GazeTracker(mapper: mapper)
        self.cursorController = CursorController()
        self.smoothingFilter = SmoothingFilter(alpha: appState.sensitivity.alpha)

        cameraManager.onFrame = { [weak self] pixelBuffer in
            self?.processFrame(pixelBuffer)
        }
    }

    func start() {
        cameraManager.start()
        DispatchQueue.main.async { [weak self] in
            self?.gazeOverlay.show()
        }
    }

    func stop() {
        cameraManager.stop()
        cursorController.emergencyKill()
        cursorController.reenable()
        smoothingFilter.reset()
        DispatchQueue.main.async { [weak self] in
            self?.gazeOverlay.hide()
        }
    }

    func emergencyKill() {
        stop()
        DispatchQueue.main.async { [weak self] in
            self?.appState.isEnabled = false
        }
    }

    func updateSensitivity() {
        smoothingFilter.alpha = appState.sensitivity.alpha
    }

    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        frameCount += 1
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        let faceRequest = VNDetectFaceLandmarksRequest()
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 1

        do {
            try handler.perform([faceRequest, handRequest])
        } catch {
            if frameCount % 30 == 0 { NSLog("iGest: Vision perform failed: \(error)") }
            return
        }

        // Debug: log detection results every 30 frames (~1 second)
        if frameCount % 30 == 0 {
            let faceCount = faceRequest.results?.count ?? 0
            let handCount = handRequest.results?.count ?? 0
            NSLog("iGest: frame \(frameCount) — faces: \(faceCount), hands: \(handCount)")
        }

        let handObservation = handRequest.results?.first
        let handLandmarks = handObservation.flatMap { handTracker.processObservation($0) }
        let trackingState = handTracker.classify(handLandmarks: handLandmarks)

        if frameCount % 30 == 0 {
            if let landmarks = handLandmarks {
                let pinchDist = hypot(landmarks.thumbTip.x - landmarks.indexTip.x,
                                     landmarks.thumbTip.y - landmarks.indexTip.y)
                NSLog("iGest: hand detected — pinchDist: \(String(format: "%.3f", pinchDist)), confidence: \(landmarks.confidence), state: \(trackingState)")
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.appState.trackingState = trackingState
        }

        // Always try to get gaze point for the overlay (even when inactive)
        var gazePoint: CGPoint = .zero
        if let faceObservation = faceRequest.results?.first {
            if let result = gazeTracker.processFrame(pixelBuffer, faceObservation: faceObservation) {
                gazePoint = smoothingFilter.apply(result.screenPoint)
            }
        }

        // Move the overlay dot to show where gaze is pointing
        if gazePoint != .zero {
            DispatchQueue.main.async { [weak self] in
                self?.gazeOverlay.moveTo(gazePoint)
            }
        }

        // Only move actual cursor when hand is active
        guard trackingState == .tracking || trackingState == .pinching else {
            cursorController.update(state: .inactive, gazePoint: .zero)
            return
        }

        cursorController.update(state: trackingState, gazePoint: gazePoint)
    }
}
