import AppKit

/// Supported geometric shapes for measuring and overlays.
enum ShapeType: String, CaseIterable, Codable {
    case rectangle
    case circle

    var title: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
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
        }
    }
}
