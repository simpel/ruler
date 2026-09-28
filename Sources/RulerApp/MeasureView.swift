import AppKit

/// View representing a measurement shape, its outline, and its interactive readout badge.
final class MeasureView: NSView {

    weak var owner: MeasurementWindow?
    var shapeType: ShapeType = .rectangle
    var anchor: NSPoint?
    var current: NSPoint = .zero
    var scale: CGFloat = 1
    /// Zero origin of the rulers, in this view's coordinates.
    var screenOrigin: NSPoint = .zero
    /// Top-left corner of the display screen, in this view's coordinates.
    var displayScreenOrigin: NSPoint = .zero

    /// Usable screen frame (excluding menu bar and dock) expressed in this view's coordinate space.
    var visibleScreenRectInView: NSRect? {
        let win = window ?? owner
        guard let win else { return nil }
        let scr = win.screen
            ?? NSScreen.screens.first { $0.frame.intersects(win.frame) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let scr else { return nil }
        let vf = scr.visibleFrame
        return NSRect(x: vf.minX - win.frame.minX,
                      y: vf.minY - win.frame.minY,
                      width: vf.width,
                      height: vf.height)
    }

    /// Kept measurements carry action buttons (move, edit, close); live drawing does not.
    var showsClose = false
    var onClose: (() -> Void)?
    var onEdit: (() -> Void)?

    var closeHot = false {
        didSet { if oldValue != closeHot { needsDisplay = true } }
    }
    var editHot = false {
        didSet { if oldValue != editHot { needsDisplay = true } }
    }
    var moveHot = false {
        didSet { if oldValue != moveHot { needsDisplay = true } }
    }
    var centerMoveHot = false {
        didSet { if oldValue != centerMoveHot { needsDisplay = true } }
    }
    var tooltipHot = false {
        didSet { if oldValue != tooltipHot { needsDisplay = true } }
    }
    var outlineHot = false {
        didSet { if oldValue != outlineHot { needsDisplay = true } }
    }
    var hoveredDot: ResizeDotKind? {
        didSet { if oldValue != hoveredDot { needsDisplay = true } }
    }

    /// Where action buttons and badge components were last drawn, in view coordinates.
    private(set) var closeRect: NSRect?
    private(set) var editRect: NSRect?
    private(set) var moveRect: NSRect?
    private(set) var centerMoveRect: NSRect?
    private(set) var badgeRect: NSRect?
    private(set) var metricHits: [MetricHitTarget] = []
    private(set) var activeDots: [ResizeDot] = []
    private(set) var shapeBox: NSRect = .zero

    var isInteracting: Bool {
        isDragging || isScrubbing || isResizingDot
    }

    // Dragging shape state
    var isDragging = false
    var dragStartMouse: NSPoint = .zero
    var dragStartAnchor: NSPoint = .zero
    var dragStartCurrent: NSPoint = .zero

    // Resizing shape via dot state
    var isResizingDot = false
    var activeResizeDot: ResizeDotKind?
    var dotDragStartMouse: NSPoint = .zero
    var dotDragStartAnchor: NSPoint = .zero
    var dotDragStartCurrent: NSPoint = .zero

    func resizeDot(at point: NSPoint) -> ResizeDot? {
        guard showsClose else { return nil }
        return activeDots.first { $0.hitRect.contains(point) }
    }

    // Scrubbing metric state
    var isScrubbing = false
    var activeMetric: BadgeMetric?
    var scrubStartMouse: NSPoint = .zero
    var scrubStartAnchor: NSPoint = .zero
    var scrubStartCurrent: NSPoint = .zero
    var trackingArea: NSTrackingArea?

    override var isOpaque: Bool { false }

    /// Computes the exact perimeter/circumference of an ellipse (or circle) using Ramanujan's formula.
    static func ellipseCircumference(width: CGFloat, height: CGFloat) -> CGFloat {
        ShapeType.ellipseCircumference(width: width, height: height)
    }

    func isOverOutline(_ localPoint: NSPoint) -> Bool {
        if shapeType == .line, let a = anchor {
            return ShapeType.distanceToSegment(p: localPoint, a: a, b: current) <= 8.0
        }
        return shapeType.isPointOnOutline(localPoint, in: shapeBox)
    }

    override func draw(_ dirtyRect: NSRect) {
        if let a = anchor {
            switch shapeType {
            case .circle:
                drawCircleMeasurement(from: a, to: current)
            case .line:
                drawLineMeasurement(from: a, to: current)
            case .rectangle:
                drawRectangleMeasurement(from: a, to: current)
            }
        } else {
            activeDots = []
            centerMoveRect = nil
            let x = (current.x - screenOrigin.x) * scale
            let y = (screenOrigin.y - current.y) * scale
            let layout = ReadoutBadge.draw(shapeType: nil,
                                           showsActions: false,
                                           posX: x,
                                           posY: y,
                                           in: bounds,
                                           near: current,
                                           screenVisibleRect: visibleScreenRectInView)
            badgeRect = layout.badgeRect
            closeRect = nil
            editRect = nil
            moveRect = nil
            metricHits = []
        }
    }

    private func drawLineMeasurement(from a: NSPoint, to b: NSPoint) {
        let box = NSRect(x: min(a.x, b.x), y: min(a.y, b.y),
                         width: abs(a.x - b.x), height: abs(a.y - b.y))
        shapeBox = box

        if outlineHot {
            let boxPath = NSBezierPath(rect: box)
            boxPath.lineWidth = 1
            boxPath.setLineDash([3, 3], count: 2, phase: 0)
            Palette.live.withAlphaComponent(0.3).setStroke()
            boxPath.stroke()
        }

        let line = NSBezierPath()
        line.lineWidth = outlineHot ? 2.5 : 2.0
        line.lineCapStyle = .round
        line.move(to: a)
        line.line(to: b)
        Palette.live.setStroke()
        line.stroke()

        let center = NSPoint(x: (a.x + b.x) / 2.0, y: (a.y + b.y) / 2.0)
        ShapeCenterHandle.draw(at: center)

        if showsClose {
            let chBox = NSRect(x: center.x - 9, y: center.y - 9, width: 18, height: 18)
            centerMoveRect = ShapeCenterHandle.hitRect(for: chBox)
        } else {
            centerMoveRect = nil
        }

        let dots = ShapeResizeHandle.dots(shapeType: .line, anchor: a, current: b, box: box)
        activeDots = dots
        for dot in dots {
            let isHovered = showsClose && (hoveredDot == dot.kind)
            ShapeResizeHandle.drawDot(at: dot.point, isHovered: isHovered)
        }

        let posX = (box.minX - screenOrigin.x) * scale
        let posY = (screenOrigin.y - box.maxY) * scale
        let scrX = showsClose ? (box.minX - displayScreenOrigin.x) * scale : nil
        let scrY = showsClose ? (displayScreenOrigin.y - box.maxY) * scale : nil
        let width = box.width * scale
        let height = box.height * scale
        let length = hypot(b.x - a.x, b.y - a.y) * scale

        let layout = ReadoutBadge.draw(shapeType: .line,
                                       showsActions: showsClose,
                                       posX: posX,
                                       posY: posY,
                                       screenX: scrX,
                                       screenY: scrY,
                                       width: width,
                                       height: height,
                                       length: length,
                                       in: bounds,
                                       forShapeBox: box,
                                       screenVisibleRect: visibleScreenRectInView,
                                       isHovered: tooltipHot,
                                       moveHot: moveHot,
                                       editHot: editHot,
                                       closeHot: closeHot,
                                       activeMetric: activeMetric)
        badgeRect = layout.badgeRect
        closeRect = layout.closeRect
        editRect = layout.editRect
        moveRect = layout.moveRect
        metricHits = layout.metricHits
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

        let dots = ShapeResizeHandle.dots(shapeType: .rectangle, anchor: a, current: b, box: box)
        activeDots = dots
        for dot in dots {
            let isHovered = showsClose && (hoveredDot == dot.kind)
            ShapeResizeHandle.drawDot(at: dot.point, isHovered: isHovered)
        }

        // Center cross mark
        let center = NSPoint(x: box.midX, y: box.midY)
        ShapeCenterHandle.draw(at: center)

        if showsClose {
            centerMoveRect = ShapeCenterHandle.hitRect(for: box)
        } else {
            centerMoveRect = nil
        }

        let posX = (box.minX - screenOrigin.x) * scale
        let posY = (screenOrigin.y - box.maxY) * scale
        let scrX = showsClose ? (box.minX - displayScreenOrigin.x) * scale : nil
        let scrY = showsClose ? (displayScreenOrigin.y - box.maxY) * scale : nil
        let width = box.width * scale
        let height = box.height * scale

        let layout = ReadoutBadge.draw(shapeType: .rectangle,
                                       showsActions: showsClose,
                                       posX: posX,
                                       posY: posY,
                                       screenX: scrX,
                                       screenY: scrY,
                                       width: width,
                                       height: height,
                                       in: bounds,
                                       forShapeBox: box,
                                       screenVisibleRect: visibleScreenRectInView,
                                       isHovered: tooltipHot,
                                       moveHot: moveHot,
                                       editHot: editHot,
                                       closeHot: closeHot,
                                       activeMetric: activeMetric)
        badgeRect = layout.badgeRect
        closeRect = layout.closeRect
        editRect = layout.editRect
        moveRect = layout.moveRect
        metricHits = layout.metricHits
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

        // Center cross mark
        let center = NSPoint(x: box.midX, y: box.midY)
        ShapeCenterHandle.draw(at: center)

        if showsClose {
            centerMoveRect = ShapeCenterHandle.hitRect(for: box)
        } else {
            centerMoveRect = nil
        }

        let dots = ShapeResizeHandle.dots(shapeType: .circle, anchor: a, current: b, box: box)
        activeDots = dots
        for dot in dots {
            let isHovered = showsClose && (hoveredDot == dot.kind)
            ShapeResizeHandle.drawDot(at: dot.point, isHovered: isHovered)
        }

        let posX = (box.minX - screenOrigin.x) * scale
        let posY = (screenOrigin.y - box.maxY) * scale
        let scrX = showsClose ? (box.minX - displayScreenOrigin.x) * scale : nil
        let scrY = showsClose ? (displayScreenOrigin.y - box.maxY) * scale : nil
        let width = box.width * scale
        let height = box.height * scale
        let radius = (width + height) / 4.0
        let circumference = MeasureView.ellipseCircumference(width: width, height: height)

        let isActualCircle = abs(width - height) < 1.0
        let showDims = !isActualCircle

        let layout = ReadoutBadge.draw(shapeType: .circle,
                                       showsActions: showsClose,
                                       posX: posX,
                                       posY: posY,
                                       screenX: scrX,
                                       screenY: scrY,
                                       width: showDims ? width : nil,
                                       height: showDims ? height : nil,
                                       radius: radius,
                                       circumference: circumference,
                                       in: bounds,
                                       forShapeBox: box,
                                       screenVisibleRect: visibleScreenRectInView,
                                       isHovered: tooltipHot,
                                       moveHot: moveHot,
                                       editHot: editHot,
                                       closeHot: closeHot,
                                       activeMetric: activeMetric)
        badgeRect = layout.badgeRect
        closeRect = layout.closeRect
        editRect = layout.editRect
        moveRect = layout.moveRect
        metricHits = layout.metricHits
    }
}
