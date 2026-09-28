import AppKit

/// A custom dark button with generous vertical inline padding and active click feedback.
final class PaddedButton: NSButton {

    private let normalBg = NSColor(calibratedWhite: 0.22, alpha: 1.0)
    private let highlightBg = NSColor(calibratedWhite: 0.35, alpha: 1.0)
    private let normalBorder = NSColor(calibratedWhite: 0.38, alpha: 1.0)
    private let destructiveBg = NSColor(calibratedRed: 0.5, green: 0.15, blue: 0.15, alpha: 1.0)
    private let destructiveHighlightBg = NSColor(calibratedRed: 0.65, green: 0.2, blue: 0.2, alpha: 1.0)
    private let destructiveBorder = NSColor(calibratedRed: 0.8, green: 0.25, blue: 0.25, alpha: 1.0)
    private let isDestructive: Bool

    init(title: String, isDestructive: Bool = false, fontSize: CGFloat = 12) {
        self.isDestructive = isDestructive
        super.init(frame: .zero)
        self.title = title
        isBordered = false

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
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setAllowsFontSmoothing(true)
        context.setShouldSmoothFonts(true)

        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        let bg: NSColor
        if isDestructive {
            bg = isHighlighted ? destructiveHighlightBg : destructiveBg
        } else {
            bg = isHighlighted ? highlightBg : normalBg
        }
        bg.setFill()
        shape.fill()

        let border = isDestructive ? destructiveBorder : normalBorder
        border.setStroke()
        shape.lineWidth = 1
        shape.stroke()

        let titleSize = attributedTitle.size()
        let titleRect = NSRect(
            x: ((bounds.width - titleSize.width) / 2.0).rounded(),
            y: ((bounds.height - titleSize.height) / 2.0).rounded(),
            width: titleSize.width,
            height: titleSize.height
        )
        attributedTitle.draw(in: titleRect)
    }
}
