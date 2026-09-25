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

    private func makeKeyBadge(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        label.textColor = NSColor(calibratedWhite: 0.95, alpha: 1.0)
        label.alignment = .center

        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor(calibratedWhite: 0.22, alpha: 0.85).cgColor
        badge.layer?.borderColor = NSColor(calibratedWhite: 0.38, alpha: 0.7).cgColor
        badge.layer?.borderWidth = 1
        badge.layer?.cornerRadius = 4

        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 76),
            badge.heightAnchor.constraint(equalToConstant: 18),
        ])
        return badge
    }

    private func makeRow(badgeText: String, description: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let badge = makeKeyBadge(badgeText)
        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        descLabel.textColor = NSColor(calibratedWhite: 0.72, alpha: 1.0)
        descLabel.lineBreakMode = .byTruncatingTail

        row.addArrangedSubview(badge)
        row.addArrangedSubview(descLabel)
        return row
    }

    private func setupUI() {
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

        stack.addArrangedSubview(makeSectionLabel("COMMANDS"))

        let commands: [(String, String)] = [
            ("Click", "Ruler or settings to focus app & draw"),
            ("Drag", "Draw shape (hold ⇧ for 1:1)"),
            ("Drag ⇄", "Scrub number values left / right"),
            ("2× number", "Open shape settings dialog"),
            ("⌥-click", "Place cross markers at position"),
            ("⌥-drag", "Pull out guide from ruler"),
            ("2× ruler", "Set zero mark on ruler"),
            ("Esc / Click", "Exit drawing mode"),
        ]

        for (key, desc) in commands {
            let row = makeRow(badgeText: key, description: desc)
            stack.addArrangedSubview(row)
        }
    }
}
