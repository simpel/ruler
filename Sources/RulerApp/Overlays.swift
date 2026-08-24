import AppKit

/// Shared blueprint look for the ruler face and overlay pieces: white
/// linework on blueprint blue, with redline markup and amber guides.
enum Palette {
    static let face = NSColor(calibratedRed: 0x12 / 255.0, green: 0x3A / 255.0, blue: 0x66 / 255.0, alpha: 1.0)
    static let ink = NSColor(calibratedRed: 0xEA / 255.0, green: 0xF2 / 255.0, blue: 0xFF / 255.0, alpha: 1.0)
    static let live = NSColor(calibratedRed: 0xFF / 255.0, green: 0x5A / 255.0, blue: 0x36 / 255.0, alpha: 1.0)    // cursor line / live measurement ("redline")
    static let guideLine = NSColor(calibratedRed: 0xF5 / 255.0, green: 0xB9 / 255.0, blue: 0x42 / 255.0, alpha: 1.0)  // fixed guides ("drafting amber")
    /// A paler wash of the guide amber, for the hover distance badges.
    static let guideTint: NSColor = guideLine.blended(withFraction: 0.55, of: NSColor.white) ?? guideLine
    static let guideBadgeText = NSColor(calibratedRed: 0x0E / 255.0, green: 0x2A / 255.0, blue: 0x4A / 255.0, alpha: 1.0)  // dark text for the amber guide badge

    static func hud() -> NSColor { NSColor(calibratedRed: 0x0A / 255.0, green: 0x23 / 255.0, blue: 0x40 / 255.0, alpha: 0.92) }

    /// A subtle top-lit sheen for the ruler face, lighter at the top edge.
    static let faceGradient: NSGradient = {
        let white = NSColor(calibratedWhite: 1.0, alpha: 1.0)
        let black = NSColor(calibratedWhite: 0.0, alpha: 1.0)
        let top = face.blended(withFraction: 0.14, of: white) ?? face
        let bottom = face.blended(withFraction: 0.16, of: black) ?? face
        return NSGradient(starting: top, ending: bottom) ?? NSGradient(colors: [face, face])!
    }()
}

/// A click-through hairline window spanning a whole screen. Used for the
/// crosshair that follows the pointer; moving a window is far cheaper than
/// redrawing a full-screen view 60 times a second.
final class HairlineWindow: NSPanel {

    private let orientation: RulerAxis

    init(orientation: RulerAxis) {
        self.orientation = orientation
        super.init(contentRect: NSRect(x: 0, y: 0, width: 10, height: 1),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        isOpaque = false
        hasShadow = false
        isReleasedWhenClosed = false
        backgroundColor = Palette.live.withAlphaComponent(0.55)
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 2)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
    }

    override var canBecomeKey: Bool { false }

    /// Positions the hairline through `point` (global coordinates).
    func follow(_ point: NSPoint, on screen: NSScreen) {
        let f = screen.frame
        let rect: NSRect
        switch orientation {
        case .horizontal:   // a horizontal line, moves in y
            rect = NSRect(x: f.minX, y: point.y.rounded() - 0.5, width: f.width, height: 1)
        case .vertical:     // a vertical line, moves in x
            rect = NSRect(x: point.x.rounded() - 0.5, y: f.minY, width: 1, height: f.height)
        }
        if frame != rect { setFrame(rect, display: false) }
    }
}

/// Click-through overlay that draws the shift-drag measurement and the
/// pointer coordinate readout. Its window is kept just big enough to hold the
/// measurement plus its labels, so redraws stay cheap.
final class MeasureOverlayWindow: NSPanel {

    let measureView = MeasureView()

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        contentView = measureView
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
    }

    override var canBecomeKey: Bool { false }

    /// `anchor` is nil while the gesture is only armed (no button pressed yet).
    func show(anchor: NSPoint?, current: NSPoint, scale: CGFloat, screen: NSScreen) {
        let padding: CGFloat = 120
        var box = NSRect(origin: current, size: .zero)
        if let a = anchor {
            box = NSRect(x: min(a.x, current.x), y: min(a.y, current.y),
                         width: abs(a.x - current.x), height: abs(a.y - current.y))
        }
        var frame = box.insetBy(dx: -padding, dy: -padding)
        frame = NSRect(x: frame.origin.x.rounded(), y: frame.origin.y.rounded(),
                       width: frame.width.rounded(), height: frame.height.rounded())

        if frame != self.frame { setFrame(frame, display: false) }

        measureView.anchor = anchor.map { NSPoint(x: $0.x - frame.minX, y: $0.y - frame.minY) }
        measureView.current = NSPoint(x: current.x - frame.minX, y: current.y - frame.minY)
        measureView.scale = scale
        measureView.showsClose = false
        measureView.screenOrigin = NSPoint(x: screen.frame.minX - frame.minX,
                                           y: screen.frame.maxY - frame.minY)
        measureView.needsDisplay = true

        if !isVisible { orderFrontRegardless() }
    }

    func hide() {
        if isVisible { orderOut(nil) }
    }
}

