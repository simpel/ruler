import AppKit

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
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        RulerController.shared.activateContext()
    }

    func toggle() {
        if let w = window, w.isVisible {
            w.orderOut(nil)
            RulerController.shared.deactivateContext()
        } else {
            show()
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        RulerController.shared.activateContext()
    }

    func windowDidResignKey(_ notification: Notification) {
        RulerController.shared.deactivateContext()
    }

    private func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 640),
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
        w.standardWindowButton(.zoomButton)?.isHidden = true
        return w
    }

    @objc private func settingsChanged() {
        contentView.syncWithSettings()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        RulerController.shared.deactivateContext()
        return false
    }
}

// MARK: - Content View (Charcoal Dark HUD)

private final class ControlContentView: NSView {

    // High-contrast Charcoal palette
    private let charcoalGradient = NSGradient(starting: NSColor(calibratedRed: 0x22 / 255.0, green: 0x26 / 255.0, blue: 0x2E / 255.0, alpha: 0.98),  // #22262E
                                              ending: NSColor(calibratedRed: 0x14 / 255.0, green: 0x16 / 255.0, blue: 0x1B / 255.0, alpha: 0.98))! // #14161B

    private let strokeColor = NSColor(calibratedWhite: 0.32, alpha: 0.8)
    private let textPrimary = NSColor(calibratedWhite: 0.98, alpha: 1.0)         // #FAFAFA (16.5:1 contrast)
    private let textSection = Palette.guideLine                                  // #F5B942 drafting amber (11:1 contrast)

    private let titleLabel = NSTextField(labelWithString: "Distanser Controls")

    // Shapes & Commands
    private let shapeSection = ShapeControlSection()
    private let commandsSection = CommandsSection()

    // Display Controls
    private let switchHorizontal = NSSwitch()
    private let switchVertical = NSSwitch()
    private let switchCrosshair = NSSwitch()
    private let switchClickThrough = NSSwitch()
    private let opacityLabel = ScrubbableLabel(labelWithString: "Opacity")
    private let opacityField = ScrubbableField()

    // Action buttons with generous vertical inline padding
    private let btnReset = PaddedButton(title: "Reset Geometry", fontSize: 12)
    private let btnResetZeros = PaddedButton(title: "Reset Zeros", fontSize: 12)
    private let btnClear = PaddedButton(title: "Clear Measurements", fontSize: 12)
    private let btnClearGuides = PaddedButton(title: "Clear Guides", fontSize: 12)
    private let btnQuit = PaddedButton(title: "Quit Distanser", isDestructive: false, fontSize: 12)
    private let authorLink = NSButton()

