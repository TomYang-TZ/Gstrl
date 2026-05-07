import AppKit

final class GazeOverlay {
    private var window: NSWindow?

    deinit {
        hide()
    }

    func show() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.show() }
            return
        }
        guard window == nil else { return }

        let dot = NSView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.systemCyan.withAlphaComponent(0.7).cgColor
        dot.layer?.cornerRadius = 12
        dot.layer?.borderWidth = 2
        dot.layer?.borderColor = NSColor.white.withAlphaComponent(0.8).cgColor

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 24, height: 24),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .floating
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.contentView = dot
        win.orderFront(nil)

        window = win
    }

    func moveTo(_ point: CGPoint) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.moveTo(point) }
            return
        }
        guard let window else { return }
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        let flipped = NSPoint(x: point.x - 12, y: screenHeight - point.y - 12)
        window.setFrameOrigin(flipped)
    }

    func hide() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.hide() }
            return
        }
        window?.orderOut(nil)
        window = nil
    }
}
