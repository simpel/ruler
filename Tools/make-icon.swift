// Draws Distanser's app icon at every size macOS asks for and writes an .iconset.
//
//   swift Tools/make-icon.swift build/AppIcon.iconset
//   iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
//
// The mark reflects the app's signature blueprint visual identity:
// a blueprint blue canvas with drafting grid, crisp white carpenter's-square
// ruler, blueprint blue ticks, and a redline cursor measurement.

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

/// Builds a single unified seamless L-shape path with rounded outer and inner corners.
func makeLShapePath(x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat, t: CGFloat, r: CGFloat) -> NSBezierPath {
    let path = CGMutablePath()
    let p0 = CGPoint(x: x0, y: y0)
    let p1 = CGPoint(x: x0 + t, y: y0)
    let p2 = CGPoint(x: x0 + t, y: y1 - t)
    let p3 = CGPoint(x: x1, y: y1 - t)
    let p4 = CGPoint(x: x1, y: y1)
    let p5 = CGPoint(x: x0, y: y1)

    path.move(to: CGPoint(x: x0 + r, y: y0))
    path.addArc(tangent1End: p1, tangent2End: p2, radius: r)
    path.addArc(tangent1End: p2, tangent2End: p3, radius: r)
    path.addArc(tangent1End: p3, tangent2End: p4, radius: r)
    path.addArc(tangent1End: p4, tangent2End: p5, radius: r)
    path.addArc(tangent1End: p5, tangent2End: p0, radius: r)
    path.addArc(tangent1End: p0, tangent2End: p1, radius: r)
    path.closeSubpath()

    let bPath = NSBezierPath()
    cgPathToNSBezierPath(path, into: bPath)
    return bPath
}

func cgPathToNSBezierPath(_ cgPath: CGPath, into bPath: NSBezierPath) {
    cgPath.applyWithBlock { element in
        let points = element.pointee.points
        switch element.pointee.type {
        case .moveToPoint:
            bPath.move(to: NSPoint(x: points[0].x, y: points[0].y))
        case .addLineToPoint:
            bPath.line(to: NSPoint(x: points[0].x, y: points[0].y))
        case .addQuadCurveToPoint:
            let current = bPath.currentPoint
            let cp = points[0]
            let end = points[1]
            let cp1 = NSPoint(x: current.x + 2.0 / 3.0 * (cp.x - current.x),
                             y: current.y + 2.0 / 3.0 * (cp.y - current.y))
            let cp2 = NSPoint(x: end.x + 2.0 / 3.0 * (cp.x - end.x),
                             y: end.y + 2.0 / 3.0 * (cp.y - end.y))
            bPath.curve(to: end, controlPoint1: cp1, controlPoint2: cp2)
        case .addCurveToPoint:
            bPath.curve(to: points[2], controlPoint1: points[0], controlPoint2: points[1])
        case .closeSubpath:
            bPath.close()
        @unknown default:
            break
        }
    }
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
        color(0x1E538F).setFill()
        shape.fill()
        NSShadow().set()

        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
    } else {
        color(0x1E538F).setFill()
        NSBezierPath(rect: body).fill()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: body).addClip()
    }

    // Blueprint gradient background (#1E538F -> #0C2849)
    let gradient = NSGradient(colors: [color(0x1E538F), color(0x0C2849)])!
    gradient.draw(in: body, angle: -90)

    // Blueprint drafting grid
    if detailed {
        let grid = NSBezierPath()
        let step = body.width / 8.0
        var x = body.minX + step
        while x < body.maxX - 1 {
            grid.move(to: NSPoint(x: x, y: body.minY))
            grid.line(to: NSPoint(x: x, y: body.maxY))
            x += step
        }
        var y = body.minY + step
        while y < body.maxY - 1 {
            grid.move(to: NSPoint(x: body.minX, y: y))
            grid.line(to: NSPoint(x: body.maxX, y: y))
            y += step
        }
        grid.lineWidth = max(0.5, S * 0.004)
        color(0xFFFFFF, 0.09).setStroke()
        grid.stroke()
    }

    // Faint highlight along the top edge.
    if detailed && !marketing {
        color(0xFFFFFF, 0.14).setStroke()
        let rim = squircle(body.insetBy(dx: S * 0.006, dy: S * 0.006))
        rim.lineWidth = S * 0.006
        rim.stroke()
    }

    // Geometry of the L, in body-relative units.
    let u = { (v: CGFloat) in body.minX + v * body.width }
    let w = { (v: CGFloat) in body.minY + v * body.height }
    let m: CGFloat = 0.13
    let t: CGFloat = 0.215
    let r = S * 0.018

    let x0 = u(m)
    let y0 = w(m)
    let x1 = u(1 - m)
    let y1 = w(1 - m)
    let barThickness = body.width * t

    // Drop shadow under the ruler
    if detailed {
        let rShadow = NSShadow()
        rShadow.shadowColor = NSColor.black.withAlphaComponent(0.40)
        rShadow.shadowBlurRadius = S * 0.025
        rShadow.shadowOffset = NSSize(width: 0, height: -S * 0.012)
        rShadow.set()
    }

    let facePath = makeLShapePath(x0: x0, y0: y0, x1: x1, y1: y1, t: barThickness, r: r)

    // Ruler face: Blueprint White with subtle gradient (#FFFFFF -> #EEF4FC)
    NSGraphicsContext.saveGraphicsState()
    facePath.addClip()
    let faceGrad = NSGradient(colors: [color(0xFFFFFF), color(0xEEF4FC)])!
    faceGrad.draw(in: NSRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    NSShadow().set()

    // Outer edge stroke
    color(0xFFFFFF, 0.9).setStroke()
    facePath.lineWidth = max(1, S * 0.008)
    facePath.stroke()

    // Ticks stand on the inner edges of the L in Blueprint Blue (matching Palette.face)
    let horizontalMinX = x0 + barThickness
    let horizontalWidth = x1 - horizontalMinX
    let horizontalMinY = y1 - barThickness

    let verticalScaleTop = y1 - barThickness
    let verticalHeight = verticalScaleTop - y0
    let verticalMaxX = x0 + barThickness

    if midDetail {
        let ticks = NSBezierPath()
        ticks.lineWidth = max(1, S * 0.012)
        let steps = detailed ? 8 : 4
        let long = detailed ? 2 : 2

        for i in 1..<steps {
            let f = CGFloat(i) / CGFloat(steps)
            let major = i % long == 0
            let depth = barThickness * (major ? 0.52 : 0.3)

            let x = (horizontalMinX + horizontalWidth * f).rounded()
            ticks.move(to: NSPoint(x: x, y: horizontalMinY))
            ticks.line(to: NSPoint(x: x, y: horizontalMinY + depth))

            let y = (verticalScaleTop - verticalHeight * f).rounded()
            ticks.move(to: NSPoint(x: verticalMaxX, y: y))
            ticks.line(to: NSPoint(x: verticalMaxX - barThickness * (major ? 0.52 : 0.3), y: y))
        }
        color(0x123A66, 0.95).setStroke()   // Blueprint Blue (Palette.face)
        ticks.stroke()
    }

    // Redline live cursor measurement line (matching Palette.live)
    let cursorX = (horizontalMinX + horizontalWidth * 0.55).rounded()
    let cursor = NSBezierPath()
    cursor.lineWidth = max(1, S * 0.018)
    cursor.move(to: NSPoint(x: cursorX, y: y1))
    cursor.line(to: NSPoint(x: cursorX, y: w(m + 0.06)))
    color(0xFF5A36).setStroke()   // Redline
    cursor.stroke()

    if detailed {
        let dot = S * 0.030
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
