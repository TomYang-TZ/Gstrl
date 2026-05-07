import AppKit
import SwiftUI

final class CalibrationWindowController {
    private var window: NSWindow?

    func show(mapper: PolynomialMapper, gazeTracker: GazeTracker, cameraManager: CameraManager, onComplete: @escaping () -> Void) {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        let engine = CalibrationEngine(screenSize: screenSize, mapper: mapper)
        let gazeCollector = GazeCollector()

        let calibrationView = CalibrationView(
            engine: engine,
            gazeCollector: gazeCollector,
            gazeTracker: gazeTracker,
            cameraManager: cameraManager,
            onComplete: { [weak self] in
                self?.dismiss()
                onComplete()
            }
        )

        let win = NSWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .screenSaver
        win.isOpaque = true
        win.backgroundColor = .black
        win.contentView = NSHostingView(rootView: calibrationView)
        win.makeKeyAndOrderFront(nil)
        window = win
    }

    func dismiss() {
        window?.close()
        window = nil
    }
}
