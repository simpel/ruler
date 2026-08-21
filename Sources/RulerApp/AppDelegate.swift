import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let controller = RulerController()
    private var statusItem: NSStatusItem!

    // Items whose checkmarks are refreshed when the menu opens.
    private var itemHorizontal: NSMenuItem!
    private var itemVertical: NSMenuItem!
    private var itemPoints: NSMenuItem!
    private var itemDevicePixels: NSMenuItem!
    private var itemClickThrough: NSMenuItem!
    private var itemCrosshair: NSMenuItem!
    private var itemLaunchAtLogin: NSMenuItem!
    private var opacityItems: [NSMenuItem] = []
    private var appearanceItems: [NSMenuItem] = []
    private var measureItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()
        controller.start()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "ruler", accessibilityDescription: "Ruler")
            button.image?.isTemplate = true
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        itemHorizontal = add(to: menu, "Horizontal Ruler", #selector(toggleHorizontal), key: "1")
        itemVertical = add(to: menu, "Vertical Ruler", #selector(toggleVertical), key: "2")
        itemCrosshair = add(to: menu, "Crosshair Follows Pointer", #selector(toggleCrosshair), key: "3")

        menu.addItem(.separator())

        let guides = NSMenu()
        _ = add(to: guides, "Add Horizontal Guide at Pointer", #selector(addHorizontalGuide))
        _ = add(to: guides, "Add Vertical Guide at Pointer", #selector(addVerticalGuide))
        guides.addItem(.separator())
        _ = add(to: guides, "Clear All Guides", #selector(clearGuides))
        let guidesItem = NSMenuItem(title: "Guides", action: nil, keyEquivalent: "")
        guidesItem.submenu = guides
        menu.addItem(guidesItem)

        let measure = NSMenu()
        for modifier in MeasureModifier.allCases {
            let item = add(to: measure, modifier.title, #selector(setMeasureModifier(_:)))
            item.representedObject = NSNumber(value: modifier.rawValue)
            measureItems.append(item)
        }
        let measureItem = NSMenuItem(title: "Measure Gesture", action: nil, keyEquivalent: "")
        measureItem.submenu = measure
        menu.addItem(measureItem)

        menu.addItem(.separator())

        let units = NSMenu()
        itemPoints = add(to: units, "Points (logical pixels)", #selector(usePoints))
        itemDevicePixels = add(to: units, "Device Pixels (Retina)", #selector(useDevicePixels))
        let unitsItem = NSMenuItem(title: "Units", action: nil, keyEquivalent: "")
        unitsItem.submenu = units
        menu.addItem(unitsItem)

        let appearance = NSMenu()
        for option in Appearance.allCases {
            let item = add(to: appearance, option.title, #selector(setAppearance(_:)))
            item.representedObject = NSNumber(value: option.rawValue)
            appearanceItems.append(item)
        }
        let appearanceItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        appearanceItem.submenu = appearance
        menu.addItem(appearanceItem)

        let opacity = NSMenu()
        for value in [1.0, 0.85, 0.7, 0.5, 0.3] {
            let item = add(to: opacity, "\(Int(value * 100))%", #selector(setOpacity(_:)))
            item.representedObject = NSNumber(value: value)
            opacityItems.append(item)
        }
        let opacityItem = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        opacityItem.submenu = opacity
        menu.addItem(opacityItem)

        itemClickThrough = add(to: menu, "Click-Through (ignore mouse)", #selector(toggleClickThrough))

        menu.addItem(.separator())
        _ = add(to: menu, "Reset Position & Size", #selector(resetGeometry))
        _ = add(to: menu, "Reset Zero Marks", #selector(resetZeros))

        itemLaunchAtLogin = add(to: menu, "Launch at Login", #selector(toggleLaunchAtLogin))

        menu.addItem(.separator())
        _ = add(to: menu, "Ruler Help…", #selector(showHelp), key: "?")
        _ = add(to: menu, "Quit Ruler", #selector(quit), key: "q")
        return menu
    }

    @discardableResult
    private func add(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        let s = Settings.shared
        itemHorizontal.state = s.showHorizontal ? .on : .off
        itemVertical.state = s.showVertical ? .on : .off
        itemPoints.state = s.devicePixels ? .off : .on
        itemDevicePixels.state = s.devicePixels ? .on : .off
        for item in appearanceItems {
            let raw = (item.representedObject as? NSNumber)?.intValue ?? 0
            item.state = raw == s.appearance.rawValue ? .on : .off
        }
        itemClickThrough.state = s.clickThrough ? .on : .off
        itemCrosshair.state = s.crosshairEnabled ? .on : .off
        itemLaunchAtLogin.state = SMAppService.mainApp.status == .enabled ? .on : .off
        for item in measureItems {
            let raw = (item.representedObject as? NSNumber)?.intValue ?? 0
            item.state = raw == s.measureModifier.rawValue ? .on : .off
        }
        for item in opacityItems {
            let value = (item.representedObject as? NSNumber)?.doubleValue ?? 1
            item.state = abs(value - s.opacity) < 0.001 ? .on : .off
        }
    }

    // MARK: - Actions

    @objc private func toggleHorizontal() { Settings.shared.showHorizontal.toggle() }
    @objc private func toggleVertical() { Settings.shared.showVertical.toggle() }
    @objc private func usePoints() { Settings.shared.devicePixels = false }
    @objc private func useDevicePixels() { Settings.shared.devicePixels = true }
    @objc private func setAppearance(_ sender: NSMenuItem) {
        guard let n = sender.representedObject as? NSNumber,
              let option = Appearance(rawValue: n.intValue) else { return }
        Settings.shared.appearance = option
    }
    @objc private func toggleClickThrough() { Settings.shared.clickThrough.toggle() }
    @objc private func toggleCrosshair() { Settings.shared.crosshairEnabled.toggle() }

    @objc private func setMeasureModifier(_ sender: NSMenuItem) {
        guard let n = sender.representedObject as? NSNumber,
              let modifier = MeasureModifier(rawValue: n.intValue) else { return }
        Settings.shared.measureModifier = modifier
    }

    @objc private func addHorizontalGuide() { controller.addGuideAtPointer(orientation: .horizontal) }
    @objc private func addVerticalGuide() { controller.addGuideAtPointer(orientation: .vertical) }
    @objc private func clearGuides() { GuideManager.shared.clear() }

    @objc private func setOpacity(_ sender: NSMenuItem) {
        guard let n = sender.representedObject as? NSNumber else { return }
        Settings.shared.opacity = n.doubleValue
    }

    @objc private func resetGeometry() {
        controller.resetGeometry()
    }

    @objc private func resetZeros() {
        Settings.shared.setZeroOffset(0, for: .horizontal)
        Settings.shared.setZeroOffset(0, for: .vertical)
        controller.applySettings()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change the login item"
            alert.informativeText = "\(error.localizedDescription)\n\nMoving Ruler to your Applications folder usually fixes this."
            alert.alertStyle = .warning
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func showHelp() {
        HelpWindowController.shared.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
