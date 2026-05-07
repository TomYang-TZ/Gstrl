import AppKit

final class GazeOverlay {
    private var window: NSWindow?
    private var dotView: NSView?

    func show() {
        let dot = NSView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.red.withAlphaComponent(0.6).cgColor
        dot.layer?.cornerRadius = 12

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
        dotView = dot
    }

    func moveTo(_ point: CGPoint) {
        guard let window else { return }
        // Convert from top-left origin (CGEvent) to bottom-left origin (NSWindow)
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        let flipped = NSPoint(x: point.x - 12, y: screenHeight - point.y - 12)
        window.setFrameOrigin(flipped)
    }

    func hide() {
        window?.close()
        window = nil
    }
}
