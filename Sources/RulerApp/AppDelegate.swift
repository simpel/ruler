import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let controller = RulerController.shared
    private var statusItem: NSStatusItem!

    // Items whose checkmarks are refreshed when the menu opens.
    private var itemHorizontal: NSMenuItem!
    private var itemVertical: NSMenuItem!
    private var itemClickThrough: NSMenuItem!
    private var itemCrosshair: NSMenuItem!
    private var itemLaunchAtLogin: NSMenuItem!
    private var itemDrawRect: NSMenuItem!
    private var itemDrawCircle: NSMenuItem!
    private var opacityItems: [NSMenuItem] = []
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()
        setupMainMenu()
        setupKeyMonitor()
        controller.start()
        ControlWindowController.shared.show()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        _ = add(to: appMenu, "About Distanser", #selector(showHelp))
        appMenu.addItem(.separator())
        _ = add(to: appMenu, "Distanser Controls…", #selector(showSettings), key: ",")
        appMenu.addItem(.separator())
        _ = add(to: appMenu, "Quit Distanser", #selector(quit), key: "q")
        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.command) else { return event }
            guard let char = event.charactersIgnoringModifiers?.lowercased() else { return event }

            if char == "q" {
                self?.quit()
                return nil
            }
            if char == "w" {
                if let keyWindow = NSApp.keyWindow, keyWindow.isVisible {
                    keyWindow.performClose(nil)
                    return nil
                }
            }
            if char == "," {
                self?.showSettings()
                return nil
            }
            return event
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "ruler", accessibilityDescription: "Distanser")
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

        let shapes = NSMenu()
        itemDrawRect = add(to: shapes, "Draw Rectangles", #selector(setDrawRectangle), key: "4")
        itemDrawCircle = add(to: shapes, "Draw Circles", #selector(setDrawCircle), key: "5")
        shapes.addItem(.separator())
        _ = add(to: shapes, "Clear All Shapes", #selector(clearMeasurements))
        let shapesItem = NSMenuItem(title: "Shapes", action: nil, keyEquivalent: "")
        shapesItem.submenu = shapes
        menu.addItem(shapesItem)

        menu.addItem(.separator())

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
        _ = add(to: menu, "Clear All Measurements", #selector(clearMeasurements))
        _ = add(to: menu, "Reset Position & Size", #selector(resetGeometry))
        _ = add(to: menu, "Reset Zero Marks", #selector(resetZeros))

        itemLaunchAtLogin = add(to: menu, "Launch at Login", #selector(toggleLaunchAtLogin))

        menu.addItem(.separator())
        _ = add(to: menu, "Distanser Controls…", #selector(showSettings), key: ",")
        _ = add(to: menu, "Distanser Help…", #selector(showHelp), key: "?")
        _ = add(to: menu, "Quit Distanser", #selector(quit), key: "q")
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
        itemClickThrough.state = s.clickThrough ? .on : .off
        itemCrosshair.state = s.crosshairEnabled ? .on : .off
        itemLaunchAtLogin.state = SMAppService.mainApp.status == .enabled ? .on : .off
        itemDrawRect.state = s.drawShapeType == .rectangle ? .on : .off
        itemDrawCircle.state = s.drawShapeType == .circle ? .on : .off
        for item in opacityItems {
            let value = (item.representedObject as? NSNumber)?.doubleValue ?? 1
            item.state = abs(value - s.opacity) < 0.001 ? .on : .off
        }
    }

    // MARK: - Actions

    @objc private func toggleHorizontal() { Settings.shared.showHorizontal.toggle() }
    @objc private func toggleVertical() { Settings.shared.showVertical.toggle() }
    @objc private func toggleClickThrough() { Settings.shared.clickThrough.toggle() }
    @objc private func toggleCrosshair() { Settings.shared.crosshairEnabled.toggle() }
    @objc private func setDrawRectangle() {
        Settings.shared.drawShapeType = .rectangle
        controller.activateContext()
    }
    @objc private func setDrawCircle() {
        Settings.shared.drawShapeType = .circle
        controller.activateContext()
    }

    @objc private func addHorizontalGuide() { controller.addGuideAtPointer(orientation: .horizontal) }
    @objc private func addVerticalGuide() { controller.addGuideAtPointer(orientation: .vertical) }
    @objc private func clearGuides() { GuideManager.shared.clear() }
    @objc private func clearMeasurements() { controller.clearMeasurements() }

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
            alert.informativeText = "\(error.localizedDescription)\n\nMoving Distanser to your Applications folder usually fixes this."
            alert.alertStyle = .warning
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc func showSettings() {
        ControlWindowController.shared.show()
    }

    func resetGeometryFromControls() {
        controller.resetGeometry()
    }

    func applySettingsFromControls() {
        controller.applySettings()
    }

    func clearMeasurementsFromControls() {
        controller.clearMeasurements()
    }

    @objc private func showHelp() {
        HelpWindowController.shared.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
