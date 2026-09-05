import AppKit

/// Draws the ruler face: tick marks, numeric labels, and the live cursor line.
final class RulerView: NSView {

    // MARK: Layout constants
    static let thickness: CGFloat = 34
    private let cornerRadius: CGFloat = 6
    private let resizeZone: CGFloat = 16

    private let minorStep: CGFloat = 10     // in display units
    private let midStep: CGFloat = 50
    private let majorStep: CGFloat = 100

    private let minorLen: CGFloat = 4
    private let midLen: CGFloat = 8
    private let majorLen: CGFloat = 13

    let axis: RulerAxis

    /// Distance (points) from the ruler's start to the cursor, or nil when off-ruler.
    var cursorDistance: CGFloat? {
        didSet { if oldValue != cursorDistance { needsDisplay = true } }
    }

    /// Span of an active measurement, in distances along this ruler.
    var measureSpan: ClosedRange<CGFloat>? {
        didSet { if oldValue != measureSpan { needsDisplay = true } }
    }

    private enum DragMode { case none, resize, guideOut }
    private var dragMode: DragMode = .none
    private var resizeHover = false
    private var trackingArea: NSTrackingArea?
    private weak var pendingGuide: GuideWindow?
    private var dragStartMouse: NSPoint = .zero
    private var dragStartFrame: NSRect = .zero

