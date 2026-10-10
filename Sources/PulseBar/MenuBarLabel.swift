import AppKit
import CoreText
import SpeedCore

enum MenuBarLabel {
    static let ringsWidth: CGFloat = 22

    struct Layout {
        let image: NSImage
        let regions: [StatusItemHintTarget: NSRect]
    }

    private struct Group {
        let target: StatusItemHintTarget
        let width: CGFloat
        let values: [CTLine]
        let labels: [CTLine]
    }

    static func layout(diskRead: String, diskWrite: String,
                       download: String, upload: String, selection: MenuBarSelection) -> Layout {
        let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
        let numberAttributes: [NSAttributedString.Key: Any] = [.font: numberFont, .foregroundColor: NSColor.black]
        let labelWidth: CGFloat = 10
        let labelSpacing: CGFloat = 4
        let groupSpacing: CGFloat = 14
        let valueWidth: CGFloat = 36
        let unitSpacing: CGFloat = 5
        let unitWidth: CGFloat = 22
        let rateGroupWidth = labelWidth + labelSpacing + valueWidth + unitSpacing + unitWidth + 2
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9.5, weight: .medium),
            .foregroundColor: NSColor.black.withAlphaComponent(0.65)
        ]
        let unitLine = CTLineCreateWithAttributedString(NSAttributedString(string: "MB/s", attributes: [
            .font: NSFont.systemFont(ofSize: 8.5, weight: .medium),
            .foregroundColor: NSColor.black.withAlphaComponent(0.65)
        ]))

        func group(_ target: StatusItemHintTarget, labels: [String], first: String, second: String) -> Group {
            let values = [first, second].map {
                CTLineCreateWithAttributedString(NSAttributedString(string: $0, attributes: numberAttributes))
            }
            let labelLines = labels.map {
                CTLineCreateWithAttributedString(NSAttributedString(string: $0, attributes: labelAttributes))
            }
            return Group(target: target, width: rateGroupWidth, values: values, labels: labelLines)
        }

        var groups: [Group] = []
        // The colored native gauges occupy the first region of the template image.
        if selection.contains(.cpu) || selection.contains(.memory) {
            groups.append(Group(target: .rings, width: ringsWidth, values: [], labels: []))
        }
        if selection.contains(.disk) {
            groups.append(group(.disk, labels: ["R", "W"], first: diskRead, second: diskWrite))
        }
        if selection.contains(.network) {
            groups.append(group(.network, labels: ["↑", "↓"], first: upload, second: download))
        }

        var regions: [StatusItemHintTarget: NSRect] = [:]
        var left: CGFloat = 0
        for group in groups {
            regions[group.target] = NSRect(x: left, y: 0, width: group.width, height: 22)
            left += group.width + groupSpacing
        }
        let width = max(0, left - groupSpacing)
        let numberLine = CTLineCreateWithAttributedString(NSAttributedString(string: "0.0", attributes: numberAttributes))
        let numberInk = CTLineGetBoundsWithOptions(numberLine, .useGlyphPathBounds)
        let unitInk = CTLineGetBoundsWithOptions(unitLine, .useGlyphPathBounds)
        let image = NSImage(size: NSSize(width: width, height: 22), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            for (index, group) in groups.enumerated() {
                guard let region = regions[group.target] else { continue }
                if !group.values.isEmpty {
                    let valuesLeft = region.minX + labelWidth + labelSpacing
                    for (valueIndex, line) in group.values.enumerated() {
                        // The first rate is the upper row in the unflipped image.
                        let rowCenter = rect.midY + (valueIndex == 0 ? 5.5 : -5.5)
                        let label = group.labels[valueIndex]
                        let labelInk = CTLineGetBoundsWithOptions(label, .useGlyphPathBounds)
                        context.textPosition = CGPoint(x: region.minX + labelWidth / 2 - labelInk.midX,
                                                       y: rowCenter - labelInk.midY)
                        CTLineDraw(label, context)
                        let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
                        // Both rows share one fixed, right-aligned value column.
                        // Long readings shrink in place without moving the unit
                        // or hover anchors; the hint keeps full-size readings.
                        let scale = min(1, valueWidth / max(1, textWidth))
                        context.saveGState()
                        context.translateBy(x: valuesLeft + valueWidth - textWidth * scale,
                                            y: rowCenter - numberInk.midY * scale)
                        context.scaleBy(x: scale, y: scale)
                        context.textPosition = .zero
                        CTLineDraw(line, context)
                        context.restoreGState()
                    }
                    context.textPosition = CGPoint(x: valuesLeft + valueWidth + unitSpacing,
                                                   y: rect.midY - unitInk.midY)
                    CTLineDraw(unitLine, context)
                }
                if index + 1 < groups.count {
                    context.setStrokeColor(NSColor.black.withAlphaComponent(0.2).cgColor)
                    context.setLineWidth(0.5)
                    let x = region.maxX + groupSpacing / 2
                    context.move(to: CGPoint(x: x, y: 5))
                    context.addLine(to: CGPoint(x: x, y: 17))
                    context.strokePath()
                }
            }
            return true
        }
        image.isTemplate = true
        return Layout(image: image, regions: regions)
    }
}
