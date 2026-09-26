import AppKit

extension NSCursor {
    /// A double-headed horizontal arrow cursor (◀──▶) indicating a draggable numeric scrub control.
    static let horizontalScrub: NSCursor = {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size, flipped: false) { _ in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 3.5, y: 12))
            path.line(to: NSPoint(x: 8.5, y: 7.5))
            path.line(to: NSPoint(x: 8.5, y: 10.5))
            path.line(to: NSPoint(x: 15.5, y: 10.5))
            path.line(to: NSPoint(x: 15.5, y: 7.5))
            path.line(to: NSPoint(x: 20.5, y: 12))
            path.line(to: NSPoint(x: 15.5, y: 16.5))
            path.line(to: NSPoint(x: 15.5, y: 13.5))
            path.line(to: NSPoint(x: 8.5, y: 13.5))
            path.line(to: NSPoint(x: 8.5, y: 16.5))
            path.close()
            path.lineJoinStyle = .round

            // Dark outline for contrast against light and dark backgrounds
            NSColor(calibratedWhite: 0.08, alpha: 0.95).setStroke()
            path.lineWidth = 2.0
            path.stroke()

            // Crisp white fill
            NSColor(calibratedWhite: 0.98, alpha: 1.0).setFill()
            path.fill()

            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 12, y: 12))
    }()

    /// A 4-way move arrow cursor (◀▲▼▶) indicating a draggable handle or move control.
    static let moveHandle: NSCursor = {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size, flipped: false) { _ in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 12, y: 20.5))
            path.line(to: NSPoint(x: 16.5, y: 16.0))
            path.line(to: NSPoint(x: 13.5, y: 16.0))
            path.line(to: NSPoint(x: 13.5, y: 13.5))
            path.line(to: NSPoint(x: 16.0, y: 13.5))
            path.line(to: NSPoint(x: 16.0, y: 16.5))
            path.line(to: NSPoint(x: 20.5, y: 12))
            path.line(to: NSPoint(x: 16.0, y: 7.5))
            path.line(to: NSPoint(x: 16.0, y: 10.5))
            path.line(to: NSPoint(x: 13.5, y: 10.5))
            path.line(to: NSPoint(x: 13.5, y: 8.0))
            path.line(to: NSPoint(x: 16.5, y: 8.0))
            path.line(to: NSPoint(x: 12, y: 3.5))
            path.line(to: NSPoint(x: 7.5, y: 8.0))
            path.line(to: NSPoint(x: 10.5, y: 8.0))
            path.line(to: NSPoint(x: 10.5, y: 10.5))
            path.line(to: NSPoint(x: 8.0, y: 10.5))
            path.line(to: NSPoint(x: 8.0, y: 7.5))
            path.line(to: NSPoint(x: 3.5, y: 12))
            path.line(to: NSPoint(x: 8.0, y: 16.5))
            path.line(to: NSPoint(x: 8.0, y: 13.5))
            path.line(to: NSPoint(x: 10.5, y: 13.5))
            path.line(to: NSPoint(x: 10.5, y: 16.0))
            path.line(to: NSPoint(x: 7.5, y: 16.0))
            path.close()
            path.lineJoinStyle = .round

            // Dark outline for contrast against light and dark backgrounds
            NSColor(calibratedWhite: 0.08, alpha: 0.95).setStroke()
            path.lineWidth = 2.0
            path.stroke()

            // Crisp white fill
            NSColor(calibratedWhite: 0.98, alpha: 1.0).setFill()
            path.fill()

            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 12, y: 12))
    }()
}