    private var isSyncing = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayout()
        bindActions()
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)

        // Matte charcoal gradient
        NSGraphicsContext.saveGraphicsState()
        charcoalGradient.draw(in: shape, angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        // Amber/bronze border
        strokeColor.setStroke()
        shape.lineWidth = 1
        shape.stroke()
    }

    private func setupLayout() {
        let universalFontSize: CGFloat = 12

        titleLabel.font = NSFont.systemFont(ofSize: universalFontSize, weight: .medium)
        titleLabel.textColor = textPrimary
        titleLabel.alignment = .center

        let makeSection = { [weak self] (text: String) -> NSTextField in
            let label = NSTextField(labelWithString: text)
            label.font = NSFont.systemFont(ofSize: universalFontSize, weight: .medium)
            label.textColor = self?.textSection ?? .systemBlue
            return label
        }

        for sw in [switchHorizontal, switchVertical, switchCrosshair, switchClickThrough] {
            sw.controlSize = .small
        }

        opacityLabel.font = NSFont.systemFont(ofSize: universalFontSize, weight: .regular)
        opacityLabel.textColor = textPrimary
        opacityLabel.onScrubDelta = { [weak self] delta in self?.scrubOpacity(delta: delta) }

        let opacityFormatter = NumberFormatter()
        opacityFormatter.minimum = 0
        opacityFormatter.maximum = 100
        opacityFormatter.allowsFloats = false
        opacityFormatter.maximumFractionDigits = 0
        opacityField.formatter = opacityFormatter
        opacityField.font = NSFont.monospacedDigitSystemFont(ofSize: universalFontSize, weight: .regular)
        opacityField.textColor = textPrimary
        opacityField.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.8)
        opacityField.isBordered = true
        opacityField.bezelStyle = .roundedBezel
        opacityField.alignment = .center
        opacityField.translatesAutoresizingMaskIntoConstraints = false
        opacityField.widthAnchor.constraint(equalToConstant: 48).isActive = true
        opacityField.onScrubDelta = { [weak self] delta in self?.scrubOpacity(delta: delta) }

        // Action buttons with 12pt font and generous 34pt height for vertical padding
        for btn in [btnReset, btnResetZeros, btnClear, btnClearGuides] {
            btn.heightAnchor.constraint(equalToConstant: 34).isActive = true
        }

        btnQuit.heightAnchor.constraint(equalToConstant: 34).isActive = true

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 11
        rootStack.edgeInsets = NSEdgeInsets(top: 40, left: 18, bottom: 18, right: 18)
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Centered window title in the header bar
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
        ])

        let makeRowLabel = { [weak self] (text: String) -> NSTextField in
            let label = NSTextField(labelWithString: text)
            label.font = NSFont.systemFont(ofSize: universalFontSize, weight: .regular)
            label.textColor = self?.textPrimary ?? .white
            return label
        }

        let makeControlRow = { (label: NSView, control: NSView) -> NSStackView in
            let row = NSStackView(views: [label, control])
            row.orientation = .horizontal
            row.distribution = .equalSpacing
            row.alignment = .centerY
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalToConstant: 284).isActive = true
            return row
        }

        let displayStack = NSStackView(views: [
            makeControlRow(makeRowLabel("Horizontal Ruler"), switchHorizontal),
            makeControlRow(makeRowLabel("Vertical Ruler"), switchVertical),
            makeControlRow(makeRowLabel("Crosshair"), switchCrosshair),
            makeControlRow(makeRowLabel("Click-Through"), switchClickThrough),
            makeControlRow(opacityLabel, opacityField),
        ])
        displayStack.orientation = .vertical
        displayStack.alignment = .leading
        displayStack.spacing = 7
        displayStack.translatesAutoresizingMaskIntoConstraints = false
        displayStack.widthAnchor.constraint(equalToConstant: 284).isActive = true

        rootStack.addArrangedSubview(makeSection("DISPLAY"))
        rootStack.addArrangedSubview(displayStack)

        // Shapes (draw mode)
        shapeSection.translatesAutoresizingMaskIntoConstraints = false
        shapeSection.widthAnchor.constraint(equalToConstant: 284).isActive = true
        rootStack.addArrangedSubview(shapeSection)

        // Commands & Gestures
        commandsSection.translatesAutoresizingMaskIntoConstraints = false
        commandsSection.widthAnchor.constraint(equalToConstant: 284).isActive = true
        rootStack.addArrangedSubview(commandsSection)
        rootStack.setCustomSpacing(14, after: commandsSection)

        // Actions: 2x2 grid with generous 34pt vertical padding
        let actionsRow1 = NSStackView(views: [btnReset, btnResetZeros])
        actionsRow1.orientation = .horizontal
        actionsRow1.distribution = .fillEqually
        actionsRow1.spacing = 8
        actionsRow1.translatesAutoresizingMaskIntoConstraints = false
        actionsRow1.widthAnchor.constraint(equalToConstant: 284).isActive = true
        actionsRow1.heightAnchor.constraint(equalToConstant: 34).isActive = true
        rootStack.addArrangedSubview(actionsRow1)

        let actionsRow2 = NSStackView(views: [btnClear, btnClearGuides])
        actionsRow2.orientation = .horizontal
        actionsRow2.distribution = .fillEqually
        actionsRow2.spacing = 8
        actionsRow2.translatesAutoresizingMaskIntoConstraints = false
        actionsRow2.widthAnchor.constraint(equalToConstant: 284).isActive = true
        actionsRow2.heightAnchor.constraint(equalToConstant: 34).isActive = true
        rootStack.addArrangedSubview(actionsRow2)

        // Quit Button
        btnQuit.translatesAutoresizingMaskIntoConstraints = false
        btnQuit.widthAnchor.constraint(equalToConstant: 284).isActive = true
        btnQuit.heightAnchor.constraint(equalToConstant: 34).isActive = true
        rootStack.addArrangedSubview(btnQuit)

        // Author Link at the bottom
        authorLink.isBordered = false
        authorLink.wantsLayer = true
        authorLink.layer?.backgroundColor = NSColor.clear.cgColor

        let p = NSMutableParagraphStyle()
        p.alignment = .center
        let str = NSMutableAttributedString(string: "Created by Joel Sandén", attributes: [
            .font: NSFont.systemFont(ofSize: universalFontSize, weight: .regular),
            .foregroundColor: NSColor(calibratedWhite: 0.60, alpha: 1.0),
            .paragraphStyle: p,
        ])
        let range = (str.string as NSString).range(of: "Joel Sandén")
        if range.location != NSNotFound {
            str.addAttributes([
                .foregroundColor: Palette.guideLine,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ], range: range)
        }
        authorLink.attributedTitle = str
        authorLink.translatesAutoresizingMaskIntoConstraints = false
        authorLink.widthAnchor.constraint(equalToConstant: 284).isActive = true
        authorLink.heightAnchor.constraint(equalToConstant: 24).isActive = true
        rootStack.addArrangedSubview(authorLink)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(authorLink.frame, cursor: .pointingHand)
    }

    private func bindActions() {
        switchHorizontal.target = self
        switchHorizontal.action = #selector(onToggleHorizontal)

        switchVertical.target = self
        switchVertical.action = #selector(onToggleVertical)

        switchCrosshair.target = self
        switchCrosshair.action = #selector(onToggleCrosshair)

        switchClickThrough.target = self
        switchClickThrough.action = #selector(onToggleClickThrough)

        opacityField.delegate = self

        btnReset.target = self
        btnReset.action = #selector(onResetGeometry)

        btnResetZeros.target = self
        btnResetZeros.action = #selector(onResetZeros)

        btnClear.target = self
        btnClear.action = #selector(onClearMeasurements)

        btnClearGuides.target = self
        btnClearGuides.action = #selector(onClearGuides)

        btnQuit.target = self
        btnQuit.action = #selector(onQuit)

        authorLink.target = self
        authorLink.action = #selector(onOpenAuthorWebsite)
    }

    func syncWithSettings() {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let s = Settings.shared
        switchHorizontal.state = s.showHorizontal ? .on : .off
        switchVertical.state = s.showVertical ? .on : .off
        switchCrosshair.state = s.crosshairEnabled ? .on : .off
        switchClickThrough.state = s.clickThrough ? .on : .off

        shapeSection.syncWithSettings()
        let val = Int((s.opacity * 100).rounded())
        if opacityField.currentEditor() == nil {
            opacityField.stringValue = "\(val)"
        }
    }

    @objc private func onToggleHorizontal() {
        Settings.shared.showHorizontal = switchHorizontal.state == .on
    }

    @objc private func onToggleVertical() {
        Settings.shared.showVertical = switchVertical.state == .on
    }

    @objc private func onToggleCrosshair() {
        Settings.shared.crosshairEnabled = switchCrosshair.state == .on
    }

    @objc private func onToggleClickThrough() {
        Settings.shared.clickThrough = switchClickThrough.state == .on
    }

    private func scrubOpacity(delta: CGFloat) {
        let currentVal = Double(opacityField.stringValue) ?? (Settings.shared.opacity * 100)
        let newVal = min(100, max(0, currentVal + delta))
        opacityField.stringValue = "\(Int(newVal.rounded()))"
        Settings.shared.opacity = newVal / 100.0
    }

    @objc private func onResetGeometry() {
        (NSApp.delegate as? AppDelegate)?.resetGeometryFromControls()
    }

    @objc private func onResetZeros() {
        Settings.shared.setZeroOffset(0, for: .horizontal)
        Settings.shared.setZeroOffset(0, for: .vertical)
        (NSApp.delegate as? AppDelegate)?.applySettingsFromControls()
    }

    @objc private func onClearMeasurements() {
        (NSApp.delegate as? AppDelegate)?.clearMeasurementsFromControls()
    }

    @objc private func onClearGuides() {
        GuideManager.shared.clear()
    }

    @objc private func onQuit() {
        NSApp.terminate(nil)
    }

    @objc private func onOpenAuthorWebsite() {
        if let url = URL(string: "https://www.joelsanden.se/ruler/") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension ControlContentView: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard !isSyncing, let field = obj.object as? NSTextField, field === opacityField else { return }
        if let val = Double(opacityField.stringValue.trimmingCharacters(in: .whitespaces)) {
            let clamped = min(100, max(0, val))
            Settings.shared.opacity = clamped / 100.0
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === opacityField else { return }
        let val = Double(opacityField.stringValue.trimmingCharacters(in: .whitespaces)) ?? (Settings.shared.opacity * 100)
        let clamped = min(100, max(0, val))
        opacityField.stringValue = "\(Int(clamped.rounded()))"
        Settings.shared.opacity = clamped / 100.0
    }
}
