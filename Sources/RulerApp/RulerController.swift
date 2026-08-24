import AppKit

/// Owns the rulers, the crosshair, the measuring overlay and the guides, and
/// drives them all from one 60 Hz pointer poll.
final class RulerController {

    private let horizontal = RulerPanel(axis: .horizontal)
    private let vertical = RulerPanel(axis: .vertical)

    private let crosshairH = HairlineWindow(orientation: .horizontal)
    private let crosshairV = HairlineWindow(orientation: .vertical)
    private let measureOverlay = MeasureOverlayWindow()

    private var timer: Timer?

    // Poll state
    private var lastMouse: NSPoint = .zero
    private var wasButtonDown = false
    private var wasArmed = false

    // Measurement state
    private var measureAnchor: NSPoint?
    private var measureCurrent: NSPoint = .zero

    var panels: [RulerPanel] { [horizontal, vertical] }

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
        // Follow the system light/dark switch while Appearance is set to System.
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(applySettings),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
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

        for hair in [crosshairH, crosshairV] {
            hair.alphaValue = CGFloat(s.opacity)
            if !s.crosshairEnabled { hair.orderOut(nil) }
        }

        GuideManager.shared.applySettings()
        MeasurementStore.shared.applySettings()
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
    private func unitsPerPoint(on screen: NSScreen?) -> CGFloat {
        Settings.shared.devicePixels ? (screen?.backingScaleFactor ?? 2.0) : 1.0
    }

    private func screen(containing point: NSPoint) -> NSScreen {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens[0]
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
        let armed = Settings.shared.measureModifier.matches(NSEvent.modifierFlags)
        let buttonDown = NSEvent.pressedMouseButtons & 1 != 0

        let idle = mouse == lastMouse && armed == wasArmed && buttonDown == wasButtonDown
        defer {
            lastMouse = mouse
            wasArmed = armed
            wasButtonDown = buttonDown
        }
        if idle && measureAnchor == nil && MeasurementStore.shared.isEmpty { return }

        updateCursorLines(mouse)
        updateCrosshair(mouse)
        MeasurementStore.shared.updateHitRegions(pointer: mouse)
        updateMeasurement(mouse, armed: armed, buttonDown: buttonDown)
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

    private func updateMeasurement(_ mouse: NSPoint, armed: Bool, buttonDown: Bool) {
        // Releasing the button keeps the measurement on screen as its own window,
        // so several things can be measured at once.
        if wasButtonDown && !buttonDown, let a = measureAnchor {
            MeasurementStore.shared.add(anchor: a, current: measureCurrent)
            measureAnchor = nil
            measureOverlay.hide()
            setMeasureSpans(nil, nil)
            return
        }

        if armed {
            if buttonDown && !wasButtonDown {
                measureAnchor = mouse          // gesture starts on the press
            }
            if buttonDown, measureAnchor != nil {
                measureCurrent = mouse
            }
        } else if !(buttonDown && measureAnchor != nil) {
            // Not armed and not mid-drag: nothing to show.
            if measureAnchor != nil || measureOverlay.isVisible {
                measureAnchor = nil
                measureOverlay.hide()
                setMeasureSpans(nil, nil)
            }
            return
        } else {
            measureCurrent = mouse             // keep a drag alive if the modifier is let go
        }

        let scr = screen(containing: mouse)
        measureOverlay.show(anchor: measureAnchor,
                            current: measureAnchor == nil ? mouse : measureCurrent,
                            scale: unitsPerPoint(on: scr),
                            screen: scr)

        if let a = measureAnchor {
            setMeasureSpans(a, measureCurrent)
        } else {
            setMeasureSpans(nil, nil)
        }
    }

    /// Mirrors the measured span onto both rulers.
    private func setMeasureSpans(_ a: NSPoint?, _ b: NSPoint?) {
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
