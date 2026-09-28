import AppKit

/// Owns the rulers, the crosshair, the measuring overlay and the guides, and
/// drives them all from one 60 Hz pointer poll.
final class RulerController {

    static let shared = RulerController()

    private let horizontal = RulerPanel(axis: .horizontal)
    private let vertical = RulerPanel(axis: .vertical)

    private let crosshairH = HairlineWindow(orientation: .horizontal)
    private let crosshairV = HairlineWindow(orientation: .vertical)
    private let measureOverlay = MeasureOverlayWindow()

    private var timer: Timer?

    // Poll state
    private var lastMouse: NSPoint = .zero

    private(set) var isContextActive: Bool = false

    var isAppInFocus: Bool {
        isContextActive || NSApp.isActive
    }

    var panels: [RulerPanel] { [horizontal, vertical] }

    func activateContext() {
        isContextActive = true
        for panel in panels {
            panel.rulerView.isContextActive = true
        }
        DrawingCanvasManager.shared.show()
        updateCrosshairOpacity()
        NotificationCenter.default.post(name: .rulerContextChanged, object: nil)
    }

    func deactivateContext() {
        guard isContextActive else { return }
        isContextActive = false
        for panel in panels {
            panel.rulerView.isContextActive = false
        }
        DrawingCanvasManager.shared.hide()
        clearLiveMeasurement()
        updateCrosshairOpacity()
        NotificationCenter.default.post(name: .rulerContextChanged, object: nil)
    }

