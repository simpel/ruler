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
    var tooltipHot = false {
        didSet { if oldValue != tooltipHot { needsDisplay = true } }
    }
    var outlineHot = false {
        didSet { if oldValue != outlineHot { needsDisplay = true } }
    }

    /// Where action buttons and badge components were last drawn, in view coordinates.
    private(set) var closeRect: NSRect?
    private(set) var editRect: NSRect?
    private(set) var moveRect: NSRect?
    private(set) var badgeRect: NSRect?
    private(set) var metricHits: [MetricHitTarget] = []
    private(set) var shapeBox: NSRect = .zero

    // Dragging shape state
    private var isDragging = false
    private var dragStartMouse: NSPoint = .zero
    private var dragStartAnchor: NSPoint = .zero
    private var dragStartCurrent: NSPoint = .zero

    // Scrubbing metric state
    private var isScrubbing = false
    private var activeMetric: BadgeMetric?
    private var scrubStartMouse: NSPoint = .zero
    private var scrubStartAnchor: NSPoint = .zero
    private var scrubStartCurrent: NSPoint = .zero

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

        for p in [a, b] {
            let dot = NSRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)
            Palette.live.setFill()
            NSBezierPath(ovalIn: dot).fill()
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

    override func resetCursorRects() {
        super.resetCursorRects()
        guard showsClose else { return }

        if let closeRect {
            addCursorRect(closeRect, cursor: .pointingHand)
        }
        if let editRect {
            addCursorRect(editRect, cursor: .pointingHand)
        }
        if let moveRect {
            addCursorRect(moveRect, cursor: .openHand)
        }
        for hit in metricHits {
            addCursorRect(hit.rect, cursor: .resizeLeftRight)
        }
        if let badgeRect {
            addCursorRect(badgeRect, cursor: .arrow)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)

        // 1. Close button
        if let closeRect, closeRect.insetBy(dx: -4, dy: -4).contains(loc) {
            onClose?()
            return
        }

        // 2. Edit button
        if let editRect, editRect.insetBy(dx: -4, dy: -4).contains(loc) {
            onEdit?()
            return
        }

        // 3. Number hit testing: double click opens settings, single click/drag scrubs
        if let hit = metricHits.first(where: { $0.rect.contains(loc) }) {
            if event.clickCount == 2 {
                onEdit?()
                return
            }
            startScrub(metric: hit.metric)
            return
        }

        // 4. Move button
        if let moveRect, moveRect.insetBy(dx: -4, dy: -4).contains(loc) {
            startDrag()
            return
        }

        // 5. Badge background or outline
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

    private func startScrub(metric: BadgeMetric) {
        guard let owner else { return }
        isScrubbing = true
        activeMetric = metric
        scrubStartMouse = NSEvent.mouseLocation
        scrubStartAnchor = owner.anchor
        scrubStartCurrent = owner.current
        NSCursor.resizeLeftRight.push()
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        if isScrubbing, let owner, let metric = activeMetric {
            let mouse = NSEvent.mouseLocation
            let stepMultiplier: CGFloat = event.modifierFlags.contains(.shift) ? 10.0 : 1.0
            let rawDelta = (mouse.x - scrubStartMouse.x) * stepMultiplier
            let delta = (rawDelta / scale).rounded()

            let anchor = scrubStartAnchor
            let current = scrubStartCurrent
            let minX = min(anchor.x, current.x)
            let maxX = max(anchor.x, current.x)
            let minY = min(anchor.y, current.y)
            let maxY = max(anchor.y, current.y)
            let origWidth = maxX - minX
            let origHeight = maxY - minY

            var newAnchor = anchor
            var newCurrent = current

            switch metric {
            case .width:
                let newW = max(5, origWidth + delta)
                if current.x >= anchor.x {
                    newAnchor.x = minX
                    newCurrent.x = minX + newW
                } else {
                    newAnchor.x = minX + newW
                    newCurrent.x = minX
                }
            case .height:
                let newH = max(5, origHeight + delta)
                if current.y >= anchor.y {
                    newAnchor.y = minY
                    newCurrent.y = minY + newH
                } else {
                    newAnchor.y = minY + newH
                    newCurrent.y = minY
                }
            case .radius:
                let origRadius = (origWidth + origHeight) / 4.0
                let newRadius = max(3, origRadius + delta)
                let midX = (anchor.x + current.x) / 2.0
                let midY = (anchor.y + current.y) / 2.0
                newAnchor = NSPoint(x: (midX - newRadius).rounded(), y: (midY - newRadius).rounded())
                newCurrent = NSPoint(x: (midX + newRadius).rounded(), y: (midY + newRadius).rounded())
            case .circumference:
                let origRadius = (origWidth + origHeight) / 4.0
                let origCirc = 2.0 * CGFloat.pi * origRadius
                let newCirc = max(18, origCirc + delta)
                let newRadius = newCirc / (2.0 * CGFloat.pi)
                let midX = (anchor.x + current.x) / 2.0
                let midY = (anchor.y + current.y) / 2.0
                newAnchor = NSPoint(x: (midX - newRadius).rounded(), y: (midY - newRadius).rounded())
                newCurrent = NSPoint(x: (midX + newRadius).rounded(), y: (midY + newRadius).rounded())
            case .x:
                newAnchor.x = anchor.x + delta
                newCurrent.x = current.x + delta
            case .y:
                // Dragging right increases displayed posY (distance from top), moving shape down
                newAnchor.y = anchor.y - delta
                newCurrent.y = current.y - delta
            }

            owner.move(toAnchor: newAnchor, current: newCurrent)
            ShapeEditDialogController.shared.syncIfActive(for: owner)
            return
        }

        if isDragging, let owner {
            let mouse = NSEvent.mouseLocation
            let dx = mouse.x - dragStartMouse.x
            let dy = mouse.y - dragStartMouse.y
            owner.move(toAnchor: NSPoint(x: (dragStartAnchor.x + dx).rounded(), y: (dragStartAnchor.y + dy).rounded()),
                       current: NSPoint(x: (dragStartCurrent.x + dx).rounded(), y: (dragStartCurrent.y + dy).rounded()))
            ShapeEditDialogController.shared.syncIfActive(for: owner)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isScrubbing {
            isScrubbing = false
            activeMetric = nil
            NSCursor.pop()
            needsDisplay = true
        }
        if isDragging {
            isDragging = false
            NSCursor.pop()
        }
    }
}
