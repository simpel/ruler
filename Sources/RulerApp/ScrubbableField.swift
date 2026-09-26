import AppKit

/// A text label that enables click-drag scrubbing of an associated numeric field.
final class ScrubbableLabel: NSTextField {
    var onScrubDelta: ((CGFloat) -> Void)?
    private var startMouseX: CGFloat = 0
    private var trackingArea: NSTrackingArea?

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .horizontalScrub)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.cursorUpdate, .activeAlways, .inVisibleRect],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.horizontalScrub.set()
    }

    override func mouseDown(with event: NSEvent) {
        startMouseX = NSEvent.mouseLocation.x
        NSCursor.horizontalScrub.push()
        while true {
            guard let nextEvent = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            if nextEvent.type == .leftMouseUp { break }
            let currentX = NSEvent.mouseLocation.x
            let stepMultiplier: CGFloat = nextEvent.modifierFlags.contains(.shift) ? 10.0 : 1.0
            let delta = (currentX - startMouseX) * stepMultiplier
            startMouseX = currentX
            onScrubDelta?(delta)
        }
        NSCursor.pop()
    }
}

/// An editable text field that supports direct typing or horizontal drag scrubbing.
final class ScrubbableField: NSTextField {
    var onScrubDelta: ((CGFloat) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func resetCursorRects() {
        if currentEditor() == nil {
            discardCursorRects()
            addCursorRect(bounds, cursor: .horizontalScrub)
        } else {
            super.resetCursorRects()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.cursorUpdate, .activeAlways, .inVisibleRect],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        if currentEditor() == nil {
            NSCursor.horizontalScrub.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let startLocation = NSEvent.mouseLocation
        var hasDragged = false
        var lastMouseX = startLocation.x

        while true {
            guard let nextEvent = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            if nextEvent.type == .leftMouseUp {
                if !hasDragged {
                    super.mouseDown(with: event)
                } else {
                    NSCursor.pop()
                }
                break
            }
            let currentX = NSEvent.mouseLocation.x
            if !hasDragged && abs(currentX - startLocation.x) > 2 {
                hasDragged = true
                NSCursor.horizontalScrub.push()
                window?.makeFirstResponder(nil)
            }
            if hasDragged {
                let stepMultiplier: CGFloat = nextEvent.modifierFlags.contains(.shift) ? 10.0 : 1.0
                let delta = (currentX - lastMouseX) * stepMultiplier
                lastMouseX = currentX
                onScrubDelta?(delta)
            }
        }
    }
}
