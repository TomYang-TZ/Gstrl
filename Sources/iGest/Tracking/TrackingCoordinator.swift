import Foundation
import AppKit

final class TrackingCoordinator {
    private let gazeTracker: GazeTracker
    private let cursorController: CursorController
    private let smoothingFilter: SmoothingFilter
    private let appState: AppState
    private let gazeOverlay = GazeOverlay()
    private var pollTimer: Timer?

    init(appState: AppState, mapper: PolynomialMapper) {
        self.appState = appState
        self.gazeTracker = GazeTracker(mapper: mapper)
        self.cursorController = CursorController()
        self.smoothingFilter = SmoothingFilter(alpha: appState.sensitivity.alpha)
    }

    func start() {
        DispatchQueue.main.async { [weak self] in
            self?.gazeOverlay.show()
            self?.startPolling()
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
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

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        let trackingState = gazeTracker.latestHandState
        appState.trackingState = trackingState

        let rawGaze = gazeTracker.latestGaze
        // Skip (0.5, 0.5) = no detection
        guard rawGaze.x != 0.5 || rawGaze.y != 0.5 else { return }
        // Skip vertical outliers
        guard rawGaze.y < 0.95 else { return }

        // Map raw gaze ratios directly to screen pixels
        // Raw gaze from GazeTracking: x and y are 0-1 ratios
        // Use MacBook built-in display (1512 x 982 logical)
        let screenW: CGFloat = 1512
        let screenH: CGFloat = 982

        // Fixed mapping: stretch observed gaze range to full screen
        let hMin: CGFloat = 0.55
        let hMax: CGFloat = 0.76
        let vMin: CGFloat = 0.50
        let vMax: CGFloat = 0.80

        var normX = (rawGaze.x - hMin) / (hMax - hMin)
        var normY = (rawGaze.y - vMin) / (vMax - vMin)

        normX = max(0.0, min(1.0, normX))
        normY = max(0.0, min(1.0, normY))

        // Screen pixel position (top-left origin for CGEvent)
        let screenPoint = smoothingFilter.apply(CGPoint(
            x: normX * screenW,
            y: normY * screenH
        ))

        gazeOverlay.moveTo(screenPoint)

        if trackingState == .tracking || trackingState == .pinching {
            cursorController.update(state: trackingState, gazePoint: screenPoint)
        } else {
            cursorController.update(state: .inactive, gazePoint: .zero)
        }
    }
}
