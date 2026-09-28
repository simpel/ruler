import AppKit

/// Content view for the Control panel (Charcoal Dark HUD) with crisp subpixel font smoothing,
/// full layer backing, and flattened subviews to guarantee razor-sharp rendering in active and inactive states.
final class ControlContentView: NSView {

    // High-contrast Charcoal palette (100% opaque for crisp subpixel font smoothing)
    private let charcoalGradient = NSGradient(starting: NSColor(calibratedRed: 0x22 / 255.0, green: 0x26 / 255.0, blue: 0x2E / 255.0, alpha: 1.0),
                                              ending: NSColor(calibratedRed: 0x14 / 255.0, green: 0x16 / 255.0, blue: 0x1B / 255.0, alpha: 1.0))!

    private let strokeColor = NSColor(calibratedWhite: 0.32, alpha: 1.0)
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
    private let opacityField = NSTextField()
    private let opacityStepper = NSStepper()

    // Action buttons with generous vertical inline padding
    private let btnReset = PaddedButton(title: "Reset Rulers", fontSize: 12)
    private let btnClear = PaddedButton(title: "Clear Measurements", fontSize: 12)
    private let btnClearGuides = PaddedButton(title: "Clear Guides", fontSize: 12)
    private let btnQuit = PaddedButton(title: "Quit Distanser", isDestructive: false, fontSize: 12)
    private let authorLink = NSButton()

    private var isSyncing = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        canDrawSubviewsIntoLayer = true
        appearance = NSAppearance(named: .darkAqua)
        setupLayout()
        bindActions()
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setAllowsFontSmoothing(true)
        context.setShouldSmoothFonts(true)

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

