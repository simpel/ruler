import AppKit

/// Utility for computing shape dimension and position updates while scrubbing readout badges.
enum MetricScrubber {

    /// Applies a delta scrub change to anchor and current coordinates for a specific metric.
    static func applyDelta(metric: BadgeMetric,
                           delta: CGFloat,
                           startAnchor: NSPoint,
                           startCurrent: NSPoint) -> (anchor: NSPoint, current: NSPoint) {
        let anchor = startAnchor
        let current = startCurrent
        let minX = min(anchor.x, current.x)
        let maxX = max(anchor.x, current.x)
        let minY = min(anchor.y, current.y)
        let maxY = max(anchor.y, current.y)
        let origWidth = maxX - minX
        let origHeight = maxY - minY

        var newAnchor = anchor
        var newCurrent = current

        switch metric {
        case .width:
            let newW = max(5, origWidth + delta)
            if current.x >= anchor.x {
                newAnchor.x = minX
                newCurrent.x = minX + newW
            } else {
                newAnchor.x = minX + newW
                newCurrent.x = minX
            }
        case .height:
            let newH = max(5, origHeight + delta)
            if current.y >= anchor.y {
                newAnchor.y = minY
                newCurrent.y = minY + newH
            } else {
                newAnchor.y = minY + newH
                newCurrent.y = minY
            }
        case .radius:
            let origRadius = max(1, (origWidth + origHeight) / 4.0)
            let newRadius = max(3, origRadius + delta)
            let s = newRadius / origRadius
            let newW = max(5, origWidth * s)
            let newH = max(5, origHeight * s)
            let midX = (anchor.x + current.x) / 2.0
            let midY = (anchor.y + current.y) / 2.0
            let halfW = newW / 2.0
            let halfH = newH / 2.0

            if current.x >= anchor.x {
                newAnchor.x = (midX - halfW).rounded()
                newCurrent.x = (midX + halfW).rounded()
            } else {
                newAnchor.x = (midX + halfW).rounded()
                newCurrent.x = (midX - halfW).rounded()
            }

            if current.y >= anchor.y {
                newAnchor.y = (midY - halfH).rounded()
                newCurrent.y = (midY + halfH).rounded()
            } else {
                newAnchor.y = (midY + halfH).rounded()
                newCurrent.y = (midY - halfH).rounded()
            }

        case .circumference:
            let origCirc = max(1, MeasureView.ellipseCircumference(width: origWidth, height: origHeight))
            let newCirc = max(18, origCirc + delta)
            let s = newCirc / origCirc
            let newW = max(5, origWidth * s)
            let newH = max(5, origHeight * s)
            let midX = (anchor.x + current.x) / 2.0
            let midY = (anchor.y + current.y) / 2.0
            let halfW = newW / 2.0
            let halfH = newH / 2.0

            if current.x >= anchor.x {
                newAnchor.x = (midX - halfW).rounded()
                newCurrent.x = (midX + halfW).rounded()
            } else {
                newAnchor.x = (midX + halfW).rounded()
                newCurrent.x = (midX - halfW).rounded()
            }

            if current.y >= anchor.y {
                newAnchor.y = (midY - halfH).rounded()
                newCurrent.y = (midY + halfH).rounded()
            } else {
                newAnchor.y = (midY + halfH).rounded()
                newCurrent.y = (midY - halfH).rounded()
            }
        case .x:
            newAnchor.x = anchor.x + delta
            newCurrent.x = current.x + delta
        case .y:
            // Dragging right increases displayed posY (distance from top), moving shape down
            newAnchor.y = anchor.y - delta
            newCurrent.y = current.y - delta
        }

        return (newAnchor, newCurrent)
    }
}
