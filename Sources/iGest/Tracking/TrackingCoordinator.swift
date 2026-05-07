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
        // Check accessibility permission — required for CGEvent click posting
        if !AXIsProcessTrusted() {
            NSLog("iGest: Accessibility NOT granted — requesting...")
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        } else {
            NSLog("iGest: Accessibility granted ✓")
        }
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

        // Get current cursor position for clicking
        // CGEvent uses global display coordinates (top-left origin of primary display)
        guard let event = CGEvent(source: nil) else { return }
        let cgPoint = event.location

        // Post click events at current cursor position
        let prevState = cursorController.currentState
        switch trackingState {
        case .pinching:
            if prevState != .pinching {
                NSLog("iGest: PINCH DETECTED → clicking at (\(cgPoint.x), \(cgPoint.y))")
                NSSound.beep()
            }
            cursorController.update(state: .pinching, gazePoint: cgPoint)
        case .tracking:
            if prevState != .tracking {
                NSLog("iGest: Hand open → tracking")
            }
            cursorController.update(state: .tracking, gazePoint: cgPoint)
        case .inactive:
            cursorController.update(state: .inactive, gazePoint: cgPoint)
        }
    }
}
