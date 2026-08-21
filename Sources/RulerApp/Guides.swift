import AppKit

/// A fixed guide line spanning a whole screen. Draggable, unlike the crosshair.
/// `orientation` is the direction the line runs; `anchor` is a point on it
/// (its cross coordinate also decides which screen the guide belongs to).
final class GuideWindow: NSPanel {

    static let thickness: CGFloat = 16

    let orientation: RulerAxis
    var anchor: NSPoint
    private let guideView: GuideView

    init(orientation: RulerAxis, anchor: NSPoint) {
        self.orientation = orientation
        self.anchor = anchor
        self.guideView = GuideView(orientation: orientation)

        super.init(contentRect: NSRect(x: 0, y: 0, width: 100, height: GuideWindow.thickness),
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
        contentView = guideView
        guideView.owner = self
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        layout()
    }

    override var canBecomeKey: Bool { false }

    /// The coordinate the guide is pinned to: y for a horizontal line, x for a vertical one.
    var position: CGFloat {
        orientation == .horizontal ? anchor.y : anchor.x
    }

    func move(to point: NSPoint) {
        anchor = point
        layout()
    }

    func layout() {
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let f = screen.frame
        let t = GuideWindow.thickness
        let rect: NSRect
        switch orientation {
        case .horizontal:
            rect = NSRect(x: f.minX, y: (anchor.y - t / 2).rounded(), width: f.width, height: t)
        case .vertical:
            rect = NSRect(x: (anchor.x - t / 2).rounded(), y: f.minY, width: t, height: f.height)
        }
        setFrame(rect, display: true)
        guideView.needsDisplay = true
    }

    func refreshLabel() {
        guideView.needsDisplay = true
    }
}

final class GuideView: NSView {

    private let orientation: RulerAxis
    weak var owner: GuideWindow?
    private var hovering = false
    private var trackingArea: NSTrackingArea?

    init(orientation: RulerAxis) {
        self.orientation = orientation
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    override var isOpaque: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeAlways],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: orientation == .horizontal ? .resizeUpDown : .resizeLeftRight)
    }

    override func draw(_ dirtyRect: NSRect) {
        if hovering {
            Palette.guideLine.withAlphaComponent(0.12).setFill()
            bounds.fill()
        }

        let line = NSBezierPath()
        line.lineWidth = 1
        switch orientation {
        case .horizontal:
            let y = bounds.midY.rounded() + 0.5
            line.move(to: NSPoint(x: bounds.minX, y: y))
            line.line(to: NSPoint(x: bounds.maxX, y: y))
        case .vertical:
            let x = bounds.midX.rounded() + 0.5
            line.move(to: NSPoint(x: x, y: bounds.minY))
            line.line(to: NSPoint(x: x, y: bounds.maxY))
        }
        Palette.guideLine.setStroke()
        line.stroke()

        drawLabel()
    }

    private func drawLabel() {
        guard let owner,
              let value = GuideManager.shared.label(for: owner) else { return }

        let text = NSAttributedString(string: value, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: NSColor.white,
        ])
        let size = text.size()
        let padX: CGFloat = 4, padY: CGFloat = 1.5
        var rect = NSRect(x: 0, y: 0, width: size.width + padX * 2, height: size.height + padY * 2)
        switch orientation {
        case .horizontal:
            rect.origin = NSPoint(x: bounds.minX + 10, y: bounds.midY - rect.height / 2)
        case .vertical:
            // Sit below the menu bar rather than under it.
            let inset = (window?.screen).map { $0.frame.maxY - $0.visibleFrame.maxY } ?? 0
            rect.origin = NSPoint(x: bounds.midX - rect.width / 2,
                                  y: bounds.maxY - inset - rect.height - 10)
        }

        Palette.guideLine.withAlphaComponent(0.95).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3).fill()
        text.draw(at: NSPoint(x: rect.minX + padX, y: rect.minY + padY))
    }

    // MARK: Interaction

    override func mouseDown(with event: NSEvent) {
        guard let owner else { return }
        if event.clickCount == 2 {
            GuideManager.shared.remove(owner)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let owner else { return }
        owner.move(to: NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        GuideManager.shared.save()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let remove = NSMenuItem(title: "Remove Guide", action: #selector(removeGuide), keyEquivalent: "")
        remove.target = self
        menu.addItem(remove)
        let clear = NSMenuItem(title: "Clear All Guides", action: #selector(clearGuides), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        return menu
    }

    @objc private func removeGuide() {
        if let owner { GuideManager.shared.remove(owner) }
    }

    @objc private func clearGuides() {
        GuideManager.shared.clear()
    }
}

/// Creates, stores and restores the fixed guides.
final class GuideManager {

    static let shared = GuideManager()

    private(set) var guides: [GuideWindow] = []

    /// Supplied by RulerController: turns a guide into the number shown on it.
    var labelProvider: ((GuideWindow) -> String?)?

    private init() {}

    func label(for guide: GuideWindow) -> String? {
        labelProvider?(guide)
    }

    @discardableResult
    func add(orientation: RulerAxis, at point: NSPoint) -> GuideWindow {
        let guide = GuideWindow(orientation: orientation, anchor: point)
        guide.alphaValue = CGFloat(Settings.shared.opacity)
        guide.ignoresMouseEvents = Settings.shared.clickThrough
        guide.orderFrontRegardless()
        guides.append(guide)
        save()
        return guide
    }

    func remove(_ guide: GuideWindow) {
        guide.orderOut(nil)
        guides.removeAll { $0 === guide }
        save()
    }

    func clear() {
        guides.forEach { $0.orderOut(nil) }
        guides.removeAll()
        save()
    }

    func applySettings() {
        for guide in guides {
            guide.alphaValue = CGFloat(Settings.shared.opacity)
            guide.ignoresMouseEvents = Settings.shared.clickThrough
            guide.refreshLabel()
        }
    }

    func relayout() {
        guides.forEach { $0.layout() }
    }

    func refreshLabels() {
        guides.forEach { $0.refreshLabel() }
    }

    // MARK: Persistence

    func save() {
        let encoded = guides.map { g in
            "\(g.orientation == .horizontal ? "h" : "v")|\(g.anchor.x)|\(g.anchor.y)"
        }
        Settings.shared.savedGuides = encoded
    }

    func restore() {
        for entry in Settings.shared.savedGuides {
            let parts = entry.split(separator: "|")
            guard parts.count == 3,
                  let x = Double(parts[1]), let y = Double(parts[2]) else { continue }
            let point = NSPoint(x: x, y: y)
            guard NSScreen.screens.contains(where: { $0.frame.contains(point) }) else { continue }
            let orientation: RulerAxis = parts[0] == "h" ? .horizontal : .vertical
            let guide = GuideWindow(orientation: orientation, anchor: point)
            guide.alphaValue = CGFloat(Settings.shared.opacity)
            guide.ignoresMouseEvents = Settings.shared.clickThrough
            guide.orderFrontRegardless()
            guides.append(guide)
        }
    }
}
