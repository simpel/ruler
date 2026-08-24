import AppKit

/// A fixed guide line spanning a whole screen. Draggable, unlike the crosshair.
/// `orientation` is the direction the line runs; `anchor` is a point on it
/// (its cross coordinate also decides which screen the guide belongs to).
final class GuideWindow: NSPanel {

    static let thickness: CGFloat = 16

    let orientation: RulerAxis
    var anchor: NSPoint
    private let guideView: GuideView
    private let labelWindow = GuideLabelWindow()

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
        GuideManager.shared.refreshLabelLayout()
    }

    /// How much room this guide's badge needs along the screen edge.
    func labelExtent() -> CGFloat {
        guard let text = GuideManager.shared.label(for: self) else { return 0 }
        let size = GuideLabelWindow.badgeSize(for: text)
        return orientation == .vertical ? size.width : size.height
    }

    /// The guide's own number lives in its own window: the guide itself is only
    /// 16pt thick, which used to clip the badge, and the edge is where the
    /// hover distances appear too. `lane` stacks labels inwards when guides sit
    /// too close for their badges to fit side by side.
    func updateLabel(lane: Int) {
        guard let text = GuideManager.shared.label(for: self) else {
            labelWindow.hide()
            return
        }
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        labelWindow.alphaValue = alphaValue
        labelWindow.update(text: text, orientation: orientation, position: position,
                           lane: lane, screen: screen)
    }

    func refreshLabel() {
        layout()
    }

    /// Takes the guide and its label off screen together.
    func teardown() {
        labelWindow.hide()
        orderOut(nil)
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

/// One guide's position badge, in its own window so it is never clipped and
/// always sits at the edge of the screen: the top edge for vertical guides,
/// the left edge for horizontal ones.
final class GuideLabelWindow: NSPanel {

    private let labelView = GuideLabelView()

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 30, height: 16),
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
        contentView = labelView
        // Above the rulers, so a number is never hidden under one.
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
    }

    override var canBecomeKey: Bool { false }

    static let laneStep: CGFloat = 20
    static let edgeInset: CGFloat = 6

    static func badgeSize(for text: String) -> NSSize {
        GuideLabelView.size(for: text)
    }

    func update(text: String, orientation: RulerAxis, position: CGFloat, lane: Int, screen: NSScreen) {
        labelView.text = text
        let size = labelView.badgeSize()
        let edge = GuideLabelWindow.edgeInset + CGFloat(lane) * GuideLabelWindow.laneStep
        let rect: NSRect
        switch orientation {
        case .vertical:
            rect = NSRect(x: (position - size.width / 2).rounded(),
                          y: (screen.visibleFrame.maxY - edge - size.height).rounded(),
                          width: size.width, height: size.height)
        case .horizontal:
            rect = NSRect(x: (screen.frame.minX + edge).rounded(),
                          y: (position - size.height / 2).rounded(),
                          width: size.width, height: size.height)
        }
        if frame != rect { setFrame(rect, display: false) }
        labelView.needsDisplay = true
        if !isVisible { orderFrontRegardless() }
    }

    func hide() {
        if isVisible { orderOut(nil) }
    }
}

final class GuideLabelView: NSView {

    var text = ""

    override var isOpaque: Bool { false }

    private var attributed: NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: Palette.guideBadgeText,
        ])
    }

    /// The badge sizes itself to its text, so nothing is ever cut off.
    func badgeSize() -> NSSize { GuideLabelView.size(for: text) }

    static func size(for text: String) -> NSSize {
        let s = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold),
        ]).size()
        return NSSize(width: ceil(s.width) + 9, height: ceil(s.height) + 4)
    }

    override func draw(_ dirtyRect: NSRect) {
        Palette.guideLine.withAlphaComponent(0.95).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 3, yRadius: 3).fill()
        let text = attributed
        let size = text.size()
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                              y: (bounds.height - size.height) / 2))
    }
}

/// Shows the distance from a hovered (or dragged) guide to every other guide
/// of the same orientation on its screen, as pale amber badges along the same
/// screen edge the position labels use — the top edge for vertical guides, the
/// left edge for horizontal ones — in a lane just inside them.
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

    func show(hovered: GuideWindow, siblings: [GuideWindow], on screen: NSScreen, startInset: CGFloat) {
        if frame != screen.frame { setFrame(screen.frame, display: false) }
        distanceView.configure(hovered: hovered, siblings: siblings, screen: screen,
                               startInset: startInset)
        if !isVisible { orderFrontRegardless() }
    }

    func hide() {
        if isVisible { orderOut(nil) }
    }
}

final class GuideDistanceView: NSView {

    /// One dimension line: it spans the gap between the hovered guide and one
    /// sibling, with the distance sitting on it, so you can see which pair of
    /// lines the number belongs to.
    private struct Dimension {
        let text: String
        let from: NSPoint
        let to: NSPoint
    }

    private var dimensions: [Dimension] = []
    private var orientation: RulerAxis = .vertical

    private let baseInset: CGFloat = 12      // clearance past the position badges
    private let laneStep: CGFloat = 21       // one row per sibling
    private let tick: CGFloat = 5

    override var isOpaque: Bool { false }