    func start() {
        GuideManager.shared.labelProvider = { [weak self] guide in
            self?.label(for: guide)
        }
        GuideManager.shared.restore()

        applySettings()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applySettings),
                                               name: .rulerSettingsChanged,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationStateChanged),
                                               name: NSApplication.didResignActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationStateChanged),
                                               name: NSApplication.didBecomeActiveNotification,
                                               object: nil)

        // Polling gives us pointer position, buttons and modifiers without an
        // event tap, so no accessibility permission is needed and we never
        // intercept anyone else's clicks.
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        t.tolerance = 1.0 / 120.0
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func applicationStateChanged() {
        updateCrosshairOpacity()
    }

    // MARK: - Settings

    @objc func applySettings() {
        let s = Settings.shared

        setVisible(s.showHorizontal, panel: horizontal)
        setVisible(s.showVertical, panel: vertical)

        for panel in panels {
            panel.alphaValue = CGFloat(s.opacity)
            panel.ignoresMouseEvents = s.clickThrough
            panel.rulerView.needsDisplay = true
        }

        updateCrosshairOpacity()

        GuideManager.shared.applySettings()
        MeasurementStore.shared.applySettings()
    }

    /// Renders crosshair lines at 100% of user opacity at all times for maximum sharpness and clarity.
    func updateCrosshairOpacity() {
        let s = Settings.shared
        let baseOpacity = CGFloat(s.opacity)
        for hair in [crosshairH, crosshairV] {
            hair.setLineOpacity(baseOpacity)
            if !s.crosshairEnabled { hair.orderOut(nil) }
        }
    }

    @objc private func screensChanged() {
        GuideManager.shared.relayout()
    }

    private func setVisible(_ visible: Bool, panel: RulerPanel) {
        if visible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    func resetGeometry() {
        panels.forEach { $0.resetGeometry() }
        GuideManager.shared.refreshLabels()
    }

    func clearMeasurements() {
        MeasurementStore.shared.clear()
    }

    func addGuideAtPointer(orientation: RulerAxis) {
        GuideManager.shared.add(orientation: orientation, at: NSEvent.mouseLocation)
    }

    // MARK: - Units

    /// Display units per point: 1 for logical points, 2 for device pixels on Retina.
    func unitsPerPoint(on screen: NSScreen?) -> CGFloat {
        Settings.shared.devicePixels ? (screen?.backingScaleFactor ?? 2.0) : 1.0
    }

    func screen(containing point: NSPoint) -> NSScreen {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    /// Global screen coordinates corresponding to the zero point (0, 0) of the rulers.
    func globalZeroOrigin(on screen: NSScreen? = nil) -> NSPoint {
        let scr = screen ?? NSScreen.main ?? NSScreen.screens.first
        let scrFrame = scr?.frame ?? .zero

        let zeroX: CGFloat
        if horizontal.isVisible {
            zeroX = horizontal.frame.minX + Settings.shared.zeroOffset(for: .horizontal)
        } else {
            zeroX = scrFrame.minX + Settings.shared.zeroOffset(for: .horizontal)
        }

        let zeroY: CGFloat
        if vertical.isVisible {
            zeroY = vertical.frame.maxY - Settings.shared.zeroOffset(for: .vertical)
        } else {
            zeroY = scrFrame.maxY - Settings.shared.zeroOffset(for: .vertical)
        }

        return NSPoint(x: zeroX, y: zeroY)
    }

    /// Number shown on a guide: measured on the ruler that reads that axis,
    /// falling back to screen coordinates when that ruler is hidden.
    private func label(for guide: GuideWindow) -> String? {
        let scale = unitsPerPoint(on: screen(containing: guide.anchor))
        // A horizontal guide marks a Y position, which the vertical ruler reads.
        let panel = guide.orientation == .horizontal ? vertical : horizontal

        if panel.isVisible {
            let d = guide.orientation == .horizontal
                ? panel.frame.maxY - guide.anchor.y
                : guide.anchor.x - panel.frame.minX
            let value = (d - Settings.shared.zeroOffset(for: panel.axis)) * scale
            return "\(Int(value.rounded()))"
        }

        let f = screen(containing: guide.anchor).frame
        let value = guide.orientation == .horizontal
            ? (f.maxY - guide.anchor.y) * scale
            : (guide.anchor.x - f.minX) * scale
        return "\(Int(value.rounded()))"
    }

    // MARK: - The poll

    private func tick() {
        let mouse = NSEvent.mouseLocation

        let idle = mouse == lastMouse
        defer {
            lastMouse = mouse
        }
        if idle && MeasurementStore.shared.isEmpty { return }

        updateCursorLines(mouse)
        updateCrosshair(mouse)
        MeasurementStore.shared.updateHitRegions(pointer: mouse)
    }

    private func updateCursorLines(_ mouse: NSPoint) {
        for panel in panels where panel.isVisible {
            let f = panel.frame
            let d = panel.axis == .horizontal ? mouse.x - f.minX : f.maxY - mouse.y
            let limit = panel.axis == .horizontal ? f.width : f.height
            panel.rulerView.cursorDistance = (d >= 0 && d <= limit) ? d : nil
        }
    }

    private func updateCrosshair(_ mouse: NSPoint) {
        guard Settings.shared.crosshairEnabled else { return }
        let scr = screen(containing: mouse)
        for hair in [crosshairH, crosshairV] {
            hair.follow(mouse, on: scr)
            if !hair.isVisible { hair.orderFrontRegardless() }
        }
    }

    static func constrainAspectRatio(anchor: NSPoint, current: NSPoint, ratio: CGFloat) -> NSPoint {
        let dx = current.x - anchor.x
        let dy = current.y - anchor.y
        let absDx = abs(dx)
        let absDy = abs(dy)
        let r = (ratio.isFinite && ratio > 0) ? ratio : 1.0

        let width: CGFloat
        let height: CGFloat
        if absDx / r >= absDy {
            width = absDx
            height = absDx / r
        } else {
            height = absDy
            width = absDy * r
        }

        let signX: CGFloat = dx >= 0 ? 1 : -1
        let signY: CGFloat = dy >= 0 ? 1 : -1
        return NSPoint(x: (anchor.x + signX * width).rounded(),
                       y: (anchor.y + signY * height).rounded())
    }

    static func constrainSquareOrCircle(anchor: NSPoint, current: NSPoint) -> NSPoint {
        constrainAspectRatio(anchor: anchor, current: current, ratio: 1.0)
    }

    static func constrainLine(anchor: NSPoint, current: NSPoint) -> NSPoint {
        let dx = current.x - anchor.x
        let dy = current.y - anchor.y
        let angle = atan2(dy, dx)
        let step = CGFloat.pi / 4.0
        let snappedAngle = (angle / step).rounded() * step
        let len = hypot(dx, dy)
        return NSPoint(x: (anchor.x + len * cos(snappedAngle)).rounded(),
                       y: (anchor.y + len * sin(snappedAngle)).rounded())
    }

    func updateLiveMeasurement(anchor: NSPoint, current: NSPoint, shapeType: ShapeType) {
        let scr = screen(containing: current)
        measureOverlay.show(anchor: anchor,
                            current: current,
                            scale: unitsPerPoint(on: scr),
                            screen: scr,
                            shapeType: shapeType)
        setMeasureSpans(anchor, current)
    }

    func clearLiveMeasurement() {
        measureOverlay.hide()
        setMeasureSpans(nil, nil)
    }

    /// Mirrors the measured span onto both rulers.
    func setMeasureSpans(_ a: NSPoint?, _ b: NSPoint?) {
        for panel in panels {
            guard let a, let b else {
                panel.rulerView.measureSpan = nil
                continue
            }
            let f = panel.frame
            let limit = panel.axis == .horizontal ? f.width : f.height
            let d1 = panel.axis == .horizontal ? a.x - f.minX : f.maxY - a.y
            let d2 = panel.axis == .horizontal ? b.x - f.minX : f.maxY - b.y
            let lower = max(0, min(d1, d2))
            let upper = min(limit, max(d1, d2))
            panel.rulerView.measureSpan = upper > lower ? lower...upper : nil
        }
    }
}
