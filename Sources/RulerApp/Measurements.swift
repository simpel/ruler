import AppKit

/// A measurement the user has finished drawing. It stays on screen until
/// dismissed, so several things can be measured at once.
final class MeasurementWindow: NSPanel {

    /// Room around the drag for the readout badge and the dismiss button.
    private static let padding: CGFloat = 120

    private let measureView = MeasureView()
    private var anchor: NSPoint      // global coordinates
    private var current: NSPoint

    init(anchor: NSPoint, current: NSPoint) {
        self.anchor = anchor
        self.current = current

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
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]

        measureView.showsClose = true
        measureView.onClose = { [weak self] in
            guard let self else { return }
            MeasurementStore.shared.remove(self)
        }
        // Click-through everywhere except the dismiss button; see updateHitRegion.
        ignoresMouseEvents = true
        layout()
    }

    override var canBecomeKey: Bool { false }

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

    private var closeRectOnScreen: NSRect? {
        measureView.closeRect.map { convertToScreen(measureView.convert($0, to: nil)) }
    }

    /// The window covers a large area, so it stays click-through and only becomes
    /// clickable while the pointer is actually over the dismiss button.
    func updateHitRegion(pointer: NSPoint) {
        let overClose = !Settings.shared.clickThrough
            && (closeRectOnScreen?.insetBy(dx: -5, dy: -5).contains(pointer) ?? false)
        if ignoresMouseEvents == overClose { ignoresMouseEvents = !overClose }
        measureView.closeHot = overClose
    }
}

/// Holds the kept measurements.
final class MeasurementStore {

    static let shared = MeasurementStore()

    private(set) var measurements: [MeasurementWindow] = []

    private init() {}

    var isEmpty: Bool { measurements.isEmpty }

    /// Ignores stray clicks: a measurement needs some length to be worth keeping.
    func add(anchor: NSPoint, current: NSPoint) {
        guard hypot(current.x - anchor.x, current.y - anchor.y) > 6 else { return }
        let window = MeasurementWindow(anchor: anchor, current: current)
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
