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
        case slideZero(initialOffset: CGFloat, startMousePos: NSPoint, isDragging: Bool)
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

        // 1. Command gestures: Command-drag moves zero point, Command-click creates/toggles a marker
        if event.modifierFlags.contains(.command) {
            let initialOffset = Settings.shared.zeroOffset(for: axis)
            rulerDragMode = .slideZero(initialOffset: initialOffset, startMousePos: NSEvent.mouseLocation, isDragging: false)
            return
        }

        // 2. Click in resize zone resizes the ruler length
        if isInResizeZone(p) {
            rulerDragMode = .resize
            dragStartMouse = NSEvent.mouseLocation
            dragStartFrame = window.frame
            return
        }

        // 3. Normal drag on a ruler moves it
        rulerDragMode = .moveWindow
        window.performDrag(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        let now = NSEvent.mouseLocation

        switch rulerDragMode {
        case .none, .moveWindow:
            break

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

        case .slideZero(let initialOffset, let startMousePos, var isDragging):
            let dist = hypot(now.x - startMousePos.x, now.y - startMousePos.y)
            if dist >= 3 {
                isDragging = true
                rulerDragMode = .slideZero(initialOffset: initialOffset, startMousePos: startMousePos, isDragging: true)
            }
            guard isDragging else { break }

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

    override func mouseUp(with event: NSEvent) {
        setHover(convert(event.locationInWindow, from: nil))

        if case .slideZero(_, let startMousePos, let isDragging) = rulerDragMode {
            if !isDragging {
                toggleGuide(at: startMousePos)
            }
        }

        rulerDragMode = .none
        needsDisplay = true
    }

    private func toggleGuide(at point: NSPoint) {
        let markerOrientation: RulerAxis = (axis == .horizontal ? .vertical : .horizontal)
        let hitGuides = GuideManager.shared.guidesNear(point: point, threshold: 16).filter {
            $0.orientation == markerOrientation
        }

        if !hitGuides.isEmpty {
            for g in hitGuides {
                GuideManager.shared.remove(g)
            }
        } else {
            GuideManager.shared.add(orientation: markerOrientation, at: point)
        }
        GuideManager.shared.save()
    }
}
