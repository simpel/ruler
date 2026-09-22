import AppKit

/// A compact, high-contrast HUD dialog allowing the user to precisely set all values
/// (position and dimensions) for an existing shape on the screen.
final class ShapeEditDialogController: NSObject, NSWindowDelegate {

    static let shared = ShapeEditDialogController()

    private var window: NSPanel?
    private weak var targetWindow: MeasurementWindow?

    private let titleLabel = NSTextField(labelWithString: "Set Shape Values")
    private let shapeTypeBadge = NSTextField(labelWithString: "Rectangle")

    private let xField = NSTextField()
    private let yField = NSTextField()
    private let wField = NSTextField()
    private let hField = NSTextField()
    private let rField = NSTextField()
    private var rRow: NSStackView?

    private let btnCancel = PaddedButton(title: "Cancel", fontSize: 12)
    private let btnApply = PaddedButton(title: "Apply", fontSize: 12)

    private var isSyncingFields = false

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

    private func makeWindow() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 310),
                            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.title = "Set Shape Values"
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
        rootStack.spacing = 10
        rootStack.edgeInsets = NSEdgeInsets(top: 24, left: 18, bottom: 18, right: 18)
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = NSColor(calibratedWhite: 0.98, alpha: 1.0)

        shapeTypeBadge.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        shapeTypeBadge.textColor = Palette.guideLine

        let headerRow = NSStackView(views: [titleLabel, shapeTypeBadge])
        headerRow.orientation = .horizontal
        headerRow.distribution = .equalSpacing
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.widthAnchor.constraint(equalToConstant: 244).isActive = true
        rootStack.addArrangedSubview(headerRow)

        let makeRow = { [weak self] (label1: String, field1: NSTextField, label2: String, field2: NSTextField) -> NSStackView in
            self?.configureField(field1)
            self?.configureField(field2)

            let l1 = NSTextField(labelWithString: label1)
            l1.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            l1.textColor = Palette.guideLine
            l1.widthAnchor.constraint(equalToConstant: 16).isActive = true

            let l2 = NSTextField(labelWithString: label2)
            l2.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            l2.textColor = Palette.guideLine
            l2.widthAnchor.constraint(equalToConstant: 16).isActive = true

            let col1 = NSStackView(views: [l1, field1])
            col1.orientation = .horizontal
            col1.spacing = 6
            field1.widthAnchor.constraint(equalToConstant: 86).isActive = true

            let col2 = NSStackView(views: [l2, field2])
            col2.orientation = .horizontal
            col2.spacing = 6
            field2.widthAnchor.constraint(equalToConstant: 86).isActive = true

            let row = NSStackView(views: [col1, col2])
            row.orientation = .horizontal
            row.spacing = 16
            row.distribution = .fillEqually
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalToConstant: 244).isActive = true
            return row
        }

        rootStack.addArrangedSubview(makeSectionLabel("POSITION (SCREEN)"))
        rootStack.addArrangedSubview(makeRow("X", xField, "Y", yField))

        rootStack.addArrangedSubview(makeSectionLabel("DIMENSIONS"))
        rootStack.addArrangedSubview(makeRow("W", wField, "H", hField))

        // Radius row for circles
        configureField(rField)
        let rLabel = NSTextField(labelWithString: "R")
        rLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        rLabel.textColor = Palette.guideLine
        rLabel.widthAnchor.constraint(equalToConstant: 16).isActive = true
        rField.widthAnchor.constraint(equalToConstant: 86).isActive = true

        let rStack = NSStackView(views: [rLabel, rField])
        rStack.orientation = .horizontal
        rStack.spacing = 6

        let rRowView = NSStackView(views: [rStack])
        rRowView.orientation = .horizontal
        rRowView.translatesAutoresizingMaskIntoConstraints = false
        rRowView.widthAnchor.constraint(equalToConstant: 244).isActive = true
        self.rRow = rRowView
        rootStack.addArrangedSubview(rRowView)

        // Action buttons
        btnCancel.heightAnchor.constraint(equalToConstant: 30).isActive = true
        btnApply.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let btnRow = NSStackView(views: [btnCancel, btnApply])
        btnRow.orientation = .horizontal
        btnRow.spacing = 8
        btnRow.distribution = .fillEqually
        btnRow.translatesAutoresizingMaskIntoConstraints = false
        btnRow.widthAnchor.constraint(equalToConstant: 244).isActive = true
        rootStack.addArrangedSubview(btnRow)

        btnCancel.target = self
        btnCancel.action = #selector(onCancel)
        btnApply.target = self
        btnApply.action = #selector(onApply)

        for f in [xField, yField, wField, hField, rField] {
            f.target = self
            f.action = #selector(onApply)
        }

        wField.delegate = self
        hField.delegate = self
        rField.delegate = self

        return view
    }

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = NSColor(calibratedWhite: 0.6, alpha: 1.0)
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
        shapeTypeBadge.stringValue = target.shapeType == .circle ? "CIRCLE" : "RECTANGLE"
        rRow?.isHidden = target.shapeType != .circle

        let anchor = target.anchor
        let current = target.current
        let box = NSRect(x: min(anchor.x, current.x), y: min(anchor.y, current.y),
                         width: abs(anchor.x - current.x), height: abs(anchor.y - current.y))

        let screen = NSScreen.screens.first { $0.frame.contains(current) } ?? NSScreen.main ?? NSScreen.screens[0]
        let scale: CGFloat = Settings.shared.devicePixels ? screen.backingScaleFactor : 1
        let scrFrame = screen.frame

        let posX = (box.minX - scrFrame.minX) * scale
        let posY = (scrFrame.maxY - box.maxY) * scale
        let width = box.width * scale
        let height = box.height * scale

        isSyncingFields = true
        xField.stringValue = "\(Int(posX.rounded()))"
        yField.stringValue = "\(Int(posY.rounded()))"
        wField.stringValue = "\(Int(width.rounded()))"
        hField.stringValue = "\(Int(height.rounded()))"
        rField.stringValue = "\(Int(((width + height) / 4.0).rounded()))"
        isSyncingFields = false
    }

    @objc private func onCancel() {
        window?.orderOut(nil)
    }

    @objc private func onApply() {
        guard let target = targetWindow else {
            window?.orderOut(nil)
            return
        }

        let screen = NSScreen.screens.first { $0.frame.contains(target.current) } ?? NSScreen.main ?? NSScreen.screens[0]
        let scale: CGFloat = Settings.shared.devicePixels ? screen.backingScaleFactor : 1
        let scrFrame = screen.frame

        let posX = CGFloat(Double(xField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0)
        let posY = CGFloat(Double(yField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0)
        let width = max(10, CGFloat(Double(wField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 100))
        let height = max(10, CGFloat(Double(hField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 100))

        let globalMinX = scrFrame.minX + posX / scale
        let globalMaxY = scrFrame.maxY - posY / scale
        let globalWidth = width / scale
        let globalHeight = height / scale

        let newAnchor = NSPoint(x: globalMinX.rounded(), y: globalMaxY.rounded())
        let newCurrent = NSPoint(x: (globalMinX + globalWidth).rounded(), y: (globalMaxY - globalHeight).rounded())

        target.move(toAnchor: newAnchor, current: newCurrent)
        window?.orderOut(nil)
    }
}

extension ShapeEditDialogController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard !isSyncingFields, let field = obj.object as? NSTextField, targetWindow?.shapeType == .circle else { return }

        isSyncingFields = true
        defer { isSyncingFields = false }

        if field === rField {
            let r = Double(rField.stringValue) ?? 50
            let d = r * 2
            wField.stringValue = "\(Int(d.rounded()))"
            hField.stringValue = "\(Int(d.rounded()))"
        } else if field === wField && hField.stringValue == wField.stringValue {
            let w = Double(wField.stringValue) ?? 100
            rField.stringValue = "\(Int((w / 2.0).rounded()))"
        }
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
