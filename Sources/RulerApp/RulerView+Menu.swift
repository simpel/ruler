import AppKit

extension RulerView {

    override func menu(for event: NSEvent) -> NSMenu? {
        RulerController.shared.activateContext()
        let p = convert(event.locationInWindow, from: nil)
        let d = distance(forViewPoint: p)
        let menu = NSMenu()

        let setZero = NSMenuItem(title: "Set Zero Here", action: #selector(setZeroHere(_:)), keyEquivalent: "")
        setZero.target = self
        setZero.representedObject = NSNumber(value: Double(d))
        menu.addItem(setZero)

        let reset = NSMenuItem(title: "Reset Zero", action: #selector(resetZero(_:)), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())

        let cross = NSMenuItem(title: "Add Cross Guide Here", action: #selector(addCrossGuide(_:)), keyEquivalent: "")
        cross.target = self
        cross.representedObject = NSValue(point: window?.convertPoint(toScreen: event.locationInWindow) ?? .zero)
        menu.addItem(cross)

        let clear = NSMenuItem(title: "Clear All Guides", action: #selector(clearGuides), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        menu.addItem(.separator())

        let hide = NSMenuItem(title: axis == .horizontal ? "Hide Horizontal Ruler" : "Hide Vertical Ruler",
                              action: #selector(hideRuler(_:)), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Distanser Controls…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit Distanser", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func setZeroHere(_ sender: NSMenuItem) {
        guard let n = sender.representedObject as? NSNumber else { return }
        Settings.shared.setZeroOffset(CGFloat(n.doubleValue), for: axis)
        needsDisplay = true
    }

    @objc private func resetZero(_ sender: Any?) {
        Settings.shared.setZeroOffset(0, for: axis)
        needsDisplay = true
    }

    /// A guide crossing this ruler, marking the value under the click.
    @objc private func addCrossGuide(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? NSValue else { return }
        GuideManager.shared.add(orientation: axis == .horizontal ? .vertical : .horizontal,
                                at: value.pointValue)
    }

    @objc private func clearGuides() {
        GuideManager.shared.clear()
    }

    @objc private func hideRuler(_ sender: Any?) {
        if axis == .horizontal {
            Settings.shared.showHorizontal = false
        } else {
            Settings.shared.showVertical = false
        }
    }

    @objc private func showSettings() {
        ControlWindowController.shared.show()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
