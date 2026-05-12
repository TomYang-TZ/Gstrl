import AppKit
import ImageIO

final class WhipOverlay {
    private var panel: NSPanel?
    private var imageView: NSImageView?
    private var isVisible = false
    private var cursorPosition: CGPoint = .zero
    private var frames: [NSImage] = []
    private var frameDurations: [TimeInterval] = []
    private var currentFrame: Int = 0
    private var timer: Timer?
    private var positionTimer: Timer?

    private let displaySize: CGFloat = 40
    private var trackingFPS: Double = 60

    init() {
        loadGifFrames()
        setupPanel()
    }

    private func loadGifFrames() {
        let bundleName = "Gstrl_Gstrl.bundle"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName)
        ]
        let resourceBundle = candidates.compactMap({ $0.flatMap { Bundle(url: $0) } }).first ?? Bundle.main
        guard let url = resourceBundle.url(forResource: "whip", withExtension: "gif"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }

        let count = CGImageSourceGetCount(source)
        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let keyed = chromaKey(cgImage)
            let size = NSSize(width: CGFloat(keyed.width), height: CGFloat(keyed.height))
            let nsImage = NSImage(cgImage: keyed, size: size)
            frames.append(nsImage)

            // Get frame duration
            var delay: TimeInterval = 0.05
            if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifProps = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                if let d = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double, d > 0 {
                    delay = d
                } else if let d = gifProps[kCGImagePropertyGIFDelayTime as String] as? Double, d > 0 {
                    delay = d
                }
            }
            frameDurations.append(delay)
        }
    }

    private func setupPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: displaySize, height: displaySize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle
        ]

        let iv = NSImageView(frame: NSRect(x: 0, y: 0, width: displaySize, height: displaySize))
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.wantsLayer = true
        iv.layer?.backgroundColor = .clear
        panel.contentView = iv

        self.panel = panel
        self.imageView = iv
    }

    func show() {
        guard !isVisible, !frames.isEmpty else { return }
        isVisible = true
        cursorPosition = CGEvent(source: nil)?.location ?? .zero
        currentFrame = 0
        imageView?.image = frames[0]
        positionPanel()
        panel?.orderFrontRegardless()
        startAnimation()
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        stopAnimation()
        panel?.orderOut(nil)
    }

    func updateCursor(_ pos: CGPoint) {
        cursorPosition = pos
    }

    private func positionPanel() {
        guard let panel else { return }
        let pos = NSEvent.mouseLocation
        let x = pos.x - displaySize / 2
        let y = pos.y + 4
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func updateFPS(_ fps: Int32) {
        trackingFPS = Double(fps)
        guard isVisible else { return }
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / trackingFPS, repeats: true) { [weak self] _ in
            self?.positionPanel()
        }
    }

    private func startAnimation() {
        scheduleNextFrame()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / trackingFPS, repeats: true) { [weak self] _ in
            self?.positionPanel()
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
        positionTimer?.invalidate()
        positionTimer = nil
    }

    private func scheduleNextFrame() {
        guard isVisible, !frames.isEmpty else { return }
        let delay = frameDurations[currentFrame]
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.advanceFrame()
        }
    }

    private func advanceFrame() {
        guard isVisible else { return }
        currentFrame = (currentFrame + 1) % frames.count
        imageView?.image = frames[currentFrame]
        scheduleNextFrame()
    }

    private func chromaKey(_ image: CGImage) -> CGImage {
        let w = image.width
        let h = image.height
        let bytesPerPixel = 4
        let bytesPerRow = w * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: h * bytesPerRow)

        guard let context = CGContext(
            data: &pixelData,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let r = CGFloat(pixelData[i]) / 255.0
            let g = CGFloat(pixelData[i + 1]) / 255.0
            let b = CGFloat(pixelData[i + 2]) / 255.0

            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let delta = maxC - minC

            var hue: CGFloat = 0
            let sat: CGFloat = maxC > 0 ? delta / maxC : 0
            let bri: CGFloat = maxC

            if delta > 0 {
                if maxC == r {
                    hue = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
                } else if maxC == g {
                    hue = 60 * (((b - r) / delta) + 2)
                } else {
                    hue = 60 * (((r - g) / delta) + 4)
                }
                if hue < 0 { hue += 360 }
            }

            // Blue/cyan sky (hue 170-250)
            let isBlueSky = hue >= 170 && hue <= 250 && sat > 0.12 && bri > 0.35

            // White/light gray (clouds)
            let isLight = sat < 0.12 && bri > 0.7

            if isBlueSky || isLight {
                pixelData[i] = 0
                pixelData[i + 1] = 0
                pixelData[i + 2] = 0
                pixelData[i + 3] = 0
            }
        }

        guard let result = context.makeImage() else { return image }
        return result
    }

    deinit {
        stopAnimation()
    }
}
