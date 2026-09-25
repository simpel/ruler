import AppKit

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
