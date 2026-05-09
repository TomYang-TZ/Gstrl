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

    // === ARCS — exact CSS border math ===
    // CSS border on circle: each side = 90deg arc
    // CG coords: 0=right(3oclock), pi/2=top(12oclock), pi=left(9oclock), -pi/2=bottom(6oclock)
    // CSS border positions in CG (before rotation):
    //   top:    pi/4  → 3pi/4   (from 1:30 to 10:30)
    //   right: -pi/4  → pi/4    (from 4:30 to 1:30)
    //   bottom:-3pi/4 → -pi/4   (from 7:30 to 4:30)
    //   left:  3pi/4  → 5pi/4   (from 10:30 to 7:30)
    // Rotation in CSS is clockwise, CG rotation is CCW, so CSS rotate(-30deg) = CG +30deg offset

    let orange = NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
    let cyan = NSColor(red: 0.2, green: 0.68, blue: 0.9, alpha: 1.0)
    ctx.setLineCap(.butt)

    // --- Outer ring: 65% size, CSS rotate(-30deg) → CG offset = +pi/6 ---
    let outerRadius = s * 0.285
    let outerRot = CGFloat.pi / 6
    ctx.setLineWidth(s * 0.012)

    // border-top (orange): pi/4+rot → 3pi/4+rot
    ctx.setStrokeColor(orange.withAlphaComponent(0.85).cgColor)
    ctx.addArc(center: center, radius: outerRadius, startAngle: .pi/4 + outerRot, endAngle: .pi*3/4 + outerRot, clockwise: false)
    ctx.strokePath()

    // border-right (cyan): -pi/4+rot → pi/4+rot
    ctx.setStrokeColor(cyan.withAlphaComponent(0.85).cgColor)
    ctx.addArc(center: center, radius: outerRadius, startAngle: -.pi/4 + outerRot, endAngle: .pi/4 + outerRot, clockwise: false)
    ctx.strokePath()

    // --- Mid ring: 47% size, CSS rotate(60deg) → CG offset = -pi/3 ---
    let midRadius = s * 0.205
    let midRot = -CGFloat.pi / 3
    ctx.setLineWidth(s * 0.008)

    // border-bottom (orange): -3pi/4+rot → -pi/4+rot
    ctx.setStrokeColor(orange.withAlphaComponent(0.6).cgColor)
    ctx.addArc(center: center, radius: midRadius, startAngle: -.pi*3/4 + midRot, endAngle: -.pi/4 + midRot, clockwise: false)
    ctx.strokePath()

    // border-left (cyan): 3pi/4+rot → 5pi/4+rot
    ctx.setStrokeColor(cyan.withAlphaComponent(0.6).cgColor)
    ctx.addArc(center: center, radius: midRadius, startAngle: .pi*3/4 + midRot, endAngle: .pi*5/4 + midRot, clockwise: false)
    ctx.strokePath()

    // --- Inner ring: 30% size, CSS rotate(-15deg) → CG offset = +pi/12 ---
    let innerRadius = s * 0.13
    let innerRot = CGFloat.pi / 12
    ctx.setLineWidth(s * 0.005)

    // border-top (orange): pi/4+rot → 3pi/4+rot
    ctx.setStrokeColor(orange.withAlphaComponent(0.45).cgColor)
    ctx.addArc(center: center, radius: innerRadius, startAngle: .pi/4 + innerRot, endAngle: .pi*3/4 + innerRot, clockwise: false)
    ctx.strokePath()

    // border-right (cyan): -pi/4+rot → pi/4+rot
    ctx.setStrokeColor(cyan.withAlphaComponent(0.45).cgColor)
    ctx.addArc(center: center, radius: innerRadius, startAngle: -.pi/4 + innerRot, endAngle: .pi/4 + innerRot, clockwise: false)
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

    // Left finger tilts right (top leans toward center)
    drawFingertip(
        at: CGPoint(x: center.x - gap - tipWidth * 0.55, y: center.y),
        angle: -.pi * 15 / 180,
        color: orange
    )

    // Right finger tilts left (top leans toward center)
    drawFingertip(
        at: CGPoint(x: center.x + gap + tipWidth * 0.55, y: center.y),
        angle: .pi * 15 / 180,
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
