import AppKit

/// Identifies an interactive metric value displayed on the readout badge.
enum BadgeMetric: Equatable {
    case width
    case height
    case radius
    case circumference
    case length
    case x
    case y
    case screenX
    case screenY
}

/// Interactive hit target for a specific numeric readout on the badge.
struct MetricHitTarget {
    let metric: BadgeMetric
    let rect: NSRect
}

/// Layout and hit targets for the floating HUD readout badge.
struct ReadoutBadgeLayout {
    let badgeRect: NSRect
    let closeRect: NSRect?
    let editRect: NSRect?
    let moveRect: NSRect?
    let metricHits: [MetricHitTarget]
}

/// Renders a modern, highly legible HUD badge for measurement overlays and live tracking.
enum ReadoutBadge {

    private static let fontVal = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
    private static let fontLbl = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
    private static let fontTitle = NSFont.systemFont(ofSize: 11, weight: .semibold)

    @discardableResult
    static func draw(shapeType: ShapeType?,
                     showsActions: Bool,
                     posX: CGFloat,
                     posY: CGFloat,
                     screenX: CGFloat? = nil,
                     screenY: CGFloat? = nil,
                     width: CGFloat? = nil,
                     height: CGFloat? = nil,
                     radius: CGFloat? = nil,
                     circumference: CGFloat? = nil,
                     length: CGFloat? = nil,
                     in bounds: NSRect,
                     near point: NSPoint? = nil,
                     forShapeBox box: NSRect? = nil,
                     screenVisibleRect: NSRect? = nil,
                     isHovered: Bool = false,
                     moveHot: Bool = false,
                     editHot: Bool = false,
                     closeHot: Bool = false,
                     activeMetric: BadgeMetric? = nil) -> ReadoutBadgeLayout {

        let padX: CGFloat = 13
        let padY: CGFloat = 11
        let colGap: CGFloat = 20
        let rowGap: CGFloat = 7
        let headerHeight: CGFloat = showsActions ? 22 : 0
        let dividerGap: CGFloat = showsActions ? 9 : 0
        let iconSlotWidth: CGFloat = 22
        let itemGap: CGFloat = 6
        let rowHeight: CGFloat = 15

        let xValStr = "\(Int(posX.rounded()))"
        let yValStr = "\(Int(posY.rounded()))"
        let sxValStr = screenX.map { "\(Int($0.rounded()))" }
        let syValStr = screenY.map { "\(Int($0.rounded()))" }
        let wValStr = width.map { "\(Int($0.rounded()))" }
        let hValStr = height.map { "\(Int($0.rounded()))" }
        let rValStr = radius.map { "\(Int($0.rounded()))" }
        let cValStr = circumference.map { "\(Int($0.rounded()))" }
        let lValStr = length.map { "\(Int($0.rounded()))" }

        let xValWidth = NSAttributedString(string: xValStr, attributes: [.font: fontVal]).size().width
        let yValWidth = NSAttributedString(string: yValStr, attributes: [.font: fontVal]).size().width
        let sxValWidth = sxValStr.map { NSAttributedString(string: $0, attributes: [.font: fontVal]).size().width } ?? 0
        let syValWidth = syValStr.map { NSAttributedString(string: $0, attributes: [.font: fontVal]).size().width } ?? 0
        let wValWidth = wValStr.map { NSAttributedString(string: $0, attributes: [.font: fontVal]).size().width } ?? 0
        let hValWidth = hValStr.map { NSAttributedString(string: $0, attributes: [.font: fontVal]).size().width } ?? 0
        let rValWidth = rValStr.map { NSAttributedString(string: $0, attributes: [.font: fontVal]).size().width } ?? 0
        let cValWidth = cValStr.map { NSAttributedString(string: $0, attributes: [.font: fontVal]).size().width } ?? 0
        let lValWidth = lValStr.map { NSAttributedString(string: $0, attributes: [.font: fontVal]).size().width } ?? 0

        let col1MaxVal = max(xValWidth, max(sxValWidth, max(wValWidth, max(rValWidth, lValWidth))))
        let col2MaxVal = max(yValWidth, max(syValWidth, max(hValWidth, cValWidth)))

        let col1Width = iconSlotWidth + itemGap + col1MaxVal
        let col2Width = iconSlotWidth + itemGap + col2MaxVal

        let gridWidth = col1Width + colGap + col2Width
        let headerMinWidth: CGFloat = showsActions ? 176 : 0
        let contentWidth = max(gridWidth, headerMinWidth)

        var numRows = 1 // Coordinates row
        if sxValStr != nil { numRows += 1 }
        if wValStr != nil { numRows += 1 }
        if rValStr != nil { numRows += 1 }
        if lValStr != nil { numRows += 1 }

        let gridHeight = CGFloat(numRows) * rowHeight + CGFloat(max(0, numRows - 1)) * rowGap
        let totalWidth = contentWidth + padX * 2
        let totalHeight = padY * 2 + headerHeight + dividerGap + gridHeight

        // Compute badge position with screen edge detection
        let badgeRect: NSRect
        let screenSafeMargin: CGFloat = 8.0

        if let box {
            let margin: CGFloat = 12.0
            let neededHeight = totalHeight + margin

            // Screen boundaries in view coordinates (fall back to view bounds if nil)
            let minScreenY = (screenVisibleRect?.minY ?? bounds.minY) + screenSafeMargin
            let maxScreenY = (screenVisibleRect?.maxY ?? bounds.maxY) - screenSafeMargin

            let spaceBelow = box.minY - minScreenY
            let spaceAbove = maxScreenY - box.maxY

            var y: CGFloat
            if spaceBelow >= neededHeight {
                // Preferred: comfortably below the shape
                y = box.minY - totalHeight - margin
            } else if spaceAbove >= neededHeight {
                // Close to bottom screen edge (or Dock): place above shape
                y = box.maxY + margin
            } else if spaceAbove > spaceBelow {
                // Neither has full clearance, but above has more space
                y = max(box.maxY + 4.0, min(maxScreenY - totalHeight, box.maxY + margin))
            } else {
                // Below has more space
                y = min(box.minY - totalHeight - 4.0, max(minScreenY, box.minY - totalHeight - margin))
            }

            // Safety clamp within view bounds so badge is never clipped by window
            y = max(bounds.minY + 2.0, min(bounds.maxY - totalHeight - 2.0, y))

            // Horizontal positioning with screen edge detection
            let minScreenX = (screenVisibleRect?.minX ?? bounds.minX) + screenSafeMargin
            let maxScreenX = (screenVisibleRect?.maxX ?? bounds.maxX) - screenSafeMargin

            var x = box.midX - totalWidth / 2.0

            if x < minScreenX {
                x = minScreenX
            } else if x + totalWidth > maxScreenX {
                x = maxScreenX - totalWidth
            }

            // Safety clamp within view bounds
            x = max(bounds.minX + 2.0, min(bounds.maxX - totalWidth - 2.0, x))

            badgeRect = NSRect(x: x.rounded(), y: y.rounded(), width: totalWidth.rounded(), height: totalHeight.rounded())
        } else {
            let pt = point ?? .zero
            var x = pt.x + 14
            var y = pt.y + 14

            let minScreenX = (screenVisibleRect?.minX ?? bounds.minX) + screenSafeMargin
            let maxScreenX = (screenVisibleRect?.maxX ?? bounds.maxX) - screenSafeMargin
            let minScreenY = (screenVisibleRect?.minY ?? bounds.minY) + screenSafeMargin
            let maxScreenY = (screenVisibleRect?.maxY ?? bounds.maxY) - screenSafeMargin

            if x + totalWidth > maxScreenX {
                x = pt.x - totalWidth - 14
            }
            if y + totalHeight > maxScreenY {
                y = pt.y - totalHeight - 14
            }

            x = max(minScreenX, min(maxScreenX - totalWidth, x))
            y = max(minScreenY, min(maxScreenY - totalHeight, y))

            x = max(bounds.minX + 2, min(bounds.maxX - totalWidth - 2, x))
            y = max(bounds.minY + 2, min(bounds.maxY - totalHeight - 2, y))
            badgeRect = NSRect(x: x.rounded(), y: y.rounded(), width: totalWidth.rounded(), height: totalHeight.rounded())
        }

        // Draw shadow
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.38)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 8
        shadow.set()

