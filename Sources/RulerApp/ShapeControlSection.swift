import AppKit

/// Control panel section for choosing live shape drawing modes with command hints.
final class ShapeControlSection: NSView {

    private let universalFontSize: CGFloat = 12
    private let textSection = Palette.guideLine

    // Draw mode selector (what the measure gesture draws)
    private let drawModeSegment = NSSegmentedControl(labels: ["Rectangle", "Circle"],
                                                     trackingMode: .selectOne, target: nil, action: nil)

    private let btnToggleDraw = PaddedButton(title: "Start Drawing Shape", fontSize: 12)
    private let hintsLabel = NSTextField()
    private var isSyncing = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        bindActions()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contextChanged),
                                               name: .rulerContextChanged,
                                               object: nil)
        updateDrawButtonState()
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: universalFontSize, weight: .medium)
        label.textColor = textSection
        return label
    }

    private func setupUI() {
        drawModeSegment.controlSize = .regular
        drawModeSegment.font = NSFont.systemFont(ofSize: universalFontSize, weight: .regular)

        btnToggleDraw.heightAnchor.constraint(equalToConstant: 32).isActive = true

        hintsLabel.isEditable = false
        hintsLabel.isSelectable = false
        hintsLabel.isBordered = false
        hintsLabel.drawsBackground = false
        hintsLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        hintsLabel.textColor = NSColor(calibratedWhite: 0.65, alpha: 1.0)
        hintsLabel.stringValue = "Click ruler or settings to draw · Click screen to exit"

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        stack.addArrangedSubview(makeSectionLabel("SHAPES"))
        drawModeSegment.translatesAutoresizingMaskIntoConstraints = false
        drawModeSegment.widthAnchor.constraint(equalToConstant: 284).isActive = true
        stack.addArrangedSubview(drawModeSegment)

        btnToggleDraw.translatesAutoresizingMaskIntoConstraints = false
        btnToggleDraw.widthAnchor.constraint(equalToConstant: 284).isActive = true
        stack.addArrangedSubview(btnToggleDraw)

        hintsLabel.translatesAutoresizingMaskIntoConstraints = false
        hintsLabel.widthAnchor.constraint(equalToConstant: 284).isActive = true
        stack.addArrangedSubview(hintsLabel)
    }

    private func bindActions() {
        drawModeSegment.target = self
        drawModeSegment.action = #selector(onDrawModeChanged)

        btnToggleDraw.target = self
        btnToggleDraw.action = #selector(onToggleDraw)
    }

    func syncWithSettings() {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        drawModeSegment.selectedSegment = Settings.shared.drawShapeType == .circle ? 1 : 0
        updateDrawButtonState()
    }

    @objc private func contextChanged() {
        updateDrawButtonState()
    }

    private func updateDrawButtonState() {
        let active = RulerController.shared.isContextActive
        btnToggleDraw.title = active ? "Drawing Active (Click Screen to Exit)" : "Start Drawing Shape"
    }

    @objc private func onDrawModeChanged() {
        let selected: ShapeType = drawModeSegment.selectedSegment == 1 ? .circle : .rectangle
        Settings.shared.drawShapeType = selected
        RulerController.shared.activateContext()
    }

    @objc private func onToggleDraw() {
        if RulerController.shared.isContextActive {
            RulerController.shared.deactivateContext()
        } else {
            RulerController.shared.activateContext()
        }
    }
}
