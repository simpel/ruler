import AppKit

/// Identifies an interactive metric value displayed on the readout badge.
enum BadgeMetric: Equatable {
    case width
    case height
    case radius
    case circumference
    case x
    case y
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
                     width: CGFloat? = nil,
                     height: CGFloat? = nil,
                     radius: CGFloat? = nil,
                     circumference: CGFloat? = nil,
                     in bounds: NSRect,
                     near point: NSPoint? = nil,
                     forShapeBox box: NSRect? = nil,
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
        let iconSlotWidth: CGFloat = 14
        let itemGap: CGFloat = 6
        let rowHeight: CGFloat = 15

        let xValStr = "\(Int(posX.rounded()))"
        let yValStr = "\(Int(posY.rounded()))"
        let wValStr = width.map { "\(Int($0.rounded()))" }
        let hValStr = height.map { "\(Int($0.rounded()))" }
        let rValStr = radius.map { "\(Int($0.rounded()))" }
        let cValStr = circumference.map { "\(Int($0.rounded()))" }

        let xValWidth = NSAttributedString(string: xValStr, attributes: [.font: fontVal]).size().width
        let yValWidth = NSAttributedString(string: yValStr, attributes: [.font: fontVal]).size().width
        let wValWidth = wValStr.map { NSAttributedString(string: $0, attributes: [.font: fontVal]).size().width } ?? 0
        let hValWidth = hValStr.map { NSAttributedString(string: $0, attributes: [.font: fontVal]).size().width } ?? 0
        let rValWidth = rValStr.map { NSAttributedString(string: $0, attributes: [.font: fontVal]).size().width } ?? 0
        let cValWidth = cValStr.map { NSAttributedString(string: $0, attributes: [.font: fontVal]).size().width } ?? 0

        let col1MaxVal = max(xValWidth, max(wValWidth, rValWidth))
        let col2MaxVal = max(yValWidth, max(hValWidth, cValWidth))

        let col1Width = iconSlotWidth + itemGap + col1MaxVal
        let col2Width = iconSlotWidth + itemGap + col2MaxVal

        let gridWidth = col1Width + colGap + col2Width
        let headerMinWidth: CGFloat = showsActions ? 176 : 0
        let contentWidth = max(gridWidth, headerMinWidth)

        var numRows = 1 // Coordinates row
        if wValStr != nil { numRows += 1 }
        if rValStr != nil { numRows += 1 }

        let gridHeight = CGFloat(numRows) * rowHeight + CGFloat(max(0, numRows - 1)) * rowGap
        let totalWidth = contentWidth + padX * 2
        let totalHeight = padY * 2 + headerHeight + dividerGap + gridHeight

        // Compute badge position
        let badgeRect: NSRect
        if let box {
            var x = box.midX - totalWidth / 2.0
            var y = box.minY - totalHeight - 12.0
            if y < bounds.minY + 4 {
                y = box.maxY + 12.0
            }
            x = min(max(x, bounds.minX + 4), bounds.maxX - totalWidth - 4)
            y = min(max(y, bounds.minY + 4), bounds.maxY - totalHeight - 4)
            badgeRect = NSRect(x: x.rounded(), y: y.rounded(), width: totalWidth.rounded(), height: totalHeight.rounded())
        } else {
            let pt = point ?? .zero
            var x = pt.x + 14
            var y = pt.y + 14
            x = min(max(x, bounds.minX + 2), bounds.maxX - totalWidth - 2)
            y = min(max(y, bounds.minY + 2), bounds.maxY - totalHeight - 2)
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
            let shapeIcon = shapeType == .circle ? "circle" : "rectangle"
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
                lblAttr.draw(at: NSPoint(x: x + 1, y: cellY))
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

        // Position Row (X, Y)
        drawCell(metric: .x, symbolName: nil, drawCustom: nil, textLabel: "X", value: xValStr, x: col1X, y: currentY)
        drawCell(metric: .y, symbolName: nil, drawCustom: nil, textLabel: "Y", value: yValStr, x: col2X, y: currentY)

        return ReadoutBadgeLayout(badgeRect: badgeRect, closeRect: outCloseRect, editRect: outEditRect, moveRect: outMoveRect, metricHits: metricHits)
    }

    /// Creates an unrasterized, resolution-independent vector SF Symbol tinted with palette colors.
    private static func makeVectorSymbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    }

    /// Draws a vector symbol centered within a slot rectangle without distortion.
    private static func drawSymbol(_ sym: NSImage, centeredIn slotRect: NSRect) {
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
