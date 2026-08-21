import AppKit

/// A borderless, floating, non-activating panel that hosts one ruler.
final class RulerPanel: NSPanel, NSWindowDelegate {

    let axis: RulerAxis
    let rulerView: RulerView

    init(axis: RulerAxis) {
        self.axis = axis
        self.rulerView = RulerView(axis: axis)

        super.init(contentRect: RulerPanel.defaultFrame(for: axis),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        contentView = rulerView
        delegate = self

        if let saved = Settings.shared.savedFrame(for: axis), fits(saved) {
            setFrame(saved, display: false)
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private func fits(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { $0.frame.intersects(frame) }
    }

    /// The point where both rulers read zero. The rulers are laid out as an L
    /// around it: the horizontal ruler's body sits above it, the vertical
    /// ruler's body to its left, so the two zero ticks land on the same pixel.
    static func sharedOrigin(in area: NSRect) -> NSPoint {
        NSPoint(x: area.minX + 80, y: area.maxY - 60)
    }

    static func defaultFrame(for axis: RulerAxis) -> NSRect {
        let area = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let t = RulerView.thickness
        let origin = sharedOrigin(in: area)
        switch axis {
        case .horizontal:
            let w = min(900, area.maxX - origin.x - 20)
            return NSRect(x: origin.x, y: origin.y, width: w, height: t)
        case .vertical:
            let h = min(700, origin.y - area.minY - 20)
            return NSRect(x: origin.x - t, y: origin.y - h, width: t, height: h)
        }
    }

    func resetGeometry() {
        setFrame(RulerPanel.defaultFrame(for: axis), display: true)
        Settings.shared.setZeroOffset(0, for: axis)
        Settings.shared.setSavedFrame(frame, for: axis)
        rulerView.needsDisplay = true
    }

    // MARK: NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        Settings.shared.setSavedFrame(frame, for: axis)
        GuideManager.shared.refreshLabels()
    }

    func windowDidResize(_ notification: Notification) {
        Settings.shared.setSavedFrame(frame, for: axis)
        GuideManager.shared.refreshLabels()
        invalidateCursorRects(for: rulerView)
        rulerView.needsDisplay = true
    }
}
