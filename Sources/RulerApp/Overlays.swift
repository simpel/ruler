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

final class MeasureView: NSView {

    weak var owner: MeasurementWindow?
    var shapeType: ShapeType = .rectangle
    var anchor: NSPoint?
    var current: NSPoint = .zero
    var scale: CGFloat = 1
    /// Top-left corner of the pointer's screen, in this view's coordinates.
    var screenOrigin: NSPoint = .zero

    /// Kept measurements carry a dismiss button; the live one does not.
    var showsClose = false
    var onClose: (() -> Void)?
    var onEdit: (() -> Void)?
    var closeHot = false {
        didSet { if oldValue != closeHot { needsDisplay = true } }
    }
    var editHot = false {
        didSet { if oldValue != editHot { needsDisplay = true } }
    }
    var tooltipHot = false {
        didSet { if oldValue != tooltipHot { needsDisplay = true } }
    }
    var outlineHot = false {
        didSet { if oldValue != outlineHot { needsDisplay = true } }
    }

    /// Where the dismiss button, edit button and badge were last drawn, in view coordinates.
    private(set) var closeRect: NSRect?
    private(set) var editRect: NSRect?
    private(set) var badgeRect: NSRect?
    private(set) var shapeBox: NSRect = .zero

    private var isDragging = false
    private var dragStartMouse: NSPoint = .zero
    private var dragStartAnchor: NSPoint = .zero
    private var dragStartCurrent: NSPoint = .zero

    override var isOpaque: Bool { false }

    func isOverOutline(_ localPoint: NSPoint) -> Bool {
        shapeType.isPointOnOutline(localPoint, in: shapeBox)
    }

    override func draw(_ dirtyRect: NSRect) {
        if let a = anchor {
            if shapeType == .circle {
                drawCircleMeasurement(from: a, to: current)
            } else {
                drawRectangleMeasurement(from: a, to: current)
            }
        } else {
            let x = (current.x - screenOrigin.x) * scale
            let y = (screenOrigin.y - current.y) * scale
            drawBadge(["X \(Int(x.rounded()))   Y \(Int(y.rounded()))"], near: current)
        }
    }

    private func drawRectangleMeasurement(from a: NSPoint, to b: NSPoint) {
        let box = NSRect(x: min(a.x, b.x), y: min(a.y, b.y),
                         width: abs(a.x - b.x), height: abs(a.y - b.y))
        shapeBox = box

        let boxPath = NSBezierPath(rect: box)
        boxPath.lineWidth = 1
        boxPath.setLineDash([4, 3], count: 2, phase: 0)
        let strokeCol = outlineHot ? Palette.live : Palette.live.withAlphaComponent(0.55)
        strokeCol.setStroke()
        boxPath.stroke()

        Palette.live.withAlphaComponent(0.10).setFill()
        NSBezierPath(rect: box).fill()

        // Diagonal measured line
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

        let posX = (box.minX - screenOrigin.x) * scale
        let posY = (screenOrigin.y - box.maxY) * scale
        let width = box.width * scale
        let height = box.height * scale

        let lines = [
            "X \(Int(posX.rounded()))   Y \(Int(posY.rounded()))",
            "W \(Int(width.rounded()))   H \(Int(height.rounded()))",
        ]
        let badge = drawBadge(lines, forShapeBox: box)
        badgeRect = badge
        if showsClose {
            drawClose(on: badge)
        } else {
            closeRect = nil
            editRect = nil
        }
    }

    private func drawCircleMeasurement(from a: NSPoint, to b: NSPoint) {
        let box = NSRect(x: min(a.x, b.x), y: min(a.y, b.y),
                         width: abs(a.x - b.x), height: abs(a.y - b.y))
        shapeBox = box

        let ovalPath = NSBezierPath(ovalIn: box)
        ovalPath.lineWidth = 1
        ovalPath.setLineDash([4, 3], count: 2, phase: 0)
        let strokeCol = outlineHot ? Palette.live : Palette.live.withAlphaComponent(0.55)
        strokeCol.setStroke()
        ovalPath.stroke()

        Palette.live.withAlphaComponent(0.10).setFill()
        NSBezierPath(ovalIn: box).fill()

        // Center crosshair mark
        let center = NSPoint(x: box.midX, y: box.midY)
        let cross = NSBezierPath()
        cross.lineWidth = 1
        cross.move(to: NSPoint(x: center.x - 4, y: center.y))
        cross.line(to: NSPoint(x: center.x + 4, y: center.y))
        cross.move(to: NSPoint(x: center.x, y: center.y - 4))
        cross.line(to: NSPoint(x: center.x, y: center.y + 4))
        Palette.live.withAlphaComponent(0.65).setStroke()
        cross.stroke()

        let posX = (box.minX - screenOrigin.x) * scale
        let posY = (screenOrigin.y - box.maxY) * scale
        let width = box.width * scale
        let height = box.height * scale
        let radius = (width + height) / 4.0
        let circumference = 2.0 * CGFloat.pi * radius

        let lines = [
            "X \(Int(posX.rounded()))   Y \(Int(posY.rounded()))",
            "W \(Int(width.rounded()))   H \(Int(height.rounded()))",
            "R \(Int(radius.rounded()))   C \(Int(circumference.rounded()))",
        ]
        let badge = drawBadge(lines, forShapeBox: box)
        badgeRect = badge
        if showsClose {
            drawClose(on: badge)
        } else {
            closeRect = nil
            editRect = nil
        }
    }

