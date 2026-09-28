import AppKit

/// A floating window that snaps its frame and origin to whole integer coordinates
/// to prevent subpixel interpolation blur across active and inactive states.
final class ControlWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        var rect = super.constrainFrameRect(frameRect, to: screen)
        rect.origin.x = rect.origin.x.rounded()
        rect.origin.y = rect.origin.y.rounded()
        rect.size.width = rect.size.width.rounded()
        rect.size.height = rect.size.height.rounded()
        return rect
    }

    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(NSPoint(x: newOrigin.x.rounded(), y: newOrigin.y.rounded()))
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        let snapped = NSRect(
            x: frameRect.origin.x.rounded(),
            y: frameRect.origin.y.rounded(),
            width: frameRect.size.width.rounded(),
            height: frameRect.size.height.rounded()
        )
        super.setFrame(snapped, display: flag)
    }
}

/// A compact, architectural light-themed window providing quick access to all Ruler
/// settings and actions. Built in high-contrast light canvas to stand out distinctly
/// against the blue floating rulers, with full WCAG AAA compliant text contrast.
final class ControlWindowController: NSObject, NSWindowDelegate {

    static let shared = ControlWindowController()

    private var window: NSWindow?
    private let contentView = ControlContentView()

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(settingsChanged),
                                               name: .rulerSettingsChanged,
                                               object: nil)
    }

    func show() {
        if window == nil { window = makeWindow() }
        contentView.syncWithSettings()
        NSApp.activate(ignoringOtherApps: true)
        if let w = window {
            w.center()
            var f = w.frame
            f.origin.x = f.origin.x.rounded()
            f.origin.y = f.origin.y.rounded()
            f.size.width = f.size.width.rounded()
            f.size.height = f.size.height.rounded()
            w.setFrame(f, display: true)
            w.makeKeyAndOrderFront(nil)
        }
    }

    func toggle() {
        if let w = window, w.isVisible {
            w.orderOut(nil)
        } else {
            show()
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        contentView.needsDisplay = true
        window?.invalidateShadow()
    }

    func windowDidResignKey(_ notification: Notification) {
        contentView.needsDisplay = true
        window?.invalidateShadow()
    }

    private func makeWindow() -> NSWindow {
        contentView.layoutSubtreeIfNeeded()
        let contentHeight = ceil(max(500, contentView.fittingSize.height))
        let w = ControlWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: contentHeight),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered,
                              defer: false)
        w.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 7)
        w.appearance = NSAppearance(named: .darkAqua)
        w.title = "Distanser Controls"
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isReleasedWhenClosed = false
        w.isMovableByWindowBackground = true
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = true
        w.delegate = self
        w.contentView = contentView
        w.setContentSize(NSSize(width: 320, height: contentHeight))
        w.standardWindowButton(.zoomButton)?.isHidden = true
        return w
    }

    @objc private func settingsChanged() {
        contentView.syncWithSettings()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