        opacityField.formatter = PercentageNumberFormatter()
        opacityField.font = NSFont.monospacedDigitSystemFont(ofSize: universalFontSize, weight: .regular)
        opacityField.textColor = textPrimary
        opacityField.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.8)
        opacityField.isBordered = true
        opacityField.bezelStyle = .roundedBezel
        opacityField.controlSize = .small
        opacityField.alignment = .center
        opacityField.translatesAutoresizingMaskIntoConstraints = false
        opacityField.widthAnchor.constraint(equalToConstant: 44).isActive = true

        opacityStepper.controlSize = .small
        opacityStepper.minValue = 0
        opacityStepper.maxValue = 100
        opacityStepper.increment = 1
        opacityStepper.valueWraps = false
        opacityStepper.translatesAutoresizingMaskIntoConstraints = false

        // Action buttons with 12pt font and generous 34pt height for vertical padding
        for btn in [btnReset, btnClear, btnClearGuides] {
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
            row.heightAnchor.constraint(equalToConstant: 26).isActive = true
            return row
        }

        let opacityRow = NSStackView(views: [opacityField, opacityStepper])
        opacityRow.orientation = .horizontal
        opacityRow.spacing = 3
        opacityRow.alignment = .centerY

        let displayStack = NSStackView(views: [
            makeControlRow(makeRowLabel("Horizontal Ruler"), switchHorizontal),
            makeControlRow(makeRowLabel("Vertical Ruler"), switchVertical),
            makeControlRow(makeRowLabel("Crosshair"), switchCrosshair),
            makeControlRow(makeRowLabel("Click-Through"), switchClickThrough),
            makeControlRow(opacityLabel, opacityRow),
        ])
        displayStack.orientation = .vertical
        displayStack.alignment = .leading
        displayStack.spacing = 7
        displayStack.translatesAutoresizingMaskIntoConstraints = false
        displayStack.widthAnchor.constraint(equalToConstant: 284).isActive = true

        // Shapes (top draw mode toggle: Rectangle / Circle)
        shapeSection.translatesAutoresizingMaskIntoConstraints = false
        shapeSection.widthAnchor.constraint(equalToConstant: 284).isActive = true
        rootStack.addArrangedSubview(shapeSection)
        rootStack.setCustomSpacing(12, after: shapeSection)

        let displayHeader = makeSection("DISPLAY")
        rootStack.addArrangedSubview(displayHeader)
        rootStack.setCustomSpacing(6, after: displayHeader)

        rootStack.addArrangedSubview(displayStack)
        rootStack.setCustomSpacing(14, after: displayStack)

        // Commands & Gestures
        commandsSection.translatesAutoresizingMaskIntoConstraints = false
        commandsSection.widthAnchor.constraint(equalToConstant: 284).isActive = true
        rootStack.addArrangedSubview(commandsSection)
        rootStack.setCustomSpacing(14, after: commandsSection)

        // Actions: Reset Rulers (full width), Clear Measurements & Guides (pair), Quit Distanser (full width)
        btnReset.translatesAutoresizingMaskIntoConstraints = false
        btnReset.widthAnchor.constraint(equalToConstant: 284).isActive = true
        btnReset.heightAnchor.constraint(equalToConstant: 34).isActive = true
        rootStack.addArrangedSubview(btnReset)
        rootStack.setCustomSpacing(8, after: btnReset)

        let clearRow = NSStackView(views: [btnClear, btnClearGuides])
        clearRow.orientation = .horizontal
        clearRow.distribution = .fillEqually
        clearRow.spacing = 8
        clearRow.translatesAutoresizingMaskIntoConstraints = false
        clearRow.widthAnchor.constraint(equalToConstant: 284).isActive = true
        clearRow.heightAnchor.constraint(equalToConstant: 34).isActive = true
        rootStack.addArrangedSubview(clearRow)
        rootStack.setCustomSpacing(8, after: clearRow)

        // Quit Button
        btnQuit.translatesAutoresizingMaskIntoConstraints = false
        btnQuit.widthAnchor.constraint(equalToConstant: 284).isActive = true
        btnQuit.heightAnchor.constraint(equalToConstant: 34).isActive = true
        rootStack.addArrangedSubview(btnQuit)
        rootStack.setCustomSpacing(12, after: btnQuit)

        // Author Link at the bottom
        authorLink.isBordered = false

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
        opacityStepper.target = self
        opacityStepper.action = #selector(onOpacityStepperChanged(_:))

        btnReset.target = self
        btnReset.action = #selector(onResetRulers)

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
        opacityStepper.integerValue = val
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

    @objc private func onOpacityStepperChanged(_ sender: NSStepper) {
        let val = sender.integerValue
        opacityField.stringValue = "\(val)"
        Settings.shared.opacity = Double(val) / 100.0
    }

    private func adjustOpacity(by delta: Int) {
        let currentVal = Int(opacityField.stringValue.filter { $0.isNumber }) ?? Int((Settings.shared.opacity * 100).rounded())
        let newVal = min(100, max(0, currentVal + delta))
        opacityField.stringValue = "\(newVal)"
        opacityStepper.integerValue = newVal
        Settings.shared.opacity = Double(newVal) / 100.0
        if let editor = opacityField.currentEditor() {
            editor.selectedRange = NSRange(location: 0, length: opacityField.stringValue.count)
        }
    }

    private func scrubOpacity(delta: CGFloat) {
        let currentVal = Double(opacityField.stringValue.filter { $0.isNumber }) ?? (Settings.shared.opacity * 100)
        let newVal = min(100, max(0, currentVal + delta))
        let intVal = Int(newVal.rounded())
        opacityField.stringValue = "\(intVal)"
        opacityStepper.integerValue = intVal
        Settings.shared.opacity = Double(intVal) / 100.0
    }

    @objc private func onResetRulers() {
        (NSApp.delegate as? AppDelegate)?.resetGeometryFromControls()
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
        let digits = field.stringValue.filter { $0.isNumber }
        if digits != field.stringValue {
            field.stringValue = digits
        }
        if let val = Int(digits) {
            let clamped = min(100, max(0, val))
            opacityStepper.integerValue = clamped
            Settings.shared.opacity = Double(clamped) / 100.0
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === opacityField else { return }
        let val = Int(field.stringValue.filter { $0.isNumber }) ?? Int((Settings.shared.opacity * 100).rounded())
        let clamped = min(100, max(0, val))
        field.stringValue = "\(clamped)"
        opacityStepper.integerValue = clamped
        Settings.shared.opacity = Double(clamped) / 100.0
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === opacityField else { return false }
        let step = NSEvent.modifierFlags.contains(.shift) ? 10 : 1
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            adjustOpacity(by: step)
            return true
        } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            adjustOpacity(by: -step)
            return true
        }
        return false
    }
}