        // Card background
        let baseBg = Palette.hud()
        let bgCol = isHovered ? baseBg.blended(withFraction: 0.12, of: .white) ?? baseBg : baseBg
        bgCol.setFill()
        let path = NSBezierPath(roundedRect: badgeRect, xRadius: 8, yRadius: 8)
        path.fill()
        NSShadow().set()

        // Border
        let borderCol = isHovered ? Palette.guideLine.withAlphaComponent(0.7) : NSColor.white.withAlphaComponent(0.18)
        borderCol.setStroke()
        let border = NSBezierPath(roundedRect: badgeRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        border.lineWidth = 1
        border.stroke()

        var currentY = badgeRect.maxY - padY
        var outCloseRect: NSRect?
        var outEditRect: NSRect?
        var outMoveRect: NSRect?

        // Header
        if showsActions, let shapeType {
            let headerY = currentY - 17

            // Shape Icon & Title (Vector SF Symbol)
            let shapeIcon: String
            switch shapeType {
            case .circle: shapeIcon = "circle"
            case .rectangle: shapeIcon = "rectangle"
            case .line: shapeIcon = "line.diagonal"
            }
            if let sImg = makeVectorSymbol(shapeIcon, pointSize: 11, weight: .medium, color: NSColor.white.withAlphaComponent(0.85)) {
                drawSymbol(sImg, centeredIn: NSRect(x: badgeRect.minX + padX, y: headerY + 1.5, width: 12, height: 12))
            }

            let titleAttr = NSAttributedString(string: shapeType.title, attributes: [
                .font: fontTitle,
                .foregroundColor: NSColor.white.withAlphaComponent(0.92)
            ])
            titleAttr.draw(at: NSPoint(x: badgeRect.minX + padX + 16, y: headerY))

            // Action Buttons: Move, Edit (Sliders), Close (X)
            let btnD: CGFloat = 18
            let btnGap: CGFloat = 5
            let closeX = badgeRect.maxX - padX - btnD
            let editX = closeX - btnD - btnGap
            let moveX = editX - btnD - btnGap

            // Move button (drag handle)
            let mRect = NSRect(x: moveX, y: headerY - 0.5, width: btnD, height: btnD)
            outMoveRect = mRect
            let moveBg = moveHot ? Palette.guideLine.withAlphaComponent(0.85) : NSColor.white.withAlphaComponent(0.12)
            moveBg.setFill()
            NSBezierPath(ovalIn: mRect).fill()
            let moveTint = moveHot ? NSColor.black : NSColor.white.withAlphaComponent(0.9)
            if let mIcon = makeVectorSymbol("arrow.up.and.down.and.arrow.left.and.right", pointSize: 9.5, weight: .semibold, color: moveTint) {
                drawSymbol(mIcon, centeredIn: mRect)
            }

            // Edit button (Sliders)
            let eRect = NSRect(x: editX, y: headerY - 0.5, width: btnD, height: btnD)
            outEditRect = eRect
            let editBg = editHot ? Palette.guideLine.withAlphaComponent(0.85) : NSColor.white.withAlphaComponent(0.12)
            editBg.setFill()
            NSBezierPath(ovalIn: eRect).fill()
            let editTint = editHot ? NSColor.black : NSColor.white.withAlphaComponent(0.9)
            if let eIcon = makeVectorSymbol("slider.horizontal.3", pointSize: 10, weight: .semibold, color: editTint) {
                drawSymbol(eIcon, centeredIn: eRect)
            }

            // Close button (X)
            let cRect = NSRect(x: closeX, y: headerY - 0.5, width: btnD, height: btnD)
            outCloseRect = cRect
            let closeBg = closeHot ? Palette.live : NSColor.white.withAlphaComponent(0.12)
            closeBg.setFill()
            NSBezierPath(ovalIn: cRect).fill()
            let closeTint = NSColor.white
            if let cIcon = makeVectorSymbol("xmark", pointSize: 9.5, weight: .bold, color: closeTint) {
                drawSymbol(cIcon, centeredIn: cRect)
            }

            currentY = headerY - 7

            // Divider
            NSColor.white.withAlphaComponent(0.12).setStroke()
            let div = NSBezierPath()
            div.move(to: NSPoint(x: badgeRect.minX + padX - 2, y: currentY))
            div.line(to: NSPoint(x: badgeRect.maxX - padX + 2, y: currentY))
            div.lineWidth = 1
            div.stroke()

            currentY -= dividerGap
        }

        // Draw grid rows
        let col1X = badgeRect.minX + padX
        let col2X = col1X + col1Width + colGap

        let iconColor = NSColor.white.withAlphaComponent(0.65)
        let labelColor = NSColor.white.withAlphaComponent(0.55)
        let valueColor = NSColor.white
        var metricHits: [MetricHitTarget] = []

        func drawCell(metric: BadgeMetric?, symbolName: String?, drawCustom: ((NSRect) -> Void)?, textLabel: String?, value: String, x: CGFloat, y: CGFloat) {
            let cellY = y - 13
            let slotRect = NSRect(x: x, y: cellY + 1.5, width: iconSlotWidth, height: 12)

            if let drawCustom = drawCustom {
                drawCustom(slotRect)
            } else if let symName = symbolName, let sym = makeVectorSymbol(symName, pointSize: 11, weight: .semibold, color: iconColor) {
                drawSymbol(sym, centeredIn: slotRect)
            } else if let textLabel = textLabel {
                let lblAttr = NSAttributedString(string: textLabel, attributes: [
                    .font: fontLbl,
                    .foregroundColor: labelColor
                ])
                let lblSize = lblAttr.size()
                let lblX = (slotRect.minX + (slotRect.width - lblSize.width) / 2.0).rounded()
                lblAttr.draw(at: NSPoint(x: lblX, y: cellY))
            }

            let isMetricActive = (metric != nil && metric == activeMetric)
            let valCol = isMetricActive ? Palette.guideLine : valueColor
            let valAttr = NSAttributedString(string: value, attributes: [
                .font: fontVal,
                .foregroundColor: valCol
            ])
            let valOrigin = NSPoint(x: x + iconSlotWidth + itemGap, y: cellY)
            valAttr.draw(at: valOrigin)

            if let metric {
                let valWidth = valAttr.size().width
                let hitRect = NSRect(x: valOrigin.x - 2, y: cellY - 2, width: valWidth + 4, height: rowHeight + 2)
                metricHits.append(MetricHitTarget(metric: metric, rect: hitRect))
            }
        }

        // Line Length Row
        if let l = lValStr {
            drawCell(metric: .length, symbolName: "ruler", drawCustom: nil, textLabel: nil, value: l, x: col1X, y: currentY)
            currentY -= (rowHeight + rowGap)
        }

        // Dimensions Row (Width, Height)
        if let w = wValStr, let h = hValStr {
            drawCell(metric: .width, symbolName: "arrow.left.and.right", drawCustom: nil, textLabel: nil, value: w, x: col1X, y: currentY)
            drawCell(metric: .height, symbolName: "arrow.up.and.down", drawCustom: nil, textLabel: nil, value: h, x: col2X, y: currentY)
            currentY -= (rowHeight + rowGap)
        }

        // Circle Metrics Row (Radius, Circumference)
        if let r = rValStr, let c = cValStr {
            drawCell(metric: .radius, symbolName: nil, drawCustom: { slotRect in
                drawRadiusIcon(in: slotRect, color: iconColor)
            }, textLabel: nil, value: r, x: col1X, y: currentY)

            drawCell(metric: .circumference, symbolName: nil, drawCustom: { slotRect in
                drawCircumferenceIcon(in: slotRect, color: iconColor)
            }, textLabel: nil, value: c, x: col2X, y: currentY)

            currentY -= (rowHeight + rowGap)
        }

        // Ruler Position Row (X, Y)
        drawCell(metric: .x, symbolName: nil, drawCustom: nil, textLabel: "X", value: xValStr, x: col1X, y: currentY)
        drawCell(metric: .y, symbolName: nil, drawCustom: nil, textLabel: "Y", value: yValStr, x: col2X, y: currentY)

        // Screen Position Row (Screen icon followed by X / Y)
        if let sx = sxValStr, let sy = syValStr {
            currentY -= (rowHeight + rowGap)
            drawCell(metric: .screenX, symbolName: nil, drawCustom: { slotRect in
                ReadoutBadge.drawScreenCoordIcon(axis: "X", in: slotRect, color: labelColor, font: fontLbl)
            }, textLabel: nil, value: sx, x: col1X, y: currentY)
            drawCell(metric: .screenY, symbolName: nil, drawCustom: { slotRect in
                ReadoutBadge.drawScreenCoordIcon(axis: "Y", in: slotRect, color: labelColor, font: fontLbl)
            }, textLabel: nil, value: sy, x: col2X, y: currentY)
        }

        return ReadoutBadgeLayout(badgeRect: badgeRect, closeRect: outCloseRect, editRect: outEditRect, moveRect: outMoveRect, metricHits: metricHits)
    }

