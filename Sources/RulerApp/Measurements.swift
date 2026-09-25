import AppKit

/// A shape or measurement the user has drawn or added. It stays on screen until
/// dismissed, so several shapes can be placed and compared at once.
final class MeasurementWindow: NSPanel {

    /// Room around the shape for the readout badge and the dismiss button.
    private static let padding: CGFloat = 120

    private let measureView = MeasureView()
    let shapeType: ShapeType
    private(set) var anchor: NSPoint      // global coordinates
    private(set) var current: NSPoint

    init(anchor: NSPoint, current: NSPoint, shapeType: ShapeType = .rectangle) {
        self.anchor = anchor
        self.current = current
        self.shapeType = shapeType

        super.init(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        contentView = measureView
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]

        measureView.shapeType = shapeType
        measureView.owner = self
        measureView.showsClose = true
        measureView.onClose = { [weak self] in
            guard let self else { return }
            MeasurementStore.shared.remove(self)
        }
        measureView.onEdit = { [weak self] in
            guard let self else { return }
            ShapeEditDialogController.shared.show(for: self)
        }
        // Click-through everywhere except the tooltip, outline and dismiss button; see updateHitRegion.
        ignoresMouseEvents = true
        layout()
    }

    override var canBecomeKey: Bool { false }

    /// Repositions the shape and updates layout.
    func move(toAnchor newAnchor: NSPoint, current newCurrent: NSPoint) {
        anchor = newAnchor
        current = newCurrent
        layout()
    }

    func layout() {
        let box = NSRect(x: min(anchor.x, current.x), y: min(anchor.y, current.y),
                         width: abs(anchor.x - current.x), height: abs(anchor.y - current.y))
        var frame = box.insetBy(dx: -MeasurementWindow.padding, dy: -MeasurementWindow.padding)
        frame = NSRect(x: frame.origin.x.rounded(), y: frame.origin.y.rounded(),
                       width: frame.width.rounded(), height: frame.height.rounded())
        setFrame(frame, display: false)

        measureView.anchor = NSPoint(x: anchor.x - frame.minX, y: anchor.y - frame.minY)
        measureView.current = NSPoint(x: current.x - frame.minX, y: current.y - frame.minY)
        measureView.scale = unitsPerPoint()

        let screen = NSScreen.screens.first { $0.frame.contains(current) } ?? NSScreen.main ?? NSScreen.screens.first
        if let screen {
            measureView.screenOrigin = NSPoint(x: screen.frame.minX - frame.minX,
                                               y: screen.frame.maxY - frame.minY)
        }
        measureView.needsDisplay = true
    }

    private func unitsPerPoint() -> CGFloat {
        guard Settings.shared.devicePixels else { return 1 }
        let screen = NSScreen.screens.first { $0.frame.contains(current) } ?? NSScreen.main
        return screen?.backingScaleFactor ?? 2
    }

    /// Refreshes the readout when the unit setting changes.
    func refresh() {
        measureView.scale = unitsPerPoint()
        measureView.needsDisplay = true
    }

    /// The window covers a large area, so it stays click-through to apps underneath
    /// and only becomes clickable while the pointer is over the dismiss button,
    /// the edit button, the tooltip badge (for dragging), or the shape outline.
    func updateHitRegion(pointer: NSPoint) {
        guard !Settings.shared.clickThrough else {
            if !ignoresMouseEvents { ignoresMouseEvents = true }
            measureView.closeHot = false
            measureView.editHot = false
            measureView.tooltipHot = false
            measureView.outlineHot = false
            return
        }

        let windowPoint = convertFromScreen(NSRect(origin: pointer, size: .zero)).origin
        let viewPoint = measureView.convert(windowPoint, from: nil)

        let overClose = measureView.closeRect?.insetBy(dx: -4, dy: -4).contains(viewPoint) ?? false
        let overEdit = !overClose && (measureView.editRect?.insetBy(dx: -4, dy: -4).contains(viewPoint) ?? false)
        let overBadge = !overClose && !overEdit && (measureView.badgeRect?.contains(viewPoint) ?? false)
        let overOutline = !overClose && !overEdit && !overBadge && measureView.isOverOutline(viewPoint)

        let interactive = overClose || overEdit || overBadge || overOutline
        if ignoresMouseEvents == interactive { ignoresMouseEvents = !interactive }
        measureView.closeHot = overClose
        measureView.editHot = overEdit
        measureView.tooltipHot = overBadge
        measureView.outlineHot = overOutline
    }
}

typealias ShapeWindow = MeasurementWindow
typealias ShapeStore = MeasurementStore

/// Holds the placed shapes and measurements.
final class MeasurementStore {

    static let shared = MeasurementStore()

    private(set) var measurements: [MeasurementWindow] = []

    private init() {}

    var isEmpty: Bool { measurements.isEmpty }

    /// Ignores stray clicks: a shape needs some length to be worth keeping.
    func add(anchor: NSPoint, current: NSPoint, shapeType: ShapeType = .rectangle) {
        guard hypot(current.x - anchor.x, current.y - anchor.y) > 6 else { return }
        let window = MeasurementWindow(anchor: anchor, current: current, shapeType: shapeType)
        window.alphaValue = CGFloat(Settings.shared.opacity)
        window.orderFrontRegardless()
        measurements.append(window)
    }

    /// Adds a fixed-size shape placed in the center of the active screen.
    func addFixed(width: CGFloat, height: CGFloat, shapeType: ShapeType = .rectangle) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        let center = NSPoint(x: screen.frame.midX, y: screen.frame.midY)
        let anchor = NSPoint(x: (center.x - width / 2.0).rounded(), y: (center.y - height / 2.0).rounded())
        let current = NSPoint(x: anchor.x + width, y: anchor.y + height)

        let window = MeasurementWindow(anchor: anchor, current: current, shapeType: shapeType)
        window.alphaValue = CGFloat(Settings.shared.opacity)
        window.orderFrontRegardless()
        measurements.append(window)
    }

    func remove(_ window: MeasurementWindow) {
        window.orderOut(nil)
        measurements.removeAll { $0 === window }
    }

    func clear() {
        measurements.forEach { $0.orderOut(nil) }
        measurements.removeAll()
    }

    func applySettings() {
        for window in measurements {
            window.alphaValue = CGFloat(Settings.shared.opacity)
            if Settings.shared.clickThrough { window.ignoresMouseEvents = true }
            window.refresh()
        }
    }

    func updateHitRegions(pointer: NSPoint) {
        measurements.forEach { $0.updateHitRegion(pointer: pointer) }
    }
}
