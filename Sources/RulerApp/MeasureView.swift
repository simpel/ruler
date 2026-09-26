import AppKit

/// View representing a measurement shape, its outline, and its interactive readout badge.
final class MeasureView: NSView {

    weak var owner: MeasurementWindow?
    var shapeType: ShapeType = .rectangle
    var anchor: NSPoint?
    var current: NSPoint = .zero
    var scale: CGFloat = 1
    /// Top-left corner of the pointer's screen, in this view's coordinates.
    var screenOrigin: NSPoint = .zero

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
            activeDots = []
            centerMoveRect = nil
            let x = (current.x - screenOrigin.x) * scale
            let y = (screenOrigin.y - current.y) * scale
            let layout = ReadoutBadge.draw(shapeType: nil,
                                           showsActions: false,
                                           posX: x,
                                           posY: y,
                                           in: bounds,
                                           near: current)
            badgeRect = layout.badgeRect
            closeRect = nil
            editRect = nil
            moveRect = nil
            metricHits = []
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
        let width = box.width * scale
        let height = box.height * scale

        let layout = ReadoutBadge.draw(shapeType: .rectangle,
                                       showsActions: showsClose,
                                       posX: posX,
                                       posY: posY,
                                       width: width,
                                       height: height,
                                       in: bounds,
                                       forShapeBox: box,
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
        let width = box.width * scale
        let height = box.height * scale
        let radius = (width + height) / 4.0
        let circumference = MeasureView.ellipseCircumference(width: width, height: height)

        let layout = ReadoutBadge.draw(shapeType: .circle,
                                       showsActions: showsClose,
                                       posX: posX,
                                       posY: posY,
                                       width: width,
                                       height: height,
                                       radius: radius,
                                       circumference: circumference,
                                       in: bounds,
                                       forShapeBox: box,
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
