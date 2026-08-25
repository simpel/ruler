// Draws Ruler's app icon at every size macOS asks for and writes an .iconset.
//
//   swift Tools/make-icon.swift build/AppIcon.iconset
//   iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
//
// The mark is a carpenter's-square ruler with a red cursor line, echoing what
// the app draws on screen.

import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

/// Apple-style continuous-ish corner: a plain rounded rect is close enough at
/// icon sizes and keeps this dependency-free.
func squircle(_ rect: NSRect) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.2237, yRadius: rect.height * 0.2237)
}

func drawIcon(size S: CGFloat, marketing: Bool = false) {
    // Icon body sits inside the canvas the way macOS app icons do — except for
    // the App Store marketing icon, which Apple masks itself: that one must be
    // a flat, opaque, edge-to-edge square with no inset, radius or shadow.
    let inset = marketing ? 0 : S * 0.098
    let body = NSRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
    let detailed = S >= 64
    let midDetail = S >= 32

    if !marketing {
        // Backdrop
        if S >= 64 {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
            shadow.shadowBlurRadius = S * 0.03
            shadow.shadowOffset = NSSize(width: 0, height: -S * 0.012)
            shadow.set()
        }
        let shape = squircle(body)
        color(0x2B2F35).setFill()
        shape.fill()
        NSShadow().set()

        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
    } else {
        color(0x2B2F35).setFill()
        NSBezierPath(rect: body).fill()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: body).addClip()
    }

    let gradient = NSGradient(colors: [color(0x3C424A), color(0x1D2024)])!
    gradient.draw(in: body, angle: -90)

    // Faint highlight along the top edge.
    if detailed && !marketing {
        color(0xFFFFFF, 0.10).setStroke()
        let rim = squircle(body.insetBy(dx: S * 0.006, dy: S * 0.006))
        rim.lineWidth = S * 0.006
        rim.stroke()
    }

    // Geometry of the L, in body-relative units.
    let u = { (v: CGFloat) in body.minX + v * body.width }
    let w = { (v: CGFloat) in body.minY + v * body.height }
    let m: CGFloat = 0.13
    let t: CGFloat = 0.215

    let horizontal = NSRect(x: u(m), y: w(1 - m - t),
                            width: body.width * (1 - m * 2), height: body.height * t)
    // The vertical bar runs the full height and overlaps the horizontal one, so
    // the union fills the corner cleanly instead of leaving a notch.
    let vertical = NSRect(x: u(m), y: w(m),
                          width: body.width * t, height: body.height * (1 - m * 2))
    let verticalScaleTop = w(1 - m - t)   // ticks only along the exposed part

    let face = NSBezierPath()
    let r = S * 0.012
    face.appendRoundedRect(horizontal, xRadius: r, yRadius: r)
    face.appendRoundedRect(vertical, xRadius: r, yRadius: r)
    face.windingRule = .nonZero
    color(0xEAF2FF).setFill()   // Blueprint White, matching Palette.ink
    face.fill()

    // Ticks stand on the inner edges of the L, like the real rulers.
    if midDetail {
        let ticks = NSBezierPath()
        ticks.lineWidth = max(1, S * 0.0115)
        let steps = detailed ? 8 : 4
        let long = detailed ? 2 : 2

        for i in 1..<steps {
            let f = CGFloat(i) / CGFloat(steps)
            let major = i % long == 0
            let depth = horizontal.height * (major ? 0.52 : 0.3)

            let x = (horizontal.minX + horizontal.width * f).rounded()
            ticks.move(to: NSPoint(x: x, y: horizontal.minY))
            ticks.line(to: NSPoint(x: x, y: horizontal.minY + depth))

            let exposed = verticalScaleTop - vertical.minY
            let y = (verticalScaleTop - exposed * f).rounded()
            ticks.move(to: NSPoint(x: vertical.maxX, y: y))
            ticks.line(to: NSPoint(x: vertical.maxX - vertical.width * (major ? 0.52 : 0.3), y: y))
        }
        color(0x2B2F35, 0.8).setStroke()
        ticks.stroke()
    }

    // The live cursor line.
    let cursorX = (horizontal.minX + horizontal.width * 0.66).rounded()
    let cursor = NSBezierPath()
    cursor.lineWidth = max(1, S * 0.017)
    cursor.move(to: NSPoint(x: cursorX, y: horizontal.maxY))
    cursor.line(to: NSPoint(x: cursorX, y: w(m + 0.06)))
    color(0xFF5A36).setStroke()   // Redline, matching Palette.live
    cursor.stroke()

    if detailed {
        let dot = S * 0.028
        color(0xFF5A36).setFill()
        NSBezierPath(ovalIn: NSRect(x: cursorX - dot / 2, y: w(m + 0.06) - dot / 2,
                                    width: dot, height: dot)).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
}

func render(pixels: Int, marketing: Bool = false) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                              pixelsWide: pixels, pixelsHigh: pixels,
                              bitsPerSample: 8, samplesPerPixel: 4,
                              hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    drawIcon(size: CGFloat(pixels), marketing: marketing)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

/// The App Store Connect marketing icon: 1024x1024, flat, no alpha channel —
/// Apple's own validator rejects a transparent or rounded-corner version.
/// Drawing a second time into a no-alpha context (directly, or by compositing
/// a CGImage into one) rendered blank both ways — something about that
/// context doesn't take AppKit drawing. So this reuses the PNG bytes from the
/// already-proven render() path unchanged, decodes them back, and copies the
/// raw RGB bytes into a fresh alpha-free bitmap by hand — no second draw pass.
func renderMarketingIcon() -> Data {
    let pixels = 1024
    let pngData = render(pixels: pixels, marketing: true)
    guard let decoded = NSBitmapImageRep(data: pngData) else {
        fatalError("could not decode the rendered marketing icon")
    }
    let flat = NSBitmapImageRep(bitmapDataPlanes: nil,
                                pixelsWide: pixels, pixelsHigh: pixels,
                                bitsPerSample: 8, samplesPerPixel: 3,
                                hasAlpha: false, isPlanar: false,
                                colorSpaceName: .deviceRGB,
                                bytesPerRow: 0, bitsPerPixel: 0)!
    guard let src = decoded.bitmapData, let dst = flat.bitmapData else {
        fatalError("no bitmap data to copy")
    }
    let srcSamples = decoded.samplesPerPixel
    let srcRowBytes = decoded.bytesPerRow
    let dstRowBytes = flat.bytesPerRow
    for y in 0..<pixels {
        for x in 0..<pixels {
            let s0 = y * srcRowBytes + x * srcSamples
            let d0 = y * dstRowBytes + x * 3
            dst[d0] = src[s0]
            dst[d0 + 1] = src[s0 + 1]
            dst[d0 + 2] = src[s0 + 2]
        }
    }
    return flat.representation(using: .png, properties: [:])!
}

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

try? FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: true)
for (name, pixels) in variants {
    let data = render(pixels: pixels)
    try! data.write(to: URL(fileURLWithPath: outputPath + "/" + name))
}
print("wrote \(variants.count) images to \(outputPath)")

if CommandLine.arguments.contains("--marketing") {
    let data = renderMarketingIcon()
    let path = outputPath + "/AppStoreIcon-1024.png"
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote marketing icon to \(path)")
}
