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
        let labelWidth: CGFloat
        let labelSpacing: CGFloat
        let valueWidth: CGFloat
        let unitSpacing: CGFloat
        let numberInkMidY: CGFloat
        let values: [CTLine]
        let labels: [CTLine]
        let unit: CTLine?
    }

    static func layout(cpu: String = "—", memory: String = "—", diskRead: String, diskWrite: String,
                       download: String, upload: String, selection: MenuBarSelection) -> Layout {
        let labelWidth: CGFloat = 10
        let labelSpacing: CGFloat = 4
        let groupSpacing: CGFloat = 14
        let valueWidth: CGFloat = 36
        let unitSpacing: CGFloat = 5
        let unitWidth: CGFloat = 22
        let rateGroupWidth = labelWidth + labelSpacing + valueWidth + unitSpacing + unitWidth + 2

        func group(_ target: StatusItemHintTarget, labels: [String], readings: [String], percentages: Bool = false) -> Group {
            // Every part of a single reading uses the same menu-bar size.
            // Two readings retain the compact type that fits a 22 pt item.
            let isSingleRow = readings.count == 1
            let numberSize = isSingleRow ? NSFont.menuBarFont(ofSize: 0).pointSize : 10.5
            let fontScale = numberSize / 10.5
            let numberAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: numberSize, weight: .medium),
                .foregroundColor: NSColor.black
            ]
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: isSingleRow ? numberSize : 9.5, weight: .medium),
                .foregroundColor: NSColor.black.withAlphaComponent(0.65)
            ]
            let values = readings.map {
                CTLineCreateWithAttributedString(NSAttributedString(string: $0, attributes: numberAttributes))
            }
            let labelLines = labels.map {
                CTLineCreateWithAttributedString(NSAttributedString(string: $0, attributes: labelAttributes))
            }
            let unit = CTLineCreateWithAttributedString(NSAttributedString(string: percentages ? "%" : "MB/s", attributes: [
                .font: NSFont.systemFont(ofSize: isSingleRow ? numberSize : (percentages ? 9.5 : 8.5), weight: .medium),
                .foregroundColor: NSColor.black.withAlphaComponent(0.65)
            ]))
            let numberLine = CTLineCreateWithAttributedString(NSAttributedString(string: "0.0", attributes: numberAttributes))
            var groupLabelWidth = (percentages ? 24 : labelWidth) * fontScale
            var groupLabelSpacing = labelSpacing * fontScale
            var groupValueWidth = valueWidth * fontScale
            var groupUnitSpacing = unitSpacing * fontScale
            var groupWidth = percentages ? 80 : rateGroupWidth
            if isSingleRow {
                let labelInkWidth = labelLines.map { CTLineGetBoundsWithOptions($0, .useGlyphPathBounds).width }.max() ?? 0
                groupLabelWidth = max(groupLabelWidth, ceil(labelInkWidth))
                if !percentages {
                    // Keep ordinary rates steady without reserving space for
                    // thousands. Longer rates expand instead of shrinking text.
                    let reservedWidth: CGFloat = ["99.9", "<0.1"].map {
                        let line = CTLineCreateWithAttributedString(NSAttributedString(string: $0, attributes: numberAttributes))
                        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
                    }.max() ?? 0
                    let readingWidth = values.map { CGFloat(CTLineGetTypographicBounds($0, nil, nil, nil)) }.max() ?? 0
                    groupValueWidth = ceil(max(reservedWidth, readingWidth))
                    groupLabelSpacing = 3
                    groupUnitSpacing = 3
                }
                let unitWidth = CGFloat(CTLineGetTypographicBounds(unit, nil, nil, nil))
                groupWidth = ceil(groupLabelWidth + groupLabelSpacing + groupValueWidth + groupUnitSpacing + unitWidth + 2 * fontScale)
            }
            return Group(target: target, width: groupWidth,
                         labelWidth: groupLabelWidth, labelSpacing: groupLabelSpacing,
                         valueWidth: groupValueWidth, unitSpacing: groupUnitSpacing,
                         numberInkMidY: CTLineGetBoundsWithOptions(numberLine, .useGlyphPathBounds).midY,
                         values: values, labels: labelLines, unit: unit)
        }

        var groups: [Group] = []
        // The colored native gauges occupy the first region of the template image.
        if selection.showsRings {
            groups.append(Group(target: .rings, width: ringsWidth, labelWidth: 0, labelSpacing: 0, valueWidth: 0, unitSpacing: 0,
                                numberInkMidY: 0, values: [], labels: [], unit: nil))
        }
        let usage = [(MenuBarNumberMetric.cpu, "CPU", cpu), (.memory, "MEM", memory)]
            .filter { selection.showsNumber($0.0) }
        if !usage.isEmpty {
            groups.append(group(.usage, labels: usage.map { $0.1 }, readings: usage.map { $0.2 }, percentages: true))
        }
        let disk = [(MenuBarNumberMetric.diskRead, "R", diskRead), (.diskWrite, "W", diskWrite)]
            .filter { selection.showsNumber($0.0) }
        if !disk.isEmpty {
            groups.append(group(.disk, labels: disk.map { $0.1 }, readings: disk.map { $0.2 }))
        }
        let network = [(MenuBarNumberMetric.upload, "↑", upload), (.download, "↓", download)]
            .filter { selection.showsNumber($0.0) }
        if !network.isEmpty {
            groups.append(group(.network, labels: network.map { $0.1 }, readings: network.map { $0.2 }))
        }

        var regions: [StatusItemHintTarget: NSRect] = [:]
        var left: CGFloat = 0
        for group in groups {
            regions[group.target] = NSRect(x: left, y: 0, width: group.width, height: 22)
            left += group.width + groupSpacing
        }
        let width = max(0, left - groupSpacing)
        let image = NSImage(size: NSSize(width: width, height: 22), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            for (index, group) in groups.enumerated() {
                guard let region = regions[group.target] else { continue }
                if !group.values.isEmpty {
                    let valuesLeft = region.minX + group.labelWidth + group.labelSpacing
                    let groupValueWidth = group.valueWidth
                    for (valueIndex, line) in group.values.enumerated() {
                        // The first rate is the upper row in the unflipped image.
                        let rowCenter = rect.midY + (group.values.count == 1 ? 0 : valueIndex == 0 ? 5.5 : -5.5)
                        let label = group.labels[valueIndex]
                        let labelInk = CTLineGetBoundsWithOptions(label, .useGlyphPathBounds)
                        context.textPosition = CGPoint(x: region.minX + group.labelWidth / 2 - labelInk.midX,
                                                       y: rowCenter - labelInk.midY)
                        CTLineDraw(label, context)
                        let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
                        // Both rows share a right-aligned column. Single rates
                        // have enough width to retain their full-size text;
                        // compact paired readings shrink only when needed.
                        let scale = min(1, groupValueWidth / max(1, textWidth))
                        context.saveGState()
                        context.translateBy(x: valuesLeft + groupValueWidth - textWidth * scale,
                                            y: rowCenter - group.numberInkMidY * scale)
                        context.scaleBy(x: scale, y: scale)
                        context.textPosition = .zero
                        CTLineDraw(line, context)
                        context.restoreGState()
                    }
                    if let unit = group.unit {
                        let unitInk = CTLineGetBoundsWithOptions(unit, .useGlyphPathBounds)
                        context.textPosition = CGPoint(x: valuesLeft + groupValueWidth + group.unitSpacing,
                                                       y: rect.midY - unitInk.midY)
                        CTLineDraw(unit, context)
                    }
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
