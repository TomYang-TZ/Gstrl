import AppKit
import SwiftUI

final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}

final class CalibrationWindowController {
    private var window: NSWindow?

    func show(mapper: PolynomialMapper, gazeTracker: GazeTracker, onComplete: @escaping () -> Void) {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        let engine = CalibrationEngine(screenSize: screenSize, mapper: mapper)
        let gazeCollector = GazeCollector()

        let calibrationView = CalibrationView(
            engine: engine,
            gazeCollector: gazeCollector,
            gazeTracker: gazeTracker,
            onComplete: { [weak self] in
                self?.dismiss()
                onComplete()
            }
        )

        let win = KeyableWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.level = .screenSaver
        win.isOpaque = true
        win.backgroundColor = .black
        win.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        win.contentView = NSHostingView(rootView: calibrationView)
        win.onEscape = { [weak self] in
            DispatchQueue.main.async {
                self?.dismiss()
            }
        }
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }

    func dismiss() {
        window?.close()
        window = nil
    }
}
