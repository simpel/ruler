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

    override func mouseEntered(with event: NSEvent) {
        hovering = true; needsDisplay = true
        if let owner { GuideManager.shared.hover(owner) }
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false; needsDisplay = true
        if let owner { GuideManager.shared.endHover(owner) }
    }

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
            .foregroundColor: Palette.guideBadgeText,
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
        GuideManager.shared.hover(owner)
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

/// Shows the distance from a hovered (or dragged) guide to every other guide
/// of the same orientation on its screen, as redline badges along the screen
/// edge that guide's own position label already sits on — the top edge for
/// vertical guides, the left edge for horizontal ones.
final class GuideDistanceOverlay: NSPanel {

    private let distanceView = GuideDistanceView()

    init() {
        super.init(contentRect: .zero,
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
        contentView = distanceView
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
    }

    override var canBecomeKey: Bool { false }

    func show(hovered: GuideWindow, siblings: [GuideWindow], on screen: NSScreen) {
        if frame != screen.frame { setFrame(screen.frame, display: false) }
        distanceView.configure(hovered: hovered, siblings: siblings, screen: screen)
        if !isVisible { orderFrontRegardless() }
    }

    func hide() {
        if isVisible { orderOut(nil) }
    }
}

final class GuideDistanceView: NSView {

    private struct Badge { let text: String; let anchor: NSPoint }

    private var badges: [Badge] = []
    private var orientation: RulerAxis = .vertical

    override var isOpaque: Bool { false }

    /// `anchor` marks where the label band sits along the screen edge; the
    /// badge itself is drawn hanging off it, matching how a guide's own
    /// position label is placed relative to its window's bounds.
    func configure(hovered: GuideWindow, siblings: [GuideWindow], screen: NSScreen) {
        orientation = hovered.orientation
        let scale = Settings.shared.devicePixels ? screen.backingScaleFactor : 1.0
        let edgeInset: CGFloat = 10
        let menuBarInset = screen.frame.maxY - screen.visibleFrame.maxY
        let origin = screen.frame.origin

        badges = siblings.map { sibling in
            let distance = abs(hovered.position - sibling.position) * scale
            let mid = (hovered.position + sibling.position) / 2
            let anchor: NSPoint
            switch orientation {
            case .vertical:
                anchor = NSPoint(x: mid - origin.x, y: screen.frame.height - menuBarInset - edgeInset)
            case .horizontal:
                anchor = NSPoint(x: edgeInset, y: mid - origin.y)
            }
            return Badge(text: "\(Int(distance.rounded()))", anchor: anchor)
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        for badge in badges { drawBadge(badge) }
    }

    private func drawBadge(_ badge: Badge) {
        let text = NSAttributedString(string: badge.text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: NSColor.white,
        ])
        let size = text.size()
        let padX: CGFloat = 4, padY: CGFloat = 1.5
        var rect = NSRect(x: 0, y: 0, width: size.width + padX * 2, height: size.height + padY * 2)
        switch orientation {
        case .vertical:
            rect.origin = NSPoint(x: badge.anchor.x - rect.width / 2, y: badge.anchor.y - rect.height)
        case .horizontal:
            rect.origin = NSPoint(x: badge.anchor.x, y: badge.anchor.y - rect.height / 2)
        }
        Palette.live.withAlphaComponent(0.95).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3).fill()
        text.draw(at: NSPoint(x: rect.minX + padX, y: rect.minY + padY))
    }
}

/// Creates, stores and restores the fixed guides.
final class GuideManager {

    static let shared = GuideManager()

    private(set) var guides: [GuideWindow] = []
    private(set) var hoveredGuide: GuideWindow?
    private let distanceOverlay = GuideDistanceOverlay()

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
        endHover(guide)
        save()
    }

    func clear() {
        guides.forEach { $0.orderOut(nil) }
        guides.removeAll()
        hoveredGuide = nil
        distanceOverlay.hide()
        save()
    }

    func applySettings() {
        for guide in guides {
            guide.alphaValue = CGFloat(Settings.shared.opacity)
            guide.ignoresMouseEvents = Settings.shared.clickThrough
            guide.refreshLabel()
        }
        distanceOverlay.alphaValue = CGFloat(Settings.shared.opacity)
        updateDistanceOverlay()
    }

    func relayout() {
        guides.forEach { $0.layout() }
        updateDistanceOverlay()
    }

    // MARK: - Hover distances

    /// The pointer entered (or is dragging) this guide: show its distance to
    /// every other guide sharing its orientation and screen.
    func hover(_ guide: GuideWindow) {
        hoveredGuide = guide
        updateDistanceOverlay()
    }

    /// The pointer left this guide. A no-op if some other guide is now hovered.
    func endHover(_ guide: GuideWindow) {
        guard hoveredGuide === guide else { return }
        hoveredGuide = nil
        distanceOverlay.hide()
    }

    private func updateDistanceOverlay() {
        guard let hovered = hoveredGuide else { distanceOverlay.hide(); return }
        let screen = NSScreen.screens.first { $0.frame.contains(hovered.anchor) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let siblings = guides.filter {
            $0 !== hovered && $0.orientation == hovered.orientation && screen.frame.contains($0.anchor)
        }
        guard !siblings.isEmpty else { distanceOverlay.hide(); return }
        distanceOverlay.show(hovered: hovered, siblings: siblings, on: screen)
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
