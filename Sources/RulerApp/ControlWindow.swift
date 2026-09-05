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
    }

    func toggle() {
        if let w = window, w.isVisible {
            w.orderOut(nil)
        } else {
            show()
        }
    }

    private func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 545),
                         styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                         backing: .buffered,
                         defer: false)
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
        return false
    }
}

// MARK: - Padded Button

/// A custom dark button with generous vertical inline padding and active click feedback.
private final class PaddedButton: NSButton {

    private let normalBg = NSColor(calibratedWhite: 0.22, alpha: 0.9)
    private let highlightBg = NSColor(calibratedWhite: 0.35, alpha: 0.9)
    private let normalBorder = NSColor(calibratedWhite: 0.38, alpha: 0.7)
    private let isDestructive: Bool

    init(title: String, isDestructive: Bool = false, fontSize: CGFloat = 12) {
        self.isDestructive = isDestructive
        super.init(frame: .zero)
        self.title = title
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = isDestructive
            ? NSColor(calibratedRed: 0.8, green: 0.25, blue: 0.25, alpha: 0.6).cgColor
            : normalBorder.cgColor
        layer?.backgroundColor = isDestructive
            ? NSColor(calibratedRed: 0.5, green: 0.15, blue: 0.15, alpha: 0.35).cgColor
            : normalBg.cgColor

        let p = NSMutableParagraphStyle()
        p.alignment = .center
        attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.98, alpha: 1.0),
            .paragraphStyle: p,
        ])
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        if isDestructive {
            layer?.backgroundColor = flag
                ? NSColor(calibratedRed: 0.65, green: 0.2, blue: 0.2, alpha: 0.5).cgColor
                : NSColor(calibratedRed: 0.5, green: 0.15, blue: 0.15, alpha: 0.35).cgColor
        } else {
            layer?.backgroundColor = flag ? highlightBg.cgColor : normalBg.cgColor
        }
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

    // Toggles
    private let checkHorizontal = NSButton(checkboxWithTitle: "Horizontal Ruler", target: nil, action: nil)
    private let checkVertical = NSButton(checkboxWithTitle: "Vertical Ruler", target: nil, action: nil)
    private let checkCrosshair = NSButton(checkboxWithTitle: "Crosshair", target: nil, action: nil)
    private let checkClickThrough = NSButton(checkboxWithTitle: "Click-Through", target: nil, action: nil)

    // Units
    private let unitsSegment = NSSegmentedControl(labels: ["Points", "Device Pixels"],
                                                  trackingMode: .selectOne, target: nil, action: nil)

    // Gesture
    private let gestureSegment = NSSegmentedControl(labels: ["Shift", "⇧⌘", "⌥⌘"],
                                                    trackingMode: .selectOne, target: nil, action: nil)

    // Opacity
    private let opacityLabel = NSTextField(labelWithString: "100%")
    private let opacitySlider = NSSlider(value: 1.0, minValue: 0.3, maxValue: 1.0, target: nil, action: nil)

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

        // Checkboxes with 12pt font
        for btn in [checkHorizontal, checkVertical, checkCrosshair, checkClickThrough] {
            btn.attributedTitle = NSAttributedString(string: btn.title, attributes: [
                .font: NSFont.systemFont(ofSize: universalFontSize, weight: .regular),
                .foregroundColor: textPrimary,
            ])
        }

        unitsSegment.controlSize = .regular
        unitsSegment.font = NSFont.systemFont(ofSize: universalFontSize, weight: .regular)
        gestureSegment.controlSize = .regular
        gestureSegment.font = NSFont.systemFont(ofSize: universalFontSize, weight: .regular)
        opacitySlider.controlSize = .regular

        opacityLabel.font = NSFont.monospacedDigitSystemFont(ofSize: universalFontSize, weight: .medium)
        opacityLabel.textColor = textPrimary

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

        // Display rows with more breathing room
        let rulerRow = NSStackView(views: [checkHorizontal, checkVertical])
        rulerRow.orientation = .horizontal
        rulerRow.spacing = 20

        let optRow = NSStackView(views: [checkCrosshair, checkClickThrough])
        optRow.orientation = .horizontal
        optRow.spacing = 20

        rootStack.addArrangedSubview(makeSection("DISPLAY"))
        rootStack.addArrangedSubview(rulerRow)
        rootStack.addArrangedSubview(optRow)

        // Units
        rootStack.addArrangedSubview(makeSection("UNITS"))
        unitsSegment.translatesAutoresizingMaskIntoConstraints = false
        unitsSegment.widthAnchor.constraint(equalToConstant: 284).isActive = true
        rootStack.addArrangedSubview(unitsSegment)

        // Measure Gesture
        rootStack.addArrangedSubview(makeSection("MEASURE GESTURE"))
        gestureSegment.translatesAutoresizingMaskIntoConstraints = false
        gestureSegment.widthAnchor.constraint(equalToConstant: 284).isActive = true
        rootStack.addArrangedSubview(gestureSegment)

        // Opacity
        let opHeader = NSStackView(views: [makeSection("OPACITY"), opacityLabel])
        opHeader.orientation = .horizontal
        opHeader.distribution = .equalSpacing
        opHeader.translatesAutoresizingMaskIntoConstraints = false
        opHeader.widthAnchor.constraint(equalToConstant: 284).isActive = true
        rootStack.addArrangedSubview(opHeader)

        opacitySlider.translatesAutoresizingMaskIntoConstraints = false
        opacitySlider.widthAnchor.constraint(equalToConstant: 284).isActive = true
        rootStack.addArrangedSubview(opacitySlider)

        // Actions: 2x2 grid with generous 34pt vertical padding
        rootStack.addArrangedSubview(makeSection("ACTIONS"))
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
        checkHorizontal.target = self
        checkHorizontal.action = #selector(onToggleHorizontal)

        checkVertical.target = self
        checkVertical.action = #selector(onToggleVertical)

        checkCrosshair.target = self
        checkCrosshair.action = #selector(onToggleCrosshair)

        checkClickThrough.target = self
        checkClickThrough.action = #selector(onToggleClickThrough)

        unitsSegment.target = self
        unitsSegment.action = #selector(onUnitsChanged)

        gestureSegment.target = self
        gestureSegment.action = #selector(onGestureChanged)

        opacitySlider.target = self
        opacitySlider.action = #selector(onOpacityChanged)

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
        checkHorizontal.state = s.showHorizontal ? .on : .off
        checkVertical.state = s.showVertical ? .on : .off
        checkCrosshair.state = s.crosshairEnabled ? .on : .off
        checkClickThrough.state = s.clickThrough ? .on : .off

        unitsSegment.selectedSegment = s.devicePixels ? 1 : 0
        gestureSegment.selectedSegment = s.measureModifier.rawValue
        opacitySlider.doubleValue = s.opacity
        opacityLabel.stringValue = "\(Int(s.opacity * 100))%"
    }

    @objc private func onToggleHorizontal() {
        Settings.shared.showHorizontal = checkHorizontal.state == .on
    }

    @objc private func onToggleVertical() {
        Settings.shared.showVertical = checkVertical.state == .on
    }

    @objc private func onToggleCrosshair() {
        Settings.shared.crosshairEnabled = checkCrosshair.state == .on
    }

    @objc private func onToggleClickThrough() {
        Settings.shared.clickThrough = checkClickThrough.state == .on
    }

    @objc private func onUnitsChanged() {
        Settings.shared.devicePixels = unitsSegment.selectedSegment == 1
    }

    @objc private func onGestureChanged() {
        if let modifier = MeasureModifier(rawValue: gestureSegment.selectedSegment) {
            Settings.shared.measureModifier = modifier
        }
    }

    @objc private func onOpacityChanged() {
        let val = (opacitySlider.doubleValue * 100).rounded() / 100
        Settings.shared.opacity = val
        opacityLabel.stringValue = "\(Int(val * 100))%"
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
