import AppKit

/// Supported geometric shapes for measuring and overlays.
enum ShapeType: String, CaseIterable, Codable {
    case rectangle
    case circle
    case line

    var title: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
        case .line: return "Line"
        }
    }

    /// Determines if a point in local view coordinates lies on or very near the shape's outline.
    func isPointOnOutline(_ point: NSPoint, in box: NSRect, tolerance: CGFloat = 6.0) -> Bool {
        guard box.width > 2 && box.height > 2 else { return false }

        switch self {
        case .rectangle:
            let outer = box.insetBy(dx: -tolerance, dy: -tolerance)
            let inner = box.insetBy(dx: tolerance, dy: tolerance)
            return outer.contains(point) && !inner.contains(point)

        case .circle:
            let rx = box.width / 2.0
            let ry = box.height / 2.0
            guard rx > 0 && ry > 0 else { return false }

            let dx = point.x - box.midX
            let dy = point.y - box.midY
            // Normalized distance from center
            let normalizedDist = sqrt((dx * dx) / (rx * rx) + (dy * dy) / (ry * ry))
            let avgR = (rx + ry) / 2.0
            let pixelDist = abs(normalizedDist - 1.0) * avgR
            return pixelDist <= tolerance

        case .line:
            let p1 = NSPoint(x: box.minX, y: box.minY)
            let p2 = NSPoint(x: box.maxX, y: box.maxY)
            return ShapeType.distanceToSegment(p: point, a: p1, b: p2) <= tolerance
        }
    }

    /// Calculates shortest perpendicular distance from point p to line segment (a, b).
    static func distanceToSegment(p: NSPoint, a: NSPoint, b: NSPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        if lenSq == 0 { return hypot(p.x - a.x, p.y - a.y) }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq
        t = max(0, min(1, t))
        let projX = a.x + t * dx
        let projY = a.y + t * dy
        return hypot(p.x - projX, p.y - projY)
    }

    /// Computes the exact perimeter/circumference of an ellipse (or circle) using Ramanujan's formula.
    static func ellipseCircumference(width: CGFloat, height: CGFloat) -> CGFloat {
        let a = width / 2.0
        let b = height / 2.0
        guard a > 0 || b > 0 else { return 0 }
        let h = pow(a - b, 2) / max(0.0001, pow(a + b, 2))
        return CGFloat.pi * (a + b) * (1.0 + (3.0 * h) / (10.0 + sqrt(4.0 - 3.0 * h)))
    }
}
