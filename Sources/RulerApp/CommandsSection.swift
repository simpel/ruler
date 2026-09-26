import AppKit

/// Control panel section displaying essential gestures and commands for using Distanser.
final class CommandsSection: NSView {

    private let universalFontSize: CGFloat = 12
    private let textSection = Palette.guideLine

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: universalFontSize, weight: .medium)
        label.textColor = textSection
        return label
    }

    private func makeSubgroupLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = NSColor(calibratedWhite: 0.55, alpha: 1.0)
        return label
    }

    private func makeRow(gesture: String, description: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        let gestureLabel = NSTextField(labelWithString: gesture)
        gestureLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        gestureLabel.textColor = NSColor(calibratedWhite: 0.94, alpha: 1.0)
        gestureLabel.alignment = .left
        gestureLabel.translatesAutoresizingMaskIntoConstraints = false
        gestureLabel.widthAnchor.constraint(equalToConstant: 82).isActive = true

        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        descLabel.textColor = NSColor(calibratedWhite: 0.70, alpha: 1.0)
        descLabel.lineBreakMode = .byTruncatingTail

        row.addArrangedSubview(gestureLabel)
        row.addArrangedSubview(descLabel)
        return row
    }

    private func setupUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let header = makeSectionLabel("COMMANDS")
        stack.addArrangedSubview(header)
        stack.setCustomSpacing(6, after: header)

        // 1. Shapes
        let shapesGroup = makeSubgroupLabel("SHAPES")
        stack.addArrangedSubview(shapesGroup)
        stack.setCustomSpacing(3, after: shapesGroup)

        let shapesCommands: [(String, String)] = [
            ("Drag", "Draw shape (hold ⇧ for 1:1)"),
        ]
        for (gesture, desc) in shapesCommands {
            stack.addArrangedSubview(makeRow(gesture: gesture, description: desc))
        }

        if let last = stack.arrangedSubviews.last {
            stack.setCustomSpacing(8, after: last)
        }

        // 2. Guides
        let guidesGroup = makeSubgroupLabel("GUIDES")
        stack.addArrangedSubview(guidesGroup)
        stack.setCustomSpacing(3, after: guidesGroup)

        let guidesCommands: [(String, String)] = [
            ("⌥ Drag", "Pull out guide from ruler"),
            ("⌥ Click", "Toggle cross marker or guide"),
        ]
        for (gesture, desc) in guidesCommands {
            stack.addArrangedSubview(makeRow(gesture: gesture, description: desc))
        }

        if let last = stack.arrangedSubviews.last {
            stack.setCustomSpacing(8, after: last)
        }

        // 3. Rulers
        let rulersGroup = makeSubgroupLabel("RULERS")
        stack.addArrangedSubview(rulersGroup)
        stack.setCustomSpacing(3, after: rulersGroup)

        let rulersCommands: [(String, String)] = [
            ("Drag", "Move ruler (drag end to resize)"),
            ("⌘ Click", "Set zero mark on ruler"),
        ]
        for (gesture, desc) in rulersCommands {
            stack.addArrangedSubview(makeRow(gesture: gesture, description: desc))
        }
    }
}
