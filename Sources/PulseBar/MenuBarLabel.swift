import AppKit
import CoreText
import SpeedCore

enum MenuBarLabel {
    static let ringsWidth: CGFloat = 22

    static func image(diskRead: String, diskWrite: String,
                      download: String, upload: String, selection: MenuBarSelection) -> NSImage {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .medium),
            .foregroundColor: NSColor.black
        ]
        let unitLine = CTLineCreateWithAttributedString(NSAttributedString(string: "MB/s", attributes: attributes))
        let unitInk = CTLineGetBoundsWithOptions(unitLine, .useGlyphPathBounds)
        let unitSpacing: CGFloat = 4
        func group(_ minimumWidth: CGFloat, _ rows: [String]) -> (width: CGFloat, rows: [String], showsUnit: Bool) {
            let widest = rows.map { text in
                let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
                return CTLineGetBoundsWithOptions(line, .useGlyphPathBounds).width
            }.max() ?? 0
            return (max(minimumWidth, ceil(widest + unitSpacing + unitInk.width) + 4), rows, true)
        }
        var groups: [(width: CGFloat, rows: [String], showsUnit: Bool)] = []
        // Reserve space for the native gauges layered over the status button.
        // Keep the remaining image templated so AppKit handles text contrast.
        if selection.contains(.cpu) || selection.contains(.memory) {
            groups.append((ringsWidth, [], false))
        }
        if selection.contains(.disk) { groups.append(group(86, ["R \(diskRead)", "W \(diskWrite)"])) }
        if selection.contains(.network) { groups.append(group(86, ["↓ \(download)", "↑ \(upload)"])) }
        let width = groups.reduce(CGFloat(0)) { $0 + $1.width } + CGFloat(max(0, groups.count - 1)) * 8
        // A multiline NSButton title uses title-cell baseline positioning,
        // which can push the first row against the top of a taller menu bar.
        // Native status-item images are centered as one block instead.
        let image = NSImage(size: NSSize(width: width, height: 22), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            var left: CGFloat = 0
            var separators: [CGFloat] = []
            for (groupIndex, group) in groups.enumerated() {
                var rowRight = left + group.width - 2
                if group.showsUnit {
                    // Both rates share one unit, centered between the two rows.
                    context.textPosition = CGPoint(x: rowRight - unitInk.maxX, y: rect.midY - unitInk.midY)
                    CTLineDraw(unitLine, context)
                    rowRight -= unitInk.width + unitSpacing
                }
                for (index, text) in group.rows.enumerated() {
                    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
                    let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
                    let rowCenter = rect.maxY - (CGFloat(index) + 0.5) * rect.height / CGFloat(group.rows.count)
                    context.textPosition = CGPoint(x: rowRight - ink.maxX, y: rowCenter - ink.midY)
                    CTLineDraw(line, context)
                }
                left += group.width + 8
                if groupIndex + 1 < groups.count { separators.append(left - 4) }
            }
            context.setStrokeColor(NSColor.black.withAlphaComponent(0.25).cgColor)
            context.setLineWidth(0.5)
            for x in separators {
                context.move(to: CGPoint(x: x, y: 4))
                context.addLine(to: CGPoint(x: x, y: 18))
            }
            context.strokePath()
            return true
        }
        image.isTemplate = true
        return image
    }
}