    init(axis: RulerAxis) {
        self.axis = axis
        super.init(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    // MARK: - Geometry helpers

    /// Length of the ruler along its measuring axis, in points.
    private var length: CGFloat {
        axis == .horizontal ? bounds.width : bounds.height
    }

    /// Points-per-display-unit: 1 for logical points, 1/scale for device pixels.
    private var pointsPerUnit: CGFloat {
        Settings.shared.devicePixels ? 1.0 / (window?.backingScaleFactor ?? 2.0) : 1.0
    }

    private var zeroOffset: CGFloat {
        Settings.shared.zeroOffset(for: axis)
    }

    /// Converts a distance along the ruler (points from its start) into a view point.
    private func position(forDistance d: CGFloat) -> CGFloat {
        axis == .horizontal ? bounds.minX + d : bounds.maxY - d
    }

    /// Converts a point inside the view into a distance along the ruler.
    func distance(forViewPoint p: NSPoint) -> CGFloat {
        axis == .horizontal ? p.x - bounds.minX : bounds.maxY - p.y
    }

    private func displayValue(atDistance d: CGFloat) -> CGFloat {
        (d - zeroOffset) / pointsPerUnit
    }

    // MARK: - Drawing

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let ink = Palette.ink

        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                xRadius: cornerRadius, yRadius: cornerRadius)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(0.96)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowOffset = NSSize(width: 0, height: -1.5)
        shadow.shadowBlurRadius = 3
        shadow.set()
        Palette.faceGradient.draw(in: shape, angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        ink.withAlphaComponent(0.3).setStroke()
        shape.lineWidth = 1
        shape.stroke()

        NSGraphicsContext.saveGraphicsState()
        shape.addClip()

        if let span = measureSpan { drawMeasureBand(span) }
        let grabbing = resizeHover || dragMode == .resize
        if grabbing { drawResizeHighlight(ink: ink) }
        drawTicks(ink: ink)
        drawGrip(ink: ink, highlighted: grabbing)
        if let d = cursorDistance, d >= 0, d <= length {
            drawCursor(at: d, accent: Palette.live)
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawTicks(ink: NSColor) {
        let ppu = pointsPerUnit
        let vStart = displayValue(atDistance: 0)
        let vEnd = displayValue(atDistance: length)
        guard vEnd > vStart else { return }

        let first = (vStart / minorStep).rounded(.down) * minorStep
        let path = NSBezierPath()
        path.lineWidth = 1

        var v = first
        while v <= vEnd + minorStep {
            let d = zeroOffset + v * ppu
            if d >= -1, d <= length + 1 {
                let isMajor = v.truncatingRemainder(dividingBy: majorStep) == 0
                let isMid = v.truncatingRemainder(dividingBy: midStep) == 0
                let len = isMajor ? majorLen : (isMid ? midLen : minorLen)
                let p = (position(forDistance: d)).rounded() + 0.5

                switch axis {
                case .horizontal:
                    path.move(to: NSPoint(x: p, y: bounds.minY))
                    path.line(to: NSPoint(x: p, y: bounds.minY + len))
                case .vertical:
                    path.move(to: NSPoint(x: bounds.maxX, y: p))
                    path.line(to: NSPoint(x: bounds.maxX - len, y: p))
                }

                if isMajor {
                    drawLabel(String(Int(v.rounded())), atDistance: d, ink: ink)
                }
            }
            v += minorStep
        }

        ink.withAlphaComponent(0.75).setStroke()
        path.stroke()
    }

    private func labelAttributes(_ ink: NSColor, size: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium),
            .foregroundColor: ink.withAlphaComponent(0.85),
        ]
    }

    private func drawLabel(_ text: String, atDistance d: CGFloat, ink: NSColor) {
        var string = NSAttributedString(string: text, attributes: labelAttributes(ink, size: 9))
        // The vertical ruler is narrow: shrink long numbers so they never clip.
        if axis == .vertical {
            let room = bounds.width - majorLen - 4
            if string.size().width > room {
                string = NSAttributedString(string: text, attributes: labelAttributes(ink, size: 7.5))
            }
        }
        let size = string.size()
        let p = position(forDistance: d)

        switch axis {
        case .horizontal:
            let y = majorLen + (bounds.height - majorLen - size.height) / 2
            var x = p + 3
            if x + size.width > bounds.maxX - 2 { x = p - 3 - size.width }
            string.draw(at: NSPoint(x: x, y: y))
        case .vertical:
            let x = max(2, (bounds.width - majorLen - size.width) / 2)
            var y = p - size.height / 2
            y = min(max(y, bounds.minY + 1), bounds.maxY - size.height - 1)
            string.draw(at: NSPoint(x: x, y: y))
        }
    }

    private var resizeZoneRect: NSRect {
        switch axis {
        case .horizontal:
            return NSRect(x: bounds.maxX - resizeZone, y: bounds.minY,
                          width: resizeZone, height: bounds.height)
        case .vertical:
            return NSRect(x: bounds.minX, y: bounds.minY,
                          width: bounds.width, height: resizeZone)
        }
    }

    /// Lights up the end of the ruler while the pointer is in the resize zone,
    /// so it reads as a handle rather than part of the scale.
    private func drawResizeHighlight(ink: NSColor) {
        let zone = resizeZoneRect
        ink.withAlphaComponent(0.20).setFill()
        zone.fill()

        let edge = NSBezierPath()
        edge.lineWidth = 1
        switch axis {
        case .horizontal:
            let x = zone.minX.rounded() + 0.5
            edge.move(to: NSPoint(x: x, y: bounds.minY))
            edge.line(to: NSPoint(x: x, y: bounds.maxY))
        case .vertical:
            let y = zone.maxY.rounded() + 0.5
            edge.move(to: NSPoint(x: bounds.minX, y: y))
            edge.line(to: NSPoint(x: bounds.maxX, y: y))
        }
        ink.withAlphaComponent(0.35).setStroke()
        edge.stroke()

        drawResizeArrows(ink: ink, in: zone)
    }

    /// A double-headed arrow across the handle, matching the resize cursor.
    private func drawResizeArrows(ink: NSColor, in zone: NSRect) {
        let path = NSBezierPath()
        path.lineWidth = 1.2
        path.lineCapStyle = .round
        let reach: CGFloat = 4.5
        let head: CGFloat = 2.6
        let c = NSPoint(x: zone.midX.rounded(), y: zone.midY.rounded())

        switch axis {
        case .horizontal:
            path.move(to: NSPoint(x: c.x - reach, y: c.y))
            path.line(to: NSPoint(x: c.x + reach, y: c.y))
            for direction in [CGFloat(-1), 1] {
                let tip = NSPoint(x: c.x + direction * reach, y: c.y)
                path.move(to: NSPoint(x: tip.x - direction * head, y: tip.y + head))
                path.line(to: tip)
                path.line(to: NSPoint(x: tip.x - direction * head, y: tip.y - head))
            }
        case .vertical:
            path.move(to: NSPoint(x: c.x, y: c.y - reach))
            path.line(to: NSPoint(x: c.x, y: c.y + reach))
            for direction in [CGFloat(-1), 1] {
                let tip = NSPoint(x: c.x, y: c.y + direction * reach)
                path.move(to: NSPoint(x: tip.x + head, y: tip.y - direction * head))
                path.line(to: tip)
                path.line(to: NSPoint(x: tip.x - head, y: tip.y - direction * head))
            }
        }
        ink.withAlphaComponent(0.9).setStroke()
        path.stroke()
    }

    /// Grip dots at the far end, hinting that the ruler can be resized there.
    private func drawGrip(ink: NSColor, highlighted: Bool = false) {
        if highlighted { return }   // the arrows replace the dots while hovering
        let color = ink.withAlphaComponent(0.35)
        color.setFill()
        let dot: CGFloat = 2
        for i in 0..<3 {
            let off = CGFloat(i) * 4
            let rect: NSRect
            switch axis {
            case .horizontal:
                rect = NSRect(x: bounds.maxX - 6 - off, y: bounds.midY - dot / 2, width: dot, height: dot)
            case .vertical:
                rect = NSRect(x: bounds.midX - dot / 2, y: bounds.minY + 4 + off, width: dot, height: dot)
            }
            NSBezierPath(ovalIn: rect).fill()
        }
    }

    /// Highlights the part of the ruler covered by an in-progress measurement.
    private func drawMeasureBand(_ span: ClosedRange<CGFloat>) {
        let a = position(forDistance: span.lowerBound)
        let b = position(forDistance: span.upperBound)
        let rect: NSRect
        switch axis {
        case .horizontal:
            rect = NSRect(x: min(a, b), y: bounds.minY, width: abs(b - a), height: bounds.height)
        case .vertical:
            rect = NSRect(x: bounds.minX, y: min(a, b), width: bounds.width, height: abs(b - a))
        }
        Palette.live.withAlphaComponent(0.22).setFill()
        rect.fill()

        let edges = NSBezierPath()
        edges.lineWidth = 1
        switch axis {
        case .horizontal:
            for x in [rect.minX, rect.maxX] {
                edges.move(to: NSPoint(x: x.rounded() + 0.5, y: bounds.minY))
                edges.line(to: NSPoint(x: x.rounded() + 0.5, y: bounds.maxY))
            }
        case .vertical:
            for y in [rect.minY, rect.maxY] {
                edges.move(to: NSPoint(x: bounds.minX, y: y.rounded() + 0.5))
                edges.line(to: NSPoint(x: bounds.maxX, y: y.rounded() + 0.5))
            }
        }
        Palette.live.withAlphaComponent(0.7).setStroke()
        edges.stroke()
    }

    private func drawCursor(at d: CGFloat, accent: NSColor) {
        let p = (position(forDistance: d)).rounded() + 0.5
        let line = NSBezierPath()
        line.lineWidth = 1
        switch axis {
        case .horizontal:
            line.move(to: NSPoint(x: p, y: bounds.minY))
            line.line(to: NSPoint(x: p, y: bounds.maxY))
        case .vertical:
            line.move(to: NSPoint(x: bounds.minX, y: p))
            line.line(to: NSPoint(x: bounds.maxX, y: p))
        }
        accent.setStroke()
        line.stroke()

        // Readout badge
        let value = Int(displayValue(atDistance: d).rounded())
        let string = NSAttributedString(string: "\(value)", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: NSColor.white,
        ])
        let size = string.size()
        let padX: CGFloat = 4, padY: CGFloat = 1.5
        var badge = NSRect(x: 0, y: 0, width: size.width + padX * 2, height: size.height + padY * 2)

        switch axis {
        case .horizontal:
            badge.origin.y = bounds.maxY - badge.height - 2
            badge.origin.x = p + 3
            if badge.maxX > bounds.maxX - 2 { badge.origin.x = p - 3 - badge.width }
        case .vertical:
            badge.origin.x = bounds.minX + 2
            badge.origin.y = p + 3
            if badge.maxY > bounds.maxY - 2 { badge.origin.y = p - 3 - badge.height }
        }
        badge.origin.x = min(max(badge.origin.x, bounds.minX + 2), bounds.maxX - badge.width - 2)
        badge.origin.y = min(max(badge.origin.y, bounds.minY + 2), bounds.maxY - badge.height - 2)

        accent.setFill()
        NSBezierPath(roundedRect: badge, xRadius: 3, yRadius: 3).fill()
        string.draw(at: NSPoint(x: badge.minX + padX, y: badge.minY + padY))
    }

