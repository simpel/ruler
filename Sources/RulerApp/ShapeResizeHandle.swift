import AppKit

/// Identifies which control dot on a shape is being interacted with.
enum ResizeDotKind: Equatable {
    case anchor
    case current
}

/// A draggable control dot located on a shape for resizing.
struct ResizeDot {
    let kind: ResizeDotKind
    let point: NSPoint      // Local view coordinates
    let hitRect: NSRect     // Expanded hit region for easy pointer capture
}

/// Helper for computing and rendering control dots on shapes.
enum ShapeResizeHandle {
    static let normalRadius: CGFloat = 2.5
    static let hoveredRadius: CGFloat = 5.0
    static let hitRadius: CGFloat = 9.0

    /// Calculates the control dots for the given shape.
    static func dots(shapeType: ShapeType, anchor: NSPoint, current: NSPoint, box: NSRect) -> [ResizeDot] {
        switch shapeType {
        case .rectangle:
            return [
                makeDot(kind: .anchor, point: anchor),
                makeDot(kind: .current, point: current)
            ]
        case .circle:
            let center = NSPoint(x: box.midX, y: box.midY)
            let rx = box.width / 2.0
            let ry = box.height / 2.0
            guard rx > 0 && ry > 0 else {
                return [
                    makeDot(kind: .anchor, point: anchor),
                    makeDot(kind: .current, point: current)
                ]
            }

            let angleA = atan2(anchor.y - center.y, anchor.x - center.x)
            let dotA = NSPoint(x: center.x + rx * cos(angleA), y: center.y + ry * sin(angleA))

            let angleB = atan2(current.y - center.y, current.x - center.x)
            let dotB = NSPoint(x: center.x + rx * cos(angleB), y: center.y + ry * sin(angleB))

            return [
                makeDot(kind: .anchor, point: dotA),
                makeDot(kind: .current, point: dotB)
            ]
        }
    }

    private static func makeDot(kind: ResizeDotKind, point: NSPoint) -> ResizeDot {
        let hitRect = NSRect(x: point.x - hitRadius,
                             y: point.y - hitRadius,
                             width: hitRadius * 2,
                             height: hitRadius * 2)
        return ResizeDot(kind: kind, point: point, hitRect: hitRect)
    }

    /// Renders a resize dot with hover growth and crisp highlight border.
    static func drawDot(at point: NSPoint, isHovered: Bool) {
        let r = isHovered ? hoveredRadius : normalRadius
        let rect = NSRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)

        Palette.live.setFill()
        NSBezierPath(ovalIn: rect).fill()

        if isHovered {
            NSColor.white.setStroke()
            let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            ring.lineWidth = 1.0
            ring.stroke()
        }
    }
}
