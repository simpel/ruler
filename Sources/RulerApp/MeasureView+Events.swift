import AppKit

// MARK: - Mouse & Cursor Interaction for MeasureView

extension MeasureView {

    override func resetCursorRects() {
        super.resetCursorRects()
        guard showsClose else { return }

        for dot in activeDots {
            addCursorRect(dot.hitRect, cursor: .moveHandle)
        }
        if let closeRect {
            addCursorRect(closeRect, cursor: .pointingHand)
        }
        if let editRect {
            addCursorRect(editRect, cursor: .pointingHand)
        }
        if let moveRect {
            addCursorRect(moveRect, cursor: .openHand)
        }
        if let centerMoveRect {
            addCursorRect(centerMoveRect, cursor: .openHand)
        }
        for hit in metricHits {
            addCursorRect(hit.rect, cursor: .horizontalScrub)
        }
        if let badgeRect {
            addCursorRect(badgeRect, cursor: .arrow)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .cursorUpdate],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if resizeDot(at: loc) != nil {
            NSCursor.moveHandle.set()
            return
        }
        if let centerMoveRect, centerMoveRect.contains(loc) {
            NSCursor.openHand.set()
            return
        }
        if let moveRect, moveRect.insetBy(dx: -4, dy: -4).contains(loc) {
            NSCursor.openHand.set()
            return
        }
        super.cursorUpdate(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let hit = resizeDot(at: loc)?.kind
        if hit != hoveredDot {
            hoveredDot = hit
            window?.invalidateCursorRects(for: self)
        }
        let hitCenter = centerMoveRect?.contains(loc) ?? false
        if hitCenter != centerMoveHot {
            centerMoveHot = hitCenter
            window?.invalidateCursorRects(for: self)
        }
    }

    override func mouseExited(with event: NSEvent) {
        if hoveredDot != nil {
            hoveredDot = nil
            window?.invalidateCursorRects(for: self)
        }
        if centerMoveHot {
            centerMoveHot = false
            window?.invalidateCursorRects(for: self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)

        // 1. Control dots (resize shape)
        if let hitDot = resizeDot(at: loc) {
            startDotResize(dot: hitDot)
            return
        }

        // 2. Close button
        if let closeRect, closeRect.insetBy(dx: -4, dy: -4).contains(loc) {
            onClose?()
            return
        }

        // 3. Edit button
        if let editRect, editRect.insetBy(dx: -4, dy: -4).contains(loc) {
            onEdit?()
            return
        }

        // 4. Number hit testing: double click opens settings, single click/drag scrubs
        if let hit = metricHits.first(where: { $0.rect.contains(loc) }) {
            if event.clickCount == 2 {
                onEdit?()
                return
            }
            startScrub(metric: hit.metric)
            return
        }

        // 5. Move button (badge header)
        if let moveRect, moveRect.insetBy(dx: -4, dy: -4).contains(loc) {
            startDrag()
            return
        }

        // 6. Center move cross (shape center)
        if let centerMoveRect, centerMoveRect.contains(loc) {
            startDrag()
            return
        }

        // 7. Badge background or outline
        if let badgeRect, badgeRect.contains(loc) {
            startDrag()
            return
        }
        if isOverOutline(loc) {
            startDrag()
            return
        }
    }

    func startDotResize(dot: ResizeDot) {
        guard let owner else { return }
        isResizingDot = true
        activeResizeDot = dot.kind
        dotDragStartMouse = NSEvent.mouseLocation
        dotDragStartAnchor = owner.anchor
        dotDragStartCurrent = owner.current
        NSCursor.moveHandle.push()
        needsDisplay = true
    }

    func startDrag() {
        guard let owner else { return }
        isDragging = true
        dragStartMouse = NSEvent.mouseLocation
        dragStartAnchor = owner.anchor
        dragStartCurrent = owner.current
        NSCursor.closedHand.push()
    }

    func startScrub(metric: BadgeMetric) {
        guard let owner else { return }
        isScrubbing = true
        activeMetric = metric
        scrubStartMouse = NSEvent.mouseLocation
        scrubStartAnchor = owner.anchor
        scrubStartCurrent = owner.current
        NSCursor.horizontalScrub.push()
        needsDisplay = true
    }

    override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
        if isResizingDot {
            mouseDragged(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if isResizingDot, let owner, let dotKind = activeResizeDot {
            let mouse = NSEvent.mouseLocation
            let dx = mouse.x - dotDragStartMouse.x
            let dy = mouse.y - dotDragStartMouse.y
            let constrain = event.modifierFlags.contains(.shift)
            let fromCenter = event.modifierFlags.contains(.command)

            var newAnchor = dotDragStartAnchor
            var newCurrent = dotDragStartCurrent

            if fromCenter {
                let center = NSPoint(x: (dotDragStartAnchor.x + dotDragStartCurrent.x) / 2.0,
                                     y: (dotDragStartAnchor.y + dotDragStartCurrent.y) / 2.0)
                switch dotKind {
                case .current:
                    let rawTarget = NSPoint(x: dotDragStartCurrent.x + dx, y: dotDragStartCurrent.y + dy)
                    let target: NSPoint
                    if owner.shapeType == .line {
                        target = constrain ? RulerController.constrainLine(anchor: center, current: rawTarget) : rawTarget
                    } else {
                        target = constrain ? RulerController.constrainSquareOrCircle(anchor: center, current: rawTarget) : rawTarget
                    }
                    newCurrent = target
                    newAnchor = NSPoint(x: (2 * center.x - target.x).rounded(),
                                        y: (2 * center.y - target.y).rounded())

                case .anchor:
                    let rawTarget = NSPoint(x: dotDragStartAnchor.x + dx, y: dotDragStartAnchor.y + dy)
                    let target: NSPoint
                    if owner.shapeType == .line {
                        target = constrain ? RulerController.constrainLine(anchor: center, current: rawTarget) : rawTarget
                    } else {
                        target = constrain ? RulerController.constrainSquareOrCircle(anchor: center, current: rawTarget) : rawTarget
                    }
                    newAnchor = target
                    newCurrent = NSPoint(x: (2 * center.x - target.x).rounded(),
                                         y: (2 * center.y - target.y).rounded())
                }
            } else {
                switch dotKind {
                case .current:
                    let rawTarget = NSPoint(x: (dotDragStartCurrent.x + dx).rounded(),
                                            y: (dotDragStartCurrent.y + dy).rounded())
                    if owner.shapeType == .line {
                        newCurrent = constrain ? RulerController.constrainLine(anchor: dotDragStartAnchor, current: rawTarget) : rawTarget
                    } else {
                        newCurrent = constrain ? RulerController.constrainSquareOrCircle(anchor: dotDragStartAnchor, current: rawTarget) : rawTarget
                    }

                case .anchor:
                    let rawTarget = NSPoint(x: (dotDragStartAnchor.x + dx).rounded(),
                                            y: (dotDragStartAnchor.y + dy).rounded())
                    if owner.shapeType == .line {
                        newAnchor = constrain ? RulerController.constrainLine(anchor: dotDragStartCurrent, current: rawTarget) : rawTarget
                    } else {
                        newAnchor = constrain ? RulerController.constrainSquareOrCircle(anchor: dotDragStartCurrent, current: rawTarget) : rawTarget
                    }
                }
            }

            let minSize: CGFloat = 5
            if abs(newCurrent.x - newAnchor.x) >= minSize || abs(newCurrent.y - newAnchor.y) >= minSize {
                owner.move(toAnchor: newAnchor, current: newCurrent)
                ShapeEditDialogController.shared.syncIfActive(for: owner)
            }
            return
        }

        if isScrubbing, let owner, let metric = activeMetric {
            let mouse = NSEvent.mouseLocation
            let stepMultiplier: CGFloat = event.modifierFlags.contains(.shift) ? 10.0 : 1.0
            let rawDelta = (mouse.x - scrubStartMouse.x) * stepMultiplier
            let delta = (rawDelta / scale).rounded()

            let updated = MetricScrubber.applyDelta(metric: metric,
                                                   delta: delta,
                                                   startAnchor: scrubStartAnchor,
                                                   startCurrent: scrubStartCurrent)

            owner.move(toAnchor: updated.anchor, current: updated.current)
            ShapeEditDialogController.shared.syncIfActive(for: owner)
            return
        }

        if isDragging, let owner {
            let mouse = NSEvent.mouseLocation
            let dx = mouse.x - dragStartMouse.x
            let dy = mouse.y - dragStartMouse.y
            owner.move(toAnchor: NSPoint(x: (dragStartAnchor.x + dx).rounded(), y: (dragStartAnchor.y + dy).rounded()),
                       current: NSPoint(x: (dragStartCurrent.x + dx).rounded(), y: (dragStartCurrent.y + dy).rounded()))
            ShapeEditDialogController.shared.syncIfActive(for: owner)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isResizingDot {
            isResizingDot = false
            activeResizeDot = nil
            NSCursor.pop()
            needsDisplay = true
        }
        if isScrubbing {
            isScrubbing = false
            activeMetric = nil
            NSCursor.pop()
            needsDisplay = true
        }
        if isDragging {
            isDragging = false
            NSCursor.pop()
        }
    }
}
