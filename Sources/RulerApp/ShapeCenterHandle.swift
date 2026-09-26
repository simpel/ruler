import AppKit

/// Helper for computing and rendering the center cross mark on geometric shapes.
enum ShapeCenterHandle {
    static let crossArm: CGFloat = 4.0
    static let hitRadius: CGFloat = 10.0

    /// Returns the interactive hit rect around the center.
    static func hitRect(for box: NSRect) -> NSRect {
        let center = NSPoint(x: box.midX, y: box.midY)
        return NSRect(
            x: (center.x - hitRadius).rounded(),
            y: (center.y - hitRadius).rounded(),
            width: hitRadius * 2,
            height: hitRadius * 2
        )
    }

    /// Renders the small cross mark at the center of the shape.
    /// Intentionally minimal: no background or hover styling; drag affordance is indicated by cursor only.
    static func draw(at center: NSPoint) {
        let cross = NSBezierPath()
        cross.lineWidth = 1.0
        cross.move(to: NSPoint(x: center.x - crossArm, y: center.y))
        cross.line(to: NSPoint(x: center.x + crossArm, y: center.y))
        cross.move(to: NSPoint(x: center.x, y: center.y - crossArm))
        cross.line(to: NSPoint(x: center.x, y: center.y + crossArm))
        Palette.live.withAlphaComponent(0.65).setStroke()
        cross.stroke()
    }
}
