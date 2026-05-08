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

    // Background: gray gradient (glass-like)
    let cornerRadius = s * 0.223
    let borderWidth = s * 0.025
    let bgPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s), xRadius: cornerRadius, yRadius: cornerRadius)

    // Gradient border: orange to cyan
    ctx.saveGState()
    bgPath.addClip()
    let borderColors = [
        NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 0.7).cgColor,
        NSColor(red: 0.6, green: 0.4, blue: 0.6, alpha: 0.5).cgColor,
        NSColor(red: 0.2, green: 0.68, blue: 0.9, alpha: 0.7).cgColor
    ] as CFArray
    let borderGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: borderColors, locations: [0.0, 0.5, 1.0])!
    ctx.drawLinearGradient(borderGradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    ctx.restoreGState()

    // Inner fill (slightly inset) — warm golden tan like Dynamic Island
    let innerRect = NSRect(x: borderWidth, y: borderWidth, width: s - borderWidth * 2, height: s - borderWidth * 2)
    let innerRadius = cornerRadius - borderWidth
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: innerRadius, yRadius: innerRadius)

    let bgColors = [
        NSColor(red: 0.85, green: 0.72, blue: 0.55, alpha: 1.0).cgColor,
        NSColor(red: 0.78, green: 0.62, blue: 0.45, alpha: 1.0).cgColor
    ] as CFArray
    let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0.0, 1.0])!

    ctx.saveGState()
    innerPath.addClip()
    ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

    // Glass highlight on top-left area
    let highlightColors = [
        NSColor(white: 1.0, alpha: 0.35).cgColor,
        NSColor(white: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    let highlightGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: highlightColors, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(highlightGradient,
        startCenter: CGPoint(x: s * 0.3, y: s * 0.7),
        startRadius: 0,
        endCenter: CGPoint(x: s * 0.3, y: s * 0.7),
        endRadius: s * 0.5,
        options: [])

    ctx.restoreGState()

    // Render SF Symbol hands
    let symbolSize = s * 0.30
    let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold)

    if let handSymbol = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: nil) {
        let configured = handSymbol.withSymbolConfiguration(config) ?? handSymbol
        let symbolRect = NSRect(x: 0, y: 0, width: configured.size.width, height: configured.size.height)

        let centerY = (s - symbolRect.height) / 2
        let gap = s * 0.04

        // Left hand (orange)
        let leftX = s / 2 - symbolRect.width - gap / 2
        let orangeColor = NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 0.85)

        let leftHandImage = NSImage(size: symbolRect.size)
        leftHandImage.lockFocus()
        configured.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        orangeColor.set()
        symbolRect.fill(using: .sourceAtop)
        leftHandImage.unlockFocus()
        leftHandImage.draw(at: NSPoint(x: leftX, y: centerY), from: .zero, operation: .sourceOver, fraction: 1.0)

        // Right hand (cyan, mirrored)
        let rightX = s / 2 + gap / 2 + symbolRect.width
        let cyanColor = NSColor(red: 0.2, green: 0.68, blue: 0.9, alpha: 0.85)

        let rightHandImage = NSImage(size: symbolRect.size)
        rightHandImage.lockFocus()
        configured.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        cyanColor.set()
        symbolRect.fill(using: .sourceAtop)
        rightHandImage.unlockFocus()

        // Draw mirrored
        ctx.saveGState()
        ctx.translateBy(x: rightX, y: centerY)
        ctx.scaleBy(x: -1, y: 1)
        rightHandImage.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)
        ctx.restoreGState()
    }

    // Glass overlay: subtle top highlight over everything
    ctx.saveGState()
    bgPath.addClip()
    let overlayColors = [
        NSColor(white: 1.0, alpha: 0.25).cgColor,
        NSColor(white: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    let overlayGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: overlayColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(overlayGradient, start: CGPoint(x: s/2, y: s), end: CGPoint(x: s/2, y: s * 0.5), options: [])
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

for size in sizes {
    let image = renderIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to render \(size)x\(size)")
        continue
    }

    let filename = "\(outputDir)/icon_\(size)x\(size).png"
    try! png.write(to: URL(fileURLWithPath: filename))

    if size >= 32 {
        let halfSize = size / 2
        let filename2x = "\(outputDir)/icon_\(halfSize)x\(halfSize)@2x.png"
        try! png.write(to: URL(fileURLWithPath: filename2x))
    }

    print("✓ \(size)x\(size)")
}

// Write Contents.json
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
print("✓ Contents.json")
print("Done!")
