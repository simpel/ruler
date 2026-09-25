import AppKit

/// Manages full-screen transparent canvas panels across all displays to intercept
/// mouse events during active drawing mode, preventing clicks and drags from leaking
/// into underlying applications (such as Microsoft Word, browsers, etc.).
final class DrawingCanvasManager {

    static let shared = DrawingCanvasManager()

    private var panels: [DrawingCanvasPanel] = []
    private var escapeMonitor: Any?

    private init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    @objc private func screensChanged() {
        let wasActive = RulerController.shared.isContextActive
        rebuildPanels()
        if wasActive {
            show()
        }
    }

    private func rebuildPanels() {
        panels.forEach { $0.orderOut(nil) }
        panels = NSScreen.screens.map { DrawingCanvasPanel(screen: $0) }
    }

    func show() {
        if panels.isEmpty || panels.count != NSScreen.screens.count {
            rebuildPanels()
        } else {
            for (panel, screen) in zip(panels, NSScreen.screens) {
                if panel.frame != screen.frame {
                    panel.setFrame(screen.frame, display: false)
                }
            }
        }

        for panel in panels {
            panel.ignoresMouseEvents = false
            panel.orderFrontRegardless()
        }

        startEscapeMonitor()
    }

    func hide() {
        stopEscapeMonitor()
        for panel in panels {
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
        }
    }

    private func startEscapeMonitor() {
        stopEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 && RulerController.shared.isContextActive { // Escape
                RulerController.shared.deactivateContext()
                return nil
            }
            return event
        }
    }

    private func stopEscapeMonitor() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }
}

/// A transparent, non-activating panel covering an entire screen display.
final class DrawingCanvasPanel: NSPanel {

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
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
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        contentView = DrawingCanvasView()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// View hosting precision crosshair cursor and gesture tracking for drawing shapes.
final class DrawingCanvasView: NSView {

    private var dragStart: NSPoint?
    private var isDragging = false
    private let dragThreshold: CGFloat = 4.0
    private var trackingArea: NSTrackingArea?

    override var isOpaque: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .cursorUpdate],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let current = NSEvent.mouseLocation
        let dist = hypot(current.x - start.x, current.y - start.y)

        if dist >= dragThreshold {
            isDragging = true
            let constrain = event.modifierFlags.contains(.shift)
            let end = constrain ? RulerController.constrainSquareOrCircle(anchor: start, current: current) : current
            RulerController.shared.updateLiveMeasurement(anchor: start, current: end, shapeType: Settings.shared.drawShapeType)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let start = dragStart
        let wasDragging = isDragging
        dragStart = nil
        isDragging = false

        if wasDragging, let start {
            let current = NSEvent.mouseLocation
            let constrain = event.modifierFlags.contains(.shift)
            let end = constrain ? RulerController.constrainSquareOrCircle(anchor: start, current: current) : current
            if hypot(end.x - start.x, end.y - start.y) > 6 {
                MeasurementStore.shared.add(anchor: start, current: end, shapeType: Settings.shared.drawShapeType)
            }
            RulerController.shared.clearLiveMeasurement()
        } else {
            RulerController.shared.clearLiveMeasurement()
            if event.modifierFlags.contains(.option), let point = start {
                let hitGuides = GuideManager.shared.guidesNear(point: point, threshold: 12)
                if !hitGuides.isEmpty {
                    for g in hitGuides {
                        GuideManager.shared.remove(g)
                    }
                } else {
                    // Option-click places cross markers (both horizontal and vertical guides)
                    GuideManager.shared.add(orientation: .horizontal, at: point)
                    GuideManager.shared.add(orientation: .vertical, at: point)
                }
            } else {
                // Clicking on the screen without modifiers means "leaving" the app context.
                RulerController.shared.deactivateContext()
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            RulerController.shared.clearLiveMeasurement()
            RulerController.shared.deactivateContext()
        } else {
            super.keyDown(with: event)
        }
    }
}