    /// Draws a screen icon (display) followed by axis text ("X" or "Y") centered within slotRect.
    static func drawScreenCoordIcon(axis: String, in slotRect: NSRect, color: NSColor, font: NSFont) {
        if let sym = makeVectorSymbol("display", pointSize: 9.5, weight: .semibold, color: color) {
            let symSize = sym.size
            let textAttr = NSAttributedString(string: axis, attributes: [
                .font: font,
                .foregroundColor: color
            ])
            let textSize = textAttr.size()
            let gap: CGFloat = 2.0
            let totalW = symSize.width + gap + textSize.width
            let startX = (slotRect.minX + (slotRect.width - totalW) / 2.0).rounded()
            let symY = (slotRect.minY + (slotRect.height - symSize.height) / 2.0).rounded()
            sym.draw(in: NSRect(x: startX, y: symY, width: symSize.width, height: symSize.height))

            let textY = slotRect.minY - 1.5
            textAttr.draw(at: NSPoint(x: startX + symSize.width + gap, y: textY))
        }
    }

    /// Creates an unrasterized, resolution-independent vector SF Symbol tinted with palette colors.
    static func makeVectorSymbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    }

    /// Draws a vector symbol centered within a slot rectangle without distortion.
    static func drawSymbol(_ sym: NSImage, centeredIn slotRect: NSRect) {
        let size = sym.size
        let targetRect = NSRect(
            x: (slotRect.minX + (slotRect.width - size.width) / 2.0).rounded(),
            y: (slotRect.minY + (slotRect.height - size.height) / 2.0).rounded(),
            width: size.width,
            height: size.height
        )
        sym.draw(in: targetRect)
    }

    /// Directly renders the radius geometric vector glyph at the device's native Retina backing scale.
    private static func drawRadiusIcon(in slotRect: NSRect, color: NSColor) {
        color.setStroke()
        color.setFill()
        let d: CGFloat = 11.0
        let rBox = NSRect(
            x: (slotRect.minX + (slotRect.width - d) / 2.0).rounded(),
            y: (slotRect.minY + (slotRect.height - d) / 2.0).rounded(),
            width: d,
            height: d
        )
        let circle = NSBezierPath(ovalIn: rBox)
        circle.lineWidth = 1.0
        circle.stroke()

        let center = NSBezierPath(ovalIn: NSRect(x: rBox.midX - 1.0, y: rBox.midY - 1.0, width: 2.0, height: 2.0))
        center.fill()

        let line = NSBezierPath()
        line.lineWidth = 1.0
        line.move(to: NSPoint(x: rBox.midX, y: rBox.midY))
        line.line(to: NSPoint(x: rBox.maxX, y: rBox.midY))
        line.stroke()
    }

    /// Directly renders the dashed circumference vector glyph at native Retina resolution.
    private static func drawCircumferenceIcon(in slotRect: NSRect, color: NSColor) {
        color.setStroke()
        let d: CGFloat = 11.0
        let cBox = NSRect(
            x: (slotRect.minX + (slotRect.width - d) / 2.0).rounded(),
            y: (slotRect.minY + (slotRect.height - d) / 2.0).rounded(),
            width: d,
            height: d
        )
        let circle = NSBezierPath(ovalIn: cBox)
        circle.lineWidth = 1.0
        circle.setLineDash([2.5, 1.8], count: 2, phase: 0)
        circle.stroke()
    }
}