    func configure(hovered: GuideWindow, siblings: [GuideWindow], screen: NSScreen, startInset: CGFloat) {
        orientation = hovered.orientation
        let scale = Settings.shared.devicePixels ? screen.backingScaleFactor : 1.0
        let menuBarInset = screen.frame.maxY - screen.visibleFrame.maxY
        let origin = screen.frame.origin

        // Nearest sibling gets the lane closest to the edge.
        let ordered = siblings.sorted {
            abs($0.position - hovered.position) < abs($1.position - hovered.position)
        }

        dimensions = ordered.enumerated().map { index, sibling in
            let lane = startInset + baseInset + CGFloat(index) * laneStep
            let a = hovered.position
            let b = sibling.position
            let text = "\(Int((abs(b - a) * scale).rounded()))"
            switch orientation {
            case .vertical:   // vertical guides sit side by side: rows across the top
                let y = screen.frame.height - menuBarInset - lane
                return Dimension(text: text,
                                 from: NSPoint(x: a - origin.x, y: y),
                                 to: NSPoint(x: b - origin.x, y: y))
            case .horizontal: // horizontal guides stack: columns down the left
                let x = lane
                return Dimension(text: text,
                                 from: NSPoint(x: x, y: a - origin.y),
                                 to: NSPoint(x: x, y: b - origin.y))
            }
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        for dimension in dimensions { drawDimension(dimension) }
    }

    private func drawDimension(_ dimension: Dimension) {
        let path = NSBezierPath()
        path.lineWidth = 1
        path.move(to: dimension.from)
        path.line(to: dimension.to)

        // End ticks, so each row reads as a span rather than a stray line.
        for point in [dimension.from, dimension.to] {
            switch orientation {
            case .vertical:
                path.move(to: NSPoint(x: point.x.rounded() + 0.5, y: point.y - tick))
                path.line(to: NSPoint(x: point.x.rounded() + 0.5, y: point.y + tick))
            case .horizontal:
                path.move(to: NSPoint(x: point.x - tick, y: point.y.rounded() + 0.5))
                path.line(to: NSPoint(x: point.x + tick, y: point.y.rounded() + 0.5))
            }
        }
        Palette.guideTint.withAlphaComponent(0.9).setStroke()
        path.stroke()

        drawBadge(dimension.text,
                  at: NSPoint(x: (dimension.from.x + dimension.to.x) / 2,
                              y: (dimension.from.y + dimension.to.y) / 2))
    }

    private func drawBadge(_ string: String, at point: NSPoint) {
        let text = NSAttributedString(string: string, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: Palette.guideBadgeText,
        ])
        let size = text.size()
        let padX: CGFloat = 4.5, padY: CGFloat = 2
        var rect = NSRect(x: point.x - (size.width + padX * 2) / 2,
                          y: point.y - (size.height + padY * 2) / 2,
                          width: size.width + padX * 2,
                          height: size.height + padY * 2)
        rect.origin.x = min(max(rect.origin.x, bounds.minX + 2), bounds.maxX - rect.width - 2)
        rect.origin.y = min(max(rect.origin.y, bounds.minY + 2), bounds.maxY - rect.height - 2)

        Palette.guideTint.setFill()
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
        refreshLabelLayout()
        save()
        return guide
    }

    func remove(_ guide: GuideWindow) {
        guide.teardown()
        guides.removeAll { $0 === guide }
        endHover(guide)
        refreshLabelLayout()
        save()
    }

    func clear() {
        guides.forEach { $0.teardown() }
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

    /// Position badges are pinned to the screen edge, so guides sitting close
    /// together would have their labels overlap. Pack them into as few lanes as
    /// the badge widths allow, then remember how deep the stack went so the
    /// distance rows can start inside it.
    private var laneDepth: [RulerAxis: Int] = [:]

    func refreshLabelLayout() {
        for orientation in [RulerAxis.horizontal, RulerAxis.vertical] {
            let ordered = guides
                .filter { $0.orientation == orientation }
                .sorted { $0.position < $1.position }

            var laneEnds: [CGFloat] = []
            var deepest = 0
            for guide in ordered {
                let extent = guide.labelExtent()
                let start = guide.position - extent / 2
                let gap: CGFloat = 4
                var lane = 0
                while lane < laneEnds.count, laneEnds[lane] + gap > start { lane += 1 }
                if lane == laneEnds.count {
                    laneEnds.append(guide.position + extent / 2)
                } else {
                    laneEnds[lane] = guide.position + extent / 2
                }
                guide.updateLabel(lane: lane)
                deepest = max(deepest, lane)
            }
            laneDepth[orientation] = ordered.isEmpty ? 0 : deepest + 1
        }
        updateDistanceOverlay()
    }

    private func updateDistanceOverlay() {
        guard let hovered = hoveredGuide else { distanceOverlay.hide(); return }
        let screen = NSScreen.screens.first { $0.frame.contains(hovered.anchor) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let siblings = guides.filter {
            $0 !== hovered && $0.orientation == hovered.orientation && screen.frame.contains($0.anchor)
        }
        guard !siblings.isEmpty else { distanceOverlay.hide(); return }
        let lanes = CGFloat(laneDepth[hovered.orientation] ?? 1)
        let startInset = GuideLabelWindow.edgeInset + lanes * GuideLabelWindow.laneStep
        distanceOverlay.show(hovered: hovered, siblings: siblings, on: screen,
                             startInset: startInset)
    }

    func refreshLabels() {
        refreshLabelLayout()
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
        refreshLabelLayout()
    }
}