    // MARK: - Interaction

    private func isInResizeZone(_ p: NSPoint) -> Bool {
        switch axis {
        case .horizontal: return p.x > bounds.maxX - resizeZone
        case .vertical: return p.y < bounds.minY + resizeZone
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        setHover(convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        setHover(convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        setHover(nil)
    }

    private func setHover(_ point: NSPoint?) {
        let hovering = point.map(isInResizeZone) ?? false
        if hovering != resizeHover {
            resizeHover = hovering
            needsDisplay = true
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        switch axis {
        case .horizontal:
            addCursorRect(NSRect(x: bounds.maxX - resizeZone, y: bounds.minY,
                                 width: resizeZone, height: bounds.height),
                          cursor: .resizeLeftRight)
        case .vertical:
            addCursorRect(NSRect(x: bounds.minX, y: bounds.minY,
                                 width: bounds.width, height: resizeZone),
                          cursor: .resizeUpDown)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let p = convert(event.locationInWindow, from: nil)

        if event.clickCount == 2 {
            // Double-click sets the zero mark where you clicked.
            Settings.shared.setZeroOffset(distance(forViewPoint: p), for: axis)
            needsDisplay = true
            return
        }

        if event.modifierFlags.contains(.option) {
            // Pull a fixed guide out of the ruler, Photoshop style: the guide
            // runs parallel to the ruler it came from.
            dragMode = .guideOut
            pendingGuide = GuideManager.shared.add(orientation: axis, at: NSEvent.mouseLocation)
            return
        }

        if isInResizeZone(p) {
            dragMode = .resize
            dragStartMouse = NSEvent.mouseLocation
            dragStartFrame = window.frame
        } else {
            dragMode = .none
            window.performDrag(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if dragMode == .guideOut {
            pendingGuide?.move(to: NSEvent.mouseLocation)
            return
        }
        guard dragMode == .resize, let window else { return }
        let now = NSEvent.mouseLocation
        let minLength: CGFloat = 120

        switch axis {
        case .horizontal:
            let w = max(minLength, dragStartFrame.width + (now.x - dragStartMouse.x))
            window.setFrame(NSRect(x: dragStartFrame.minX, y: dragStartFrame.minY,
                                   width: w, height: dragStartFrame.height), display: true)
        case .vertical:
            let h = max(minLength, dragStartFrame.height - (now.y - dragStartMouse.y))
            window.setFrame(NSRect(x: dragStartFrame.minX, y: dragStartFrame.maxY - h,
                                   width: dragStartFrame.width, height: h), display: true)
        }
    }

    override func mouseUp(with event: NSEvent) {
        setHover(convert(event.locationInWindow, from: nil))
        if dragMode == .guideOut {
            GuideManager.shared.save()
            pendingGuide = nil
        }
        dragMode = .none
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let p = convert(event.locationInWindow, from: nil)
        let d = distance(forViewPoint: p)
        let menu = NSMenu()

        let setZero = NSMenuItem(title: "Set Zero Here", action: #selector(setZeroHere(_:)), keyEquivalent: "")
        setZero.target = self
        setZero.representedObject = NSNumber(value: Double(d))
        menu.addItem(setZero)

        let reset = NSMenuItem(title: "Reset Zero", action: #selector(resetZero(_:)), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())

        let cross = NSMenuItem(title: "Add Cross Guide Here", action: #selector(addCrossGuide(_:)), keyEquivalent: "")
        cross.target = self
        cross.representedObject = NSValue(point: window?.convertPoint(toScreen: event.locationInWindow) ?? .zero)
        menu.addItem(cross)

        let clear = NSMenuItem(title: "Clear All Guides", action: #selector(clearGuides), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        menu.addItem(.separator())

        let hide = NSMenuItem(title: axis == .horizontal ? "Hide Horizontal Ruler" : "Hide Vertical Ruler",
                              action: #selector(hideRuler(_:)), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Distanser Controls…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit Distanser", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func setZeroHere(_ sender: NSMenuItem) {
        guard let n = sender.representedObject as? NSNumber else { return }
        Settings.shared.setZeroOffset(CGFloat(n.doubleValue), for: axis)
        needsDisplay = true
    }

    @objc private func resetZero(_ sender: Any?) {
        Settings.shared.setZeroOffset(0, for: axis)
        needsDisplay = true
    }

    /// A guide crossing this ruler, marking the value under the click.
    @objc private func addCrossGuide(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? NSValue else { return }
        GuideManager.shared.add(orientation: axis == .horizontal ? .vertical : .horizontal,
                                at: value.pointValue)
    }

    @objc private func clearGuides() {
        GuideManager.shared.clear()
    }

    @objc private func hideRuler(_ sender: Any?) {
        if axis == .horizontal {
            Settings.shared.showHorizontal = false
        } else {
            Settings.shared.showVertical = false
        }
    }

    @objc private func showSettings() {
        ControlWindowController.shared.show()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
