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

    // Inactive / neutral palette (used when not in active drawing context)
    static let inactiveFace = NSColor(calibratedRed: 0x24 / 255.0, green: 0x28 / 255.0, blue: 0x30 / 255.0, alpha: 1.0)
    static let inactiveInk = NSColor(calibratedWhite: 0.65, alpha: 1.0)
    static let inactiveLive = NSColor(calibratedWhite: 0.48, alpha: 0.8)

    static let inactiveFaceGradient: NSGradient = {
        let white = NSColor(calibratedWhite: 1.0, alpha: 1.0)
        let black = NSColor(calibratedWhite: 0.0, alpha: 1.0)
        let top = inactiveFace.blended(withFraction: 0.12, of: white) ?? inactiveFace
        let bottom = inactiveFace.blended(withFraction: 0.15, of: black) ?? inactiveFace
        return NSGradient(starting: top, ending: bottom) ?? NSGradient(colors: [inactiveFace, inactiveFace])!
    }()
}

/// A click-through hairline window spanning a whole screen. Used for the
/// crosshair that follows the pointer; moving a window is far cheaper than
/// redrawing a full-screen view 60 times a second.
final class HairlineWindow: NSPanel {

    private let orientation: RulerAxis
    private let lineView = NSView()

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
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 2)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]

        lineView.wantsLayer = true
        lineView.layer?.backgroundColor = Palette.live.cgColor
        contentView = lineView
    }

    override var canBecomeKey: Bool { false }

    func setLineOpacity(_ opacity: CGFloat) {
        lineView.alphaValue = opacity
        lineView.layer?.opacity = Float(opacity)
        alphaValue = opacity
        backgroundColor = Palette.live.withAlphaComponent(opacity)
    }

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
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 4)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
    }

    override var canBecomeKey: Bool { false }

    /// `anchor` is nil while the gesture is only armed (no button pressed yet).
    func show(anchor: NSPoint?, current: NSPoint, scale: CGFloat, screen: NSScreen, shapeType: ShapeType = .rectangle) {
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

        measureView.shapeType = shapeType
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

