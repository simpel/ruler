import AppKit

/// Draws the ruler face: tick marks, numeric labels, and the live cursor line.
final class RulerView: NSView {

    // MARK: Layout constants
    static let thickness: CGFloat = 34
    let cornerRadius: CGFloat = 6
    let resizeZone: CGFloat = 16

    let minorStep: CGFloat = 10     // in display units
    let midStep: CGFloat = 50
    let majorStep: CGFloat = 100

    let minorLen: CGFloat = 4
    let midLen: CGFloat = 8
    let majorLen: CGFloat = 13

    let axis: RulerAxis

    var isContextActive: Bool = false {
        didSet { if oldValue != isContextActive { needsDisplay = true } }
    }

    /// Distance (points) from the ruler's start to the cursor, or nil when off-ruler.
    var cursorDistance: CGFloat? {
        didSet { if oldValue != cursorDistance { needsDisplay = true } }
    }

    /// Span of an active measurement, in distances along this ruler.
    var measureSpan: ClosedRange<CGFloat>? {
        didSet { if oldValue != measureSpan { needsDisplay = true } }
    }

    enum RulerDragMode {
        case none
        case resize
        case moveWindow
        case slideZero(initialOffset: CGFloat, startMousePos: NSPoint)
        case guideOut(guide: GuideWindow, initialOffset: CGFloat)
    }

    private var rulerDragMode: RulerDragMode = .none
    var isResizing: Bool {
        if case .resize = rulerDragMode { return true }
        return false
    }

    var resizeHover = false
    private var trackingArea: NSTrackingArea?
    private var dragStartMouse: NSPoint = .zero
    private var dragStartFrame: NSRect = .zero

    init(axis: RulerAxis) {
        self.axis = axis
        super.init(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    // MARK: - Geometry helpers

    /// Length of the ruler along its measuring axis, in points.
    var length: CGFloat {
        axis == .horizontal ? bounds.width : bounds.height
    }

    /// Points-per-display-unit: 1 for logical points, 1/scale for device pixels.
    var pointsPerUnit: CGFloat {
        Settings.shared.devicePixels ? 1.0 / (window?.backingScaleFactor ?? 2.0) : 1.0
    }

    var zeroOffset: CGFloat {
        Settings.shared.zeroOffset(for: axis)
    }

    /// Converts a distance along the ruler (points from its start) into a view point.
    func position(forDistance d: CGFloat) -> CGFloat {
        axis == .horizontal ? bounds.minX + d : bounds.maxY - d
    }

    /// Converts a point inside the view into a distance along the ruler.
    func distance(forViewPoint p: NSPoint) -> CGFloat {
        axis == .horizontal ? p.x - bounds.minX : bounds.maxY - p.y
    }

    func displayValue(atDistance d: CGFloat) -> CGFloat {
        (d - zeroOffset) / pointsPerUnit
    }

    // MARK: - Drawing

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        drawFace(in: dirtyRect)
    }

    // MARK: - Interaction

    func isInResizeZone(_ p: NSPoint) -> Bool {
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

    func setHover(_ point: NSPoint?) {
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
        RulerController.shared.activateContext()
        let p = convert(event.locationInWindow, from: nil)

        // 1. Command-click on ruler toggles a guide directly at this coordinate
        if event.modifierFlags.contains(.command) {
            let nearbyGuides = GuideManager.shared.guidesNear(point: NSEvent.mouseLocation, threshold: max(16, RulerView.thickness / 2))
            let guidesOnThisRuler = GuideManager.shared.guides.filter { guide in
                guard guide.orientation == axis else { return false }
                guard guide.windowNumber != window.windowNumber else { return false }
                return guide.frame.intersects(window.frame.insetBy(dx: -4, dy: -4))
            }

            let guidesToRemove = Set(nearbyGuides).union(guidesOnThisRuler)
            if !guidesToRemove.isEmpty {
                for g in guidesToRemove {
                    GuideManager.shared.remove(g)
                }
            } else {
                GuideManager.shared.add(orientation: axis, at: NSEvent.mouseLocation)
            }
            GuideManager.shared.save()
            rulerDragMode = .none
            needsDisplay = true
            return
        }

        // 2. Shift-drag repositions the ruler window
        if event.modifierFlags.contains(.shift) {
            rulerDragMode = .moveWindow
            window.performDrag(with: event)
            return
        }

        // 3. Click in resize zone resizes the ruler length
        if isInResizeZone(p) {
            rulerDragMode = .resize
            dragStartMouse = NSEvent.mouseLocation
            dragStartFrame = window.frame
            return
        }

        // 4. Normal drag start: records position to slide zero or drag out a guide
        let initialOffset = Settings.shared.zeroOffset(for: axis)
        rulerDragMode = .slideZero(initialOffset: initialOffset, startMousePos: NSEvent.mouseLocation)
    }

    override func mouseDragged(with event: NSEvent) {
        let now = NSEvent.mouseLocation

        switch rulerDragMode {
        case .none, .moveWindow:
            break

        case .guideOut(let guide, _):
            guide.move(to: now)

        case .resize:
            guard let window else { return }
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

        case .slideZero(let initialOffset, let startMousePos):
            let localPoint = convert(event.locationInWindow, from: nil)
            let outThreshold: CGFloat = 4.0
            let isDraggedOut: Bool
            switch axis {
            case .horizontal:
                isDraggedOut = localPoint.y < -outThreshold || localPoint.y > bounds.height + outThreshold
            case .vertical:
                isDraggedOut = localPoint.x < -outThreshold || localPoint.x > bounds.width + outThreshold
            }

            if isDraggedOut {
                // Dragged out perpendicular to the ruler: create and pull out a guide!
                Settings.shared.setZeroOffset(initialOffset, for: axis)
                needsDisplay = true

                let guide = GuideManager.shared.add(orientation: axis, at: now)
                rulerDragMode = .guideOut(guide: guide, initialOffset: initialOffset)
            } else {
                // Dragging along the ruler axis: move the zero position for this ruler
                switch axis {
                case .horizontal:
                    let delta = now.x - startMousePos.x
                    Settings.shared.setZeroOffset(initialOffset + delta, for: axis)
                case .vertical:
                    let delta = startMousePos.y - now.y
                    Settings.shared.setZeroOffset(initialOffset + delta, for: axis)
                }
                needsDisplay = true
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        setHover(convert(event.locationInWindow, from: nil))
        if case .guideOut = rulerDragMode {
            GuideManager.shared.save()
        }
        rulerDragMode = .none
        needsDisplay = true
    }
}