    /// The dismiss (✕) and set values buttons on the readout badge.
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

        // Edit button directly to the left of close button
        let eRect = NSRect(x: rect.minX - d - 3, y: rect.minY, width: d, height: d)
        editRect = eRect

        (editHot ? Palette.live : Palette.hud()).setFill()
        NSBezierPath(ovalIn: eRect).fill()
        NSColor.white.withAlphaComponent(0.25).setStroke()
        let eRing = NSBezierPath(ovalIn: eRect.insetBy(dx: 0.5, dy: 0.5))
        eRing.lineWidth = 1
        eRing.stroke()

        // Vector slider icon
        let left = eRect.minX + 3.5
        let right = eRect.maxX - 3.5
        NSColor.white.setStroke()

        let p1 = NSBezierPath()
        p1.lineWidth = 1.0
        p1.move(to: NSPoint(x: left, y: eRect.midY + 3.2))
        p1.line(to: NSPoint(x: right, y: eRect.midY + 3.2))
        p1.stroke()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: left + 2.0, y: eRect.midY + 2.0, width: 2.4, height: 2.4)).fill()

        let p2 = NSBezierPath()
        p2.lineWidth = 1.0
        p2.move(to: NSPoint(x: left, y: eRect.midY))
        p2.line(to: NSPoint(x: right, y: eRect.midY))
        p2.stroke()
        NSBezierPath(ovalIn: NSRect(x: right - 4.4, y: eRect.midY - 1.2, width: 2.4, height: 2.4)).fill()

        let p3 = NSBezierPath()
        p3.lineWidth = 1.0
        p3.move(to: NSPoint(x: left, y: eRect.midY - 3.2))
        p3.line(to: NSPoint(x: right, y: eRect.midY - 3.2))
        p3.stroke()
        NSBezierPath(ovalIn: NSRect(x: eRect.midX - 1.2, y: eRect.midY - 4.4, width: 2.4, height: 2.4)).fill()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if showsClose {
            if let closeRect {
                addCursorRect(closeRect, cursor: .pointingHand)
            }
            if let editRect {
                addCursorRect(editRect, cursor: .pointingHand)
            }
            if let badgeRect {
                addCursorRect(badgeRect, cursor: .openHand)
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if let closeRect, closeRect.insetBy(dx: -4, dy: -4).contains(loc) {
            onClose?()
            return
        }
        if let editRect, editRect.insetBy(dx: -4, dy: -4).contains(loc) {
            onEdit?()
            return
        }
        if let badgeRect, badgeRect.contains(loc) {
            startDrag()
            return
        }
        if isOverOutline(loc) {
            startDrag()
            return
        }
    }

    private func startDrag() {
        guard let owner else { return }
        isDragging = true
        dragStartMouse = NSEvent.mouseLocation
        dragStartAnchor = owner.anchor
        dragStartCurrent = owner.current
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let owner else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - dragStartMouse.x
        let dy = mouse.y - dragStartMouse.y
        owner.move(toAnchor: NSPoint(x: dragStartAnchor.x + dx, y: dragStartAnchor.y + dy),
                   current: NSPoint(x: dragStartCurrent.x + dx, y: dragStartCurrent.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            NSCursor.pop()
        }
    }

    @discardableResult
    private func drawBadge(_ lines: [String], near point: NSPoint? = nil, forShapeBox box: NSRect? = nil) -> NSRect {
        let text = NSAttributedString(string: lines.joined(separator: "\n"), attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white,
        ])
        let size = text.size()
        let padX: CGFloat = 6, padY: CGFloat = 4
        let badgeWidth = size.width + padX * 2
        let badgeHeight = size.height + padY * 2

        var rect: NSRect
        if let box {
            // Position outside the shape: preferred below, flip above if near bottom edge
            var x = box.midX - badgeWidth / 2.0
            var y = box.minY - badgeHeight - 12.0
            if y < bounds.minY + 4 {
                y = box.maxY + 12.0
            }
            x = min(max(x, bounds.minX + 4), bounds.maxX - badgeWidth - 4)
            y = min(max(y, bounds.minY + 4), bounds.maxY - badgeHeight - 4)
            rect = NSRect(x: x.rounded(), y: y.rounded(), width: badgeWidth, height: badgeHeight)
        } else {
            let pt = point ?? .zero
            var x = pt.x + 14
            var y = pt.y + 14
            x = min(max(x, bounds.minX + 2), bounds.maxX - badgeWidth - 2)
            y = min(max(y, bounds.minY + 2), bounds.maxY - badgeHeight - 2)
            rect = NSRect(x: x.rounded(), y: y.rounded(), width: badgeWidth, height: badgeHeight)
        }

        let bgCol = tooltipHot ? Palette.hud().blended(withFraction: 0.15, of: .white) ?? Palette.hud() : Palette.hud()
        bgCol.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()

        if tooltipHot {
            Palette.guideLine.withAlphaComponent(0.6).setStroke()
            let border = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            border.lineWidth = 1
            border.stroke()
        }

        text.draw(in: NSRect(x: rect.minX + padX, y: rect.minY + padY,
                             width: size.width, height: size.height))
        return rect
    }
}
