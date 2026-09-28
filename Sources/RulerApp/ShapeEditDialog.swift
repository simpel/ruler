import AppKit

/// A compact, high-contrast HUD dialog allowing the user to precisely set and scrub
/// all values (position relative to rulers, position relative to screen, and dimensions)
/// for an existing shape with live autoupdates.
final class ShapeEditDialogController: NSObject, NSWindowDelegate {

    static let shared = ShapeEditDialogController()

    private var window: NSPanel?
    private weak var targetWindow: MeasurementWindow?

    // Ruler-relative position
    private let xField = ScrubbableField()
    private let yField = ScrubbableField()

    // Screen-relative position
    private let scrXField = ScrubbableField()
    private let scrYField = ScrubbableField()

    // Dimensions
    private let wField = ScrubbableField()
    private let hField = ScrubbableField()

    // Shape-specific
    private let rField = ScrubbableField()
    private let lField = ScrubbableField()
    private var rRow: NSStackView?
    private var lRow: NSStackView?

    private var isSyncingFields = false

    private enum CoordSource { case ruler, screen }

    private override init() {
        super.init()
    }

    func show(for target: MeasurementWindow) {
        self.targetWindow = target
        if window == nil { window = makeWindow() }

        populateFields(from: target)

        if let win = window {
            NSApp.activate(ignoringOtherApps: true)
            win.center()
            win.makeKeyAndOrderFront(nil)
        }
    }

    func syncIfActive(for target: MeasurementWindow) {
        guard let win = window, win.isVisible, targetWindow === target, !isSyncingFields else { return }
        populateFields(from: target)
    }

