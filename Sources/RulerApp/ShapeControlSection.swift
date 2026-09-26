import AppKit

/// Control panel section for choosing live shape drawing modes with command hints.
final class ShapeControlSection: NSView {

    private let universalFontSize: CGFloat = 12
    private let textSection = Palette.guideLine
    private let textPrimary = NSColor(calibratedWhite: 0.98, alpha: 1.0)

    // Draw mode selector (toggles between Rectangle and Circle)
    private let switchShape = NSSwitch()

    private var isSyncing = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        bindActions()
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: universalFontSize, weight: .medium)
        label.textColor = textSection
        return label
    }

    private func setupUI() {
        switchShape.controlSize = .small
        switchShape.toolTip = "Toggle between Rectangle (off) and Circle (on) shape drawing"

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

        let label = NSTextField(labelWithString: "Circle")
        label.font = NSFont.systemFont(ofSize: universalFontSize, weight: .regular)
        label.textColor = textPrimary

        let row = NSStackView(views: [label, switchShape])
        row.orientation = .horizontal
        row.distribution = .equalSpacing
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 284).isActive = true

        stack.addArrangedSubview(row)
    }

    private func bindActions() {
        switchShape.target = self
        switchShape.action = #selector(onToggleShape)
    }

    func syncWithSettings() {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        switchShape.state = Settings.shared.drawShapeType == .circle ? .on : .off
    }

    @objc private func onToggleShape() {
        Settings.shared.drawShapeType = switchShape.state == .on ? .circle : .rectangle
        RulerController.shared.activateContext()
    }
}
