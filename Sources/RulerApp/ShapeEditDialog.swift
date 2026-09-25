import AppKit

/// A compact, high-contrast HUD dialog allowing the user to precisely set and scrub
/// all values (position and dimensions) for an existing shape with live autoupdates.
final class ShapeEditDialogController: NSObject, NSWindowDelegate {

    static let shared = ShapeEditDialogController()

    private var window: NSPanel?
    private weak var targetWindow: MeasurementWindow?

    private let titleLabel = NSTextField(labelWithString: "Shape Settings")
    private let shapeTypeBadge = NSTextField(labelWithString: "RECTANGLE")

    private let xField = ScrubbableField()
    private let yField = ScrubbableField()
    private let wField = ScrubbableField()
    private let hField = ScrubbableField()
    private let rField = ScrubbableField()
    private var rRow: NSStackView?

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

    func syncIfActive(for target: MeasurementWindow) {
        guard let win = window, win.isVisible, targetWindow === target, !isSyncingFields else { return }
        populateFields(from: target)
    }

    private func makeWindow() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 240),
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
        rootStack.spacing = 10
        rootStack.edgeInsets = NSEdgeInsets(top: 20, left: 18, bottom: 20, right: 18)
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

        let closeBtn = NSButton()
        closeBtn.bezelStyle = .inline
        closeBtn.isBordered = false
        closeBtn.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .bold))
        closeBtn.contentTintColor = NSColor.white.withAlphaComponent(0.7)
        closeBtn.target = self
        closeBtn.action = #selector(onClose)
        closeBtn.widthAnchor.constraint(equalToConstant: 18).isActive = true
        closeBtn.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let titleGroup = NSStackView(views: [titleLabel, shapeTypeBadge])
        titleGroup.orientation = .horizontal
        titleGroup.spacing = 8

        let headerRow = NSStackView(views: [titleGroup, closeBtn])
        headerRow.orientation = .horizontal
        headerRow.distribution = .equalSpacing
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.widthAnchor.constraint(equalToConstant: 244).isActive = true
        rootStack.addArrangedSubview(headerRow)

        let makeRow = { [weak self] (label1: String, field1: ScrubbableField, label2: String, field2: ScrubbableField) -> NSStackView in
            guard let self else { return NSStackView() }
            self.configureField(field1)
            self.configureField(field2)

            let l1 = ScrubbableLabel(labelWithString: label1)
            l1.font = NSFont.systemFont(ofSize: 12, weight: .bold)
            l1.textColor = Palette.guideLine
            l1.alignment = .center
            l1.widthAnchor.constraint(equalToConstant: 16).isActive = true
            l1.onScrubDelta = { [weak self] delta in self?.scrub(field: field1, delta: delta) }

            let l2 = ScrubbableLabel(labelWithString: label2)
            l2.font = NSFont.systemFont(ofSize: 12, weight: .bold)
            l2.textColor = Palette.guideLine
            l2.alignment = .center
            l2.widthAnchor.constraint(equalToConstant: 16).isActive = true
            l2.onScrubDelta = { [weak self] delta in self?.scrub(field: field2, delta: delta) }

            field1.onScrubDelta = { [weak self] delta in self?.scrub(field: field1, delta: delta) }
            field2.onScrubDelta = { [weak self] delta in self?.scrub(field: field2, delta: delta) }

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
        rField.onScrubDelta = { [weak self] delta in self?.scrub(field: self?.rField ?? NSTextField(), delta: delta) }
        let rLabel = ScrubbableLabel(labelWithString: "R")
        rLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        rLabel.textColor = Palette.guideLine
        rLabel.alignment = .center
        rLabel.widthAnchor.constraint(equalToConstant: 16).isActive = true
        rLabel.onScrubDelta = { [weak self] delta in self?.scrub(field: self?.rField ?? NSTextField(), delta: delta) }
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

        for f in [xField, yField, wField, hField, rField] {
            f.delegate = self
        }

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

    @objc private func onClose() {
        window?.orderOut(nil)
    }

    private func scrub(field: NSTextField, delta: CGFloat) {
        let currentVal = Double(field.stringValue) ?? 0
        let isDim = (field === wField || field === hField || field === rField)
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
            let r = Double(rField.stringValue) ?? 50
            let d = r * 2
            wField.stringValue = "\(Int(d.rounded()))"
            hField.stringValue = "\(Int(d.rounded()))"
        } else if field === wField {
            let w = Double(wField.stringValue) ?? 100
            hField.stringValue = "\(Int(w.rounded()))"
            rField.stringValue = "\(Int((w / 2.0).rounded()))"
        } else if field === hField {
            let h = Double(hField.stringValue) ?? 100
            wField.stringValue = "\(Int(h.rounded()))"
            rField.stringValue = "\(Int((h / 2.0).rounded()))"
        }
    }

    private func applyLive() {
        guard let target = targetWindow else { return }

        let screen = NSScreen.screens.first { $0.frame.contains(target.current) } ?? NSScreen.main ?? NSScreen.screens[0]
        let scale: CGFloat = Settings.shared.devicePixels ? screen.backingScaleFactor : 1
        let scrFrame = screen.frame

        let posX = CGFloat(Double(xField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0)
        let posY = CGFloat(Double(yField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0)
        let width = max(5, CGFloat(Double(wField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 10))
        let height = max(5, CGFloat(Double(hField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 10))

        let globalMinX = scrFrame.minX + posX / scale
        let globalMaxY = scrFrame.maxY - posY / scale
        let globalWidth = width / scale
        let globalHeight = height / scale

        let newAnchor = NSPoint(x: globalMinX.rounded(), y: globalMaxY.rounded())
        let newCurrent = NSPoint(x: (globalMinX + globalWidth).rounded(), y: (globalMaxY - globalHeight).rounded())

        target.move(toAnchor: newAnchor, current: newCurrent)
    }
}

extension ShapeEditDialogController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard !isSyncingFields, let field = obj.object as? NSTextField else { return }
        syncCircleFields(modified: field)
        applyLive()
    }
}

/// A text label that enables click-drag scrubbing of an associated numeric field.
private final class ScrubbableLabel: NSTextField {
    var onScrubDelta: ((CGFloat) -> Void)?
    private var startMouseX: CGFloat = 0

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        startMouseX = NSEvent.mouseLocation.x
        NSCursor.resizeLeftRight.push()
        while true {
            guard let nextEvent = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            if nextEvent.type == .leftMouseUp { break }
            let currentX = NSEvent.mouseLocation.x
            let stepMultiplier: CGFloat = nextEvent.modifierFlags.contains(.shift) ? 10.0 : 1.0
            let delta = (currentX - startMouseX) * stepMultiplier
            startMouseX = currentX
            onScrubDelta?(delta)
        }
        NSCursor.pop()
    }
}

/// An editable text field that supports direct typing or horizontal drag scrubbing.
private final class ScrubbableField: NSTextField {
    var onScrubDelta: ((CGFloat) -> Void)?

    override func resetCursorRects() {
        super.resetCursorRects()
        if currentEditor() == nil {
            addCursorRect(bounds, cursor: .resizeLeftRight)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let startLocation = NSEvent.mouseLocation
        var hasDragged = false
        var lastMouseX = startLocation.x

        while true {
            guard let nextEvent = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            if nextEvent.type == .leftMouseUp {
                if !hasDragged {
                    super.mouseDown(with: event)
                } else {
                    NSCursor.pop()
                }
                break
            }
            let currentX = NSEvent.mouseLocation.x
            if !hasDragged && abs(currentX - startLocation.x) > 2 {
                hasDragged = true
                NSCursor.resizeLeftRight.push()
                window?.makeFirstResponder(nil)
            }
            if hasDragged {
                let stepMultiplier: CGFloat = nextEvent.modifierFlags.contains(.shift) ? 10.0 : 1.0
                let delta = (currentX - lastMouseX) * stepMultiplier
                lastMouseX = currentX
                onScrubDelta?(delta)
            }
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