    private func makeWindow() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 284, height: 220),
                            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.title = "Shape Settings"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.delegate = self
        panel.contentView = makeContentView()
        return panel
    }

    private func makeContentView() -> NSView {
        let view = NSView()
        view.wantsLayer = true

        let bgView = ShapeEditBackgroundView()
        bgView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bgView)
        NSLayoutConstraint.activate([
            bgView.topAnchor.constraint(equalTo: view.topAnchor),
            bgView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bgView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 6
        rootStack.edgeInsets = NSEdgeInsets(top: 26, left: 18, bottom: 16, right: 18)
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let makeRow = { [weak self] (label1: String, field1: ScrubbableField, label2: String, field2: ScrubbableField, isScreen: Bool) -> NSStackView in
            guard let self else { return NSStackView() }
            self.configureField(field1)
            self.configureField(field2)

            let l1 = self.makeLabel(text: label1, isScreen: isScreen, field: field1)
            let l2 = self.makeLabel(text: label2, isScreen: isScreen, field: field2)

            field1.onScrubDelta = { [weak self] delta in self?.scrub(field: field1, delta: delta) }
            field2.onScrubDelta = { [weak self] delta in self?.scrub(field: field2, delta: delta) }

            let col1 = NSStackView(views: [l1, field1])
            col1.orientation = .horizontal
            col1.spacing = 6
            field1.widthAnchor.constraint(equalToConstant: 84).isActive = true

            let col2 = NSStackView(views: [l2, field2])
            col2.orientation = .horizontal
            col2.spacing = 6
            field2.widthAnchor.constraint(equalToConstant: 84).isActive = true

            let row = NSStackView(views: [col1, col2])
            row.orientation = .horizontal
            row.spacing = 16
            row.distribution = .fillEqually
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalToConstant: 248).isActive = true
            return row
        }

        // Section 1: Ruler Position
        let rulerLbl = makeSectionLabel("RULER POSITION")
        rootStack.addArrangedSubview(rulerLbl)
        rootStack.addArrangedSubview(makeRow("X", xField, "Y", yField, false))
        rootStack.setCustomSpacing(8, after: rootStack.arrangedSubviews.last!)

        // Section 2: Screen Position
        let scrLbl = makeSectionLabel("SCREEN POSITION")
        rootStack.addArrangedSubview(scrLbl)
        rootStack.addArrangedSubview(makeRow("X", scrXField, "Y", scrYField, true))
        rootStack.setCustomSpacing(8, after: rootStack.arrangedSubviews.last!)

        // Section 3: Dimensions
        let dimLbl = makeSectionLabel("DIMENSIONS")
        rootStack.addArrangedSubview(dimLbl)
        rootStack.addArrangedSubview(makeRow("W", wField, "H", hField, false))

        // Radius row for circles
        configureField(rField)
        rField.onScrubDelta = { [weak self] delta in self?.scrub(field: self?.rField ?? NSTextField(), delta: delta) }
        let rLabel = makeLabel(text: "R", isScreen: false, field: rField)
        rField.widthAnchor.constraint(equalToConstant: 84).isActive = true

        let rStack = NSStackView(views: [rLabel, rField])
        rStack.orientation = .horizontal
        rStack.spacing = 6

        let rRowView = NSStackView(views: [rStack])
        rRowView.orientation = .horizontal
        rRowView.translatesAutoresizingMaskIntoConstraints = false
        rRowView.widthAnchor.constraint(equalToConstant: 248).isActive = true
        self.rRow = rRowView
        rootStack.addArrangedSubview(rRowView)

        // Length row for lines
        configureField(lField)
        lField.onScrubDelta = { [weak self] delta in self?.scrub(field: self?.lField ?? NSTextField(), delta: delta) }
        let lLabel = makeLabel(text: "L", isScreen: false, field: lField)
        lField.widthAnchor.constraint(equalToConstant: 84).isActive = true

        let lStack = NSStackView(views: [lLabel, lField])
        lStack.orientation = .horizontal
        lStack.spacing = 6

        let lRowView = NSStackView(views: [lStack])
        lRowView.orientation = .horizontal
        lRowView.translatesAutoresizingMaskIntoConstraints = false
        lRowView.widthAnchor.constraint(equalToConstant: 248).isActive = true
        self.lRow = lRowView
        rootStack.addArrangedSubview(lRowView)

        for f in [xField, yField, scrXField, scrYField, wField, hField, rField, lField] {
            f.delegate = self
        }

        return view
    }

    private func makeLabel(text: String, isScreen: Bool, field: ScrubbableField) -> ScrubbableLabel {
        let label = ScrubbableLabel()
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.alignment = .center
        label.onScrubDelta = { [weak self] delta in self?.scrub(field: field, delta: delta) }

        if isScreen {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [Palette.guideLine]))
            if let img = NSImage(systemSymbolName: "display", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let attachment = NSTextAttachment()
                attachment.image = img
                attachment.bounds = NSRect(x: 0, y: -1.0, width: img.size.width, height: img.size.height)
                let attr = NSMutableAttributedString(attachment: attachment)
                attr.append(NSAttributedString(string: " \(text)", attributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                    .foregroundColor: Palette.guideLine
                ]))
                label.attributedStringValue = attr
            } else {
                label.font = NSFont.systemFont(ofSize: 11, weight: .bold)
                label.textColor = Palette.guideLine
                label.stringValue = text
            }
            label.widthAnchor.constraint(equalToConstant: 28).isActive = true
        } else {
            label.font = NSFont.systemFont(ofSize: 11, weight: .bold)
            label.textColor = Palette.guideLine
            label.stringValue = text
            label.widthAnchor.constraint(equalToConstant: 18).isActive = true
        }
        return label
    }

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 9.5, weight: .bold)
        label.textColor = NSColor(calibratedWhite: 0.65, alpha: 1.0)
        return label
    }

    private func configureField(_ field: NSTextField) {
        field.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        field.textColor = NSColor(calibratedWhite: 0.98, alpha: 1.0)
        field.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.8)
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.alignment = .center
    }

    private func populateFields(from target: MeasurementWindow) {
        let isCircle = target.shapeType == .circle
        let isLine = target.shapeType == .line
        rRow?.isHidden = !isCircle
        lRow?.isHidden = !isLine

        let h: CGFloat = (isCircle || isLine) ? 256 : 224
        if let win = window {
            var f = win.frame
            f.origin.y += f.size.height - h
            f.size.height = h
            win.setFrame(f, display: true, animate: false)
        }

        let anchor = target.anchor
        let current = target.current
        let box = NSRect(x: min(anchor.x, current.x), y: min(anchor.y, current.y),
                         width: abs(anchor.x - current.x), height: abs(anchor.y - current.y))

        let screen = NSScreen.screens.first { $0.frame.contains(current) } ?? NSScreen.main ?? NSScreen.screens[0]
        let scale: CGFloat = Settings.shared.devicePixels ? screen.backingScaleFactor : 1
        let scrFrame = screen.frame
        let zero = RulerController.shared.globalZeroOrigin(on: screen)

        let posX = (box.minX - zero.x) * scale
        let posY = (zero.y - box.maxY) * scale
        let scrX = (box.minX - scrFrame.minX) * scale
        let scrY = (scrFrame.maxY - box.maxY) * scale
        let width = box.width * scale
        let height = box.height * scale
        let radius = (width + height) / 4.0
        let length = hypot(current.x - anchor.x, current.y - anchor.y) * scale

        isSyncingFields = true
        xField.stringValue = "\(Int(posX.rounded()))"
        yField.stringValue = "\(Int(posY.rounded()))"
        scrXField.stringValue = "\(Int(scrX.rounded()))"
        scrYField.stringValue = "\(Int(scrY.rounded()))"
        wField.stringValue = "\(Int(width.rounded()))"
        hField.stringValue = "\(Int(height.rounded()))"
        rField.stringValue = "\(Int(radius.rounded()))"
        lField.stringValue = "\(Int(length.rounded()))"
        isSyncingFields = false
    }

    @objc private func onClose() {
        window?.orderOut(nil)
    }

    private func scrub(field: NSTextField, delta: CGFloat) {
        guard let target = targetWindow else { return }
        let screen = NSScreen.screens.first { $0.frame.contains(target.current) } ?? NSScreen.main ?? NSScreen.screens[0]
        let scale: CGFloat = Settings.shared.devicePixels ? screen.backingScaleFactor : 1

        if field === rField {
            let currentW = max(5, Double(wField.stringValue) ?? 100)
            let currentH = max(5, Double(hField.stringValue) ?? 100)
            let currentR = (currentW + currentH) / 4.0
            let newR = max(3, currentR + delta)
            let s = newR / max(1, currentR)
            let newW = max(5, (currentW * s).rounded())
            let newH = max(5, (currentH * s).rounded())

            isSyncingFields = true
            rField.stringValue = "\(Int(newR.rounded()))"
            wField.stringValue = "\(Int(newW))"
            hField.stringValue = "\(Int(newH))"
            isSyncingFields = false
            applyLive()
            return
        }

        if field === lField {
            let currentL = max(5, hypot(target.current.x - target.anchor.x, target.current.y - target.anchor.y) * scale)
            let newL = max(5, currentL + delta)
            let s = newL / currentL
            let newCurrent = NSPoint(x: (target.anchor.x + (target.current.x - target.anchor.x) * s).rounded(),
                                     y: (target.anchor.y + (target.current.y - target.anchor.y) * s).rounded())
            target.move(toAnchor: target.anchor, current: newCurrent)
            populateFields(from: target)
            return
        }

        if field === xField || field === scrXField {
            let cur = Double(field.stringValue) ?? 0
            field.stringValue = "\(Int((cur + delta).rounded()))"
            applyLive(preferredXSource: field === xField ? .ruler : .screen, preferredYSource: .ruler)
            return
        }

        if field === yField || field === scrYField {
            let cur = Double(field.stringValue) ?? 0
            field.stringValue = "\(Int((cur + delta).rounded()))"
            applyLive(preferredXSource: .ruler, preferredYSource: field === yField ? .ruler : .screen)
            return
        }

        let currentVal = Double(field.stringValue) ?? 0
        let isDim = (field === wField || field === hField)
        let newVal = isDim ? max(5, currentVal + delta) : currentVal + delta
        field.stringValue = "\(Int(newVal.rounded()))"

        syncCircleFields(modified: field)
        applyLive()
    }

    private func syncCircleFields(modified field: NSTextField) {
        guard targetWindow?.shapeType == .circle else { return }
        isSyncingFields = true
        defer { isSyncingFields = false }

        if field === rField {
            let currentW = max(5, Double(wField.stringValue) ?? 100)
            let currentH = max(5, Double(hField.stringValue) ?? 100)
            let currentR = (currentW + currentH) / 4.0
            let newR = max(3, Double(rField.stringValue) ?? currentR)
            if currentR > 0 {
                let s = newR / currentR
                let newW = max(5, (currentW * s).rounded())
                let newH = max(5, (currentH * s).rounded())
                wField.stringValue = "\(Int(newW))"
                hField.stringValue = "\(Int(newH))"
            }
        } else if field === wField || field === hField {
            let w = Double(wField.stringValue) ?? 100
            let h = Double(hField.stringValue) ?? 100
            rField.stringValue = "\(Int(((w + h) / 4.0).rounded()))"
        }
    }

    private func applyLive(preferredXSource: CoordSource = .ruler, preferredYSource: CoordSource = .ruler) {
        guard let target = targetWindow else { return }

        let screen = NSScreen.screens.first { $0.frame.contains(target.current) } ?? NSScreen.main ?? NSScreen.screens[0]
        let scale: CGFloat = Settings.shared.devicePixels ? screen.backingScaleFactor : 1
        let scrFrame = screen.frame
        let zero = RulerController.shared.globalZeroOrigin(on: screen)

        let width = max(5, CGFloat(Double(wField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 10))
        let height = max(5, CGFloat(Double(hField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 10))

        let globalMinX: CGFloat
        if preferredXSource == .screen {
            let scrX = CGFloat(Double(scrXField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0)
            globalMinX = scrFrame.minX + scrX / scale
        } else {
            let rulerX = CGFloat(Double(xField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0)
            globalMinX = zero.x + rulerX / scale
        }

        let globalMaxY: CGFloat
        if preferredYSource == .screen {
            let scrY = CGFloat(Double(scrYField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0)
            globalMaxY = scrFrame.maxY - scrY / scale
        } else {
            let rulerY = CGFloat(Double(yField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0)
            globalMaxY = zero.y - rulerY / scale
        }

        let globalWidth = width / scale
        let globalHeight = height / scale

        let newAnchor = NSPoint(x: globalMinX.rounded(), y: globalMaxY.rounded())
        let newCurrent = NSPoint(x: (globalMinX + globalWidth).rounded(), y: (globalMaxY - globalHeight).rounded())

        target.move(toAnchor: newAnchor, current: newCurrent)

        isSyncingFields = true
        let box = NSRect(x: min(newAnchor.x, newCurrent.x), y: min(newAnchor.y, newCurrent.y),
                         width: abs(newAnchor.x - newCurrent.x), height: abs(newAnchor.y - newCurrent.y))
        let newRulerX = (box.minX - zero.x) * scale
        let newRulerY = (zero.y - box.maxY) * scale
        let newScrX = (box.minX - scrFrame.minX) * scale
        let newScrY = (scrFrame.maxY - box.maxY) * scale

        xField.stringValue = "\(Int(newRulerX.rounded()))"
        yField.stringValue = "\(Int(newRulerY.rounded()))"
        scrXField.stringValue = "\(Int(newScrX.rounded()))"
        scrYField.stringValue = "\(Int(newScrY.rounded()))"
        isSyncingFields = false
    }
}

extension ShapeEditDialogController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard !isSyncingFields, let field = obj.object as? NSTextField else { return }
        let prefX: CoordSource = (field === scrXField) ? .screen : .ruler
        let prefY: CoordSource = (field === scrYField) ? .screen : .ruler
        syncCircleFields(modified: field)
        applyLive(preferredXSource: prefX, preferredYSource: prefY)
    }
}

private final class ShapeEditBackgroundView: NSView {
    private let gradient = NSGradient(starting: NSColor(calibratedRed: 0x22 / 255.0, green: 0x26 / 255.0, blue: 0x2E / 255.0, alpha: 0.98),
                                      ending: NSColor(calibratedRed: 0x14 / 255.0, green: 0x16 / 255.0, blue: 0x1B / 255.0, alpha: 0.98))!
    private let strokeColor = NSColor(calibratedWhite: 0.32, alpha: 0.8)

    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
        gradient.draw(in: shape, angle: -90)
        strokeColor.setStroke()
        shape.lineWidth = 1
        shape.stroke()
    }
}
