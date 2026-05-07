import Foundation
import Vision
import AppKit

final class TrackingCoordinator {
    private let cameraManager = CameraManager()
    private let handTracker = HandTracker()
    private let cursorController: CursorController
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        self.cursorController = CursorController()

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
    }

    func emergencyKill() {
        stop()
        DispatchQueue.main.async { [weak self] in
            self?.appState.isEnabled = false
        }
    }

    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 1

        do {
            try handler.perform([handRequest])
        } catch {
            return
        }

        let handObservation = handRequest.results?.first
        let handLandmarks = handObservation.flatMap { handTracker.processObservation($0) }
        let trackingState = handTracker.classify(handLandmarks: handLandmarks)

        DispatchQueue.main.async { [weak self] in
            self?.appState.trackingState = trackingState
        }

        // Get current cursor position (wherever Head Pointer has moved it)
        let cursorPos = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        // Convert from NSEvent (bottom-left) to CGEvent (top-left)
        let cgPoint = CGPoint(x: cursorPos.x, y: screenHeight - cursorPos.y)

        // Post click events at current cursor position
        switch trackingState {
        case .pinching:
            cursorController.update(state: .pinching, gazePoint: cgPoint)
        case .tracking:
            cursorController.update(state: .tracking, gazePoint: cgPoint)
        case .inactive:
            cursorController.update(state: .inactive, gazePoint: cgPoint)
        }
    }
}
