#!/usr/bin/env swift

import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outputDir = "Sources/Gstrl/Resources/AppIcon.iconset"

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

func renderIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let cornerRadius = s * 0.223
    let center = CGPoint(x: s / 2, y: s / 2)

    // Background: pure white with very subtle warmth
    let bgPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s), xRadius: cornerRadius, yRadius: cornerRadius)
    ctx.saveGState()
    bgPath.addClip()
    ctx.setFillColor(NSColor(red: 0.995, green: 0.995, blue: 0.99, alpha: 1.0).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

    // Subtle gradient overlay
    let bgColors = [
        NSColor(white: 1.0, alpha: 0.3).cgColor,
        NSColor(white: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

    // === ARCS — matching the CSS border approach ===
    // CSS uses border-color on specific sides + rotation to create partial circles
    // I'll draw arc segments to match

    let orange = NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
    let cyan = NSColor(red: 0.2, green: 0.68, blue: 0.9, alpha: 1.0)

    // Outer arc: 65% of icon size, rotated -30deg
    // CSS: border-top = orange, border-right = cyan
    // After -30deg rotation: orange appears top-left, cyan appears top-right
    let outerRadius = s * 0.325
    let outerWidth = s * 0.012

    ctx.setLineWidth(outerWidth)
    ctx.setLineCap(.round)

    // The CSS border trick with rotation -30deg means:
    // top border (orange) spans from -30deg to 60deg (relative to normal top)
    // right border (cyan) spans from 60deg to 150deg
    // In CG coordinate system (0 = right, counter-clockwise positive):
    // After rotating the whole thing by -30 degrees:

    // Orange arc segment (top portion after rotation)
    ctx.setStrokeColor(orange.withAlphaComponent(0.85).cgColor)
    ctx.addArc(center: center, radius: outerRadius, startAngle: .pi * 0.33, endAngle: .pi * 0.83, clockwise: false)
    ctx.strokePath()

    // Cyan arc segment (right portion after rotation)
    ctx.setStrokeColor(cyan.withAlphaComponent(0.85).cgColor)
    ctx.addArc(center: center, radius: outerRadius, startAngle: .pi * 1.33, endAngle: .pi * 1.83, clockwise: false)
    ctx.strokePath()

    // Mid arc: 47% of icon size, rotated 60deg
    // CSS: border-bottom = orange(0.6), border-left = cyan(0.6)
    let midRadius = s * 0.235
    let midWidth = s * 0.008

    ctx.setLineWidth(midWidth)

    // Orange segment (bottom after rotation)
    ctx.setStrokeColor(orange.withAlphaComponent(0.6).cgColor)
    ctx.addArc(center: center, radius: midRadius, startAngle: -.pi * 0.17, endAngle: .pi * 0.33, clockwise: false)
    ctx.strokePath()

    // Cyan segment (left after rotation)
    ctx.setStrokeColor(cyan.withAlphaComponent(0.6).cgColor)
    ctx.addArc(center: center, radius: midRadius, startAngle: .pi * 0.83, endAngle: .pi * 1.33, clockwise: false)
    ctx.strokePath()

    // Inner arc: 30% of icon size, rotated -15deg
    // CSS: border-top = orange(0.45), border-right = cyan(0.45)
    let innerRadius = s * 0.15
    let innerWidth = s * 0.006

    ctx.setLineWidth(innerWidth)

    ctx.setStrokeColor(orange.withAlphaComponent(0.45).cgColor)
    ctx.addArc(center: center, radius: innerRadius, startAngle: .pi * 0.42, endAngle: .pi * 0.92, clockwise: false)
    ctx.strokePath()

    ctx.setStrokeColor(cyan.withAlphaComponent(0.45).cgColor)
    ctx.addArc(center: center, radius: innerRadius, startAngle: .pi * 1.42, endAngle: .pi * 1.92, clockwise: false)
    ctx.strokePath()

    // === FINGERTIPS ===
    let tipWidth = s * 0.07
    let tipHeight = s * 0.1
    let gap = s * 0.012
    let tipCornerTop = tipWidth / 2
    let tipCornerBot = tipWidth * 0.36

    func drawFingertip(at pos: CGPoint, angle: CGFloat, color: NSColor) {
        ctx.saveGState()
        ctx.translateBy(x: pos.x, y: pos.y)
        ctx.rotate(by: angle)

        // Shadow/glow
        let glowColors = [
            color.withAlphaComponent(0.5).cgColor,
            color.withAlphaComponent(0.0).cgColor
        ] as CFArray
        let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0.0, 1.0])!
        ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 0, y: -tipHeight * 0.1), startRadius: 0, endCenter: CGPoint(x: 0, y: -tipHeight * 0.1), endRadius: tipHeight * 0.6, options: [])

        // Pill/teardrop shape using rounded rect
        let rect = CGRect(x: -tipWidth / 2, y: -tipHeight / 2, width: tipWidth, height: tipHeight)
        let path = CGPath(roundedRect: rect, cornerWidth: tipCornerTop, cornerHeight: tipCornerTop, transform: nil)
        ctx.setFillColor(color.cgColor)
        ctx.addPath(path)
        ctx.fillPath()

        ctx.restoreGState()
    }

    drawFingertip(
        at: CGPoint(x: center.x - gap - tipWidth * 0.55, y: center.y),
        angle: .pi * 15 / 180,
        color: orange
    )

    drawFingertip(
        at: CGPoint(x: center.x + gap + tipWidth * 0.55, y: center.y),
        angle: -.pi * 15 / 180,
        color: cyan
    )

    ctx.restoreGState()
    image.unlockFocus()
    return image
}

for size in sizes {
    let image = renderIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed \(size)")
        continue
    }

    try! png.write(to: URL(fileURLWithPath: "\(outputDir)/icon_\(size)x\(size).png"))
    if size >= 32 {
        try! png.write(to: URL(fileURLWithPath: "\(outputDir)/icon_\(size/2)x\(size/2)@2x.png"))
    }
    print("✓ \(size)")
}

let contentsJSON = """
{
  "images": [
    { "filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16" },
    { "filename": "icon_16x16@2x.png", "idiom": "mac", "scale": "2x", "size": "16x16" },
    { "filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32" },
    { "filename": "icon_32x32@2x.png", "idiom": "mac", "scale": "2x", "size": "32x32" },
    { "filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128" },
    { "filename": "icon_128x128@2x.png", "idiom": "mac", "scale": "2x", "size": "128x128" },
    { "filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256" },
    { "filename": "icon_256x256@2x.png", "idiom": "mac", "scale": "2x", "size": "256x256" },
    { "filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512" },
    { "filename": "icon_512x512@2x.png", "idiom": "mac", "scale": "2x", "size": "512x512" }
  ],
  "info": { "author": "xcode", "version": 1 }
}
"""
try! contentsJSON.write(toFile: "\(outputDir)/Contents.json", atomically: true, encoding: .utf8)
print("✓ Done")