final class MeasureView: NSView {

    var anchor: NSPoint?
    var current: NSPoint = .zero
    var scale: CGFloat = 1
    /// Top-left corner of the pointer's screen, in this view's coordinates.
    var screenOrigin: NSPoint = .zero

    /// Kept measurements carry a dismiss button; the live one does not.
    var showsClose = false
    var onClose: (() -> Void)?
    var closeHot = false {
        didSet { if oldValue != closeHot { needsDisplay = true } }
    }
    /// Where the dismiss button was last drawn, in view coordinates.
    private(set) var closeRect: NSRect?

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        if let a = anchor {
            drawMeasurement(from: a, to: current)
        } else {
            let x = (current.x - screenOrigin.x) * scale
            let y = (screenOrigin.y - current.y) * scale
            drawBadge(["X \(Int(x.rounded()))   Y \(Int(y.rounded()))"], near: current)
        }
    }

    private func drawMeasurement(from a: NSPoint, to b: NSPoint) {
        let dx = abs(b.x - a.x) * scale
        let dy = abs(b.y - a.y) * scale
        let dist = (hypot(b.x - a.x, b.y - a.y)) * scale

        // Bounding box of the drag.
        let box = NSRect(x: min(a.x, b.x), y: min(a.y, b.y),
                         width: abs(a.x - b.x), height: abs(a.y - b.y))
        let boxPath = NSBezierPath(rect: box)
        boxPath.lineWidth = 1
        boxPath.setLineDash([4, 3], count: 2, phase: 0)
        Palette.live.withAlphaComponent(0.55).setStroke()
        boxPath.stroke()

        Palette.live.withAlphaComponent(0.10).setFill()
        NSBezierPath(rect: box).fill()

        // The measured line itself.
        let line = NSBezierPath()
        line.lineWidth = 1.5
        line.move(to: a)
        line.line(to: b)
        Palette.live.setStroke()
        line.stroke()

        for p in [a, b] {
            let dot = NSRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)
            Palette.live.setFill()
            NSBezierPath(ovalIn: dot).fill()
        }

        var lines = ["\(Int(dist.rounded())) px"]
        if dx > 0.5 || dy > 0.5 {
            lines.append("W \(Int(dx.rounded()))   H \(Int(dy.rounded()))")
        }
        let badge = drawBadge(lines, near: b)
        if showsClose {
            drawClose(on: badge)
        } else {
            closeRect = nil
        }
    }

    /// A small ✕ hanging off the readout badge, like a chip's dismiss control.
    private func drawClose(on badge: NSRect) {
        let d: CGFloat = 17
        var rect = NSRect(x: badge.maxX - d / 2, y: badge.maxY - d / 2, width: d, height: d)
        rect.origin.x = min(rect.origin.x, bounds.maxX - d - 1)
        rect.origin.y = min(rect.origin.y, bounds.maxY - d - 1)
        closeRect = rect

        (closeHot ? Palette.live : Palette.hud()).setFill()
        NSBezierPath(ovalIn: rect).fill()
        NSColor.white.withAlphaComponent(0.25).setStroke()
        let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
        ring.lineWidth = 1
        ring.stroke()

        let inset = d * 0.32
        let cross = NSBezierPath()
        cross.lineWidth = 1.6
        cross.lineCapStyle = .round
        cross.move(to: NSPoint(x: rect.minX + inset, y: rect.minY + inset))
        cross.line(to: NSPoint(x: rect.maxX - inset, y: rect.maxY - inset))
        cross.move(to: NSPoint(x: rect.minX + inset, y: rect.maxY - inset))
        cross.line(to: NSPoint(x: rect.maxX - inset, y: rect.minY + inset))
        NSColor.white.setStroke()
        cross.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        guard let closeRect else { return }
        if closeRect.insetBy(dx: -4, dy: -4).contains(convert(event.locationInWindow, from: nil)) {
            onClose?()
        }
    }

    @discardableResult
    private func drawBadge(_ lines: [String], near point: NSPoint) -> NSRect {
        let text = NSAttributedString(string: lines.joined(separator: "\n"), attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white,
        ])
        let size = text.size()
        let padX: CGFloat = 6, padY: CGFloat = 4
        var rect = NSRect(x: point.x + 14, y: point.y + 14,
                          width: size.width + padX * 2, height: size.height + padY * 2)
        rect.origin.x = min(max(rect.origin.x, bounds.minX + 2), bounds.maxX - rect.width - 2)
        rect.origin.y = min(max(rect.origin.y, bounds.minY + 2), bounds.maxY - rect.height - 2)

        Palette.hud().setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        text.draw(in: NSRect(x: rect.minX + padX, y: rect.minY + padY,
                             width: size.width, height: size.height))
        return rect
    }
}
