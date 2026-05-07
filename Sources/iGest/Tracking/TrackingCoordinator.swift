import Vision
import Foundation

final class TrackingCoordinator {
    private let cameraManager = CameraManager()
    private let handTracker = HandTracker()
    private let gazeTracker: GazeTracker
    private let cursorController: CursorController
    private let smoothingFilter: SmoothingFilter
    private let appState: AppState

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
    }

    func stop() {
        cameraManager.stop()
        cursorController.emergencyKill()
        cursorController.reenable()
        smoothingFilter.reset()
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
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        let faceRequest = VNDetectFaceLandmarksRequest()
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 1

        do {
            try handler.perform([faceRequest, handRequest])
        } catch {
            return
        }

        let handObservation = handRequest.results?.first
        let handLandmarks = handObservation.flatMap { handTracker.processObservation($0) }
        let trackingState = handTracker.classify(handLandmarks: handLandmarks)

        DispatchQueue.main.async { [weak self] in
            self?.appState.trackingState = trackingState
        }

        guard trackingState == .tracking || trackingState == .pinching else {
            cursorController.update(state: .inactive, gazePoint: .zero)
            smoothingFilter.reset()
            return
        }

        var gazePoint: CGPoint = .zero
        if let faceObservation = faceRequest.results?.first {
            if let result = gazeTracker.processFrame(pixelBuffer, faceObservation: faceObservation) {
                gazePoint = smoothingFilter.apply(result.screenPoint)
            }
        }

        cursorController.update(state: trackingState, gazePoint: gazePoint)
    }
}
