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

        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)

        // Fixed mapping based on observed ranges:
        //   H: 0.56 (looking right on screen) → 0.75 (looking left on screen)
        //   V: 0.55 (looking up) → 0.80 (looking down)
        // Map to full screen with these as the endpoints
        let hMin: CGFloat = 0.55
        let hMax: CGFloat = 0.76
        let vMin: CGFloat = 0.50
        let vMax: CGFloat = 0.80

        // Normalize within range
        var normX = (rawGaze.x - hMin) / (hMax - hMin)
        var normY = (rawGaze.y - vMin) / (vMax - vMin)

        // Clamp
        normX = max(0.0, min(1.0, normX))
        normY = max(0.0, min(1.0, normY))

        let screenPoint = smoothingFilter.apply(CGPoint(
            x: normX * screenSize.width,
            y: normY * screenSize.height
        ))

        gazeOverlay.moveTo(screenPoint)

        if trackingState == .tracking || trackingState == .pinching {
            cursorController.update(state: trackingState, gazePoint: screenPoint)
        } else {
            cursorController.update(state: .inactive, gazePoint: .zero)
        }
    }
}
