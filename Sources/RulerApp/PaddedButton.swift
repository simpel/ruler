import AppKit

/// A custom dark button with generous vertical inline padding and active click feedback.
final class PaddedButton: NSButton {

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
