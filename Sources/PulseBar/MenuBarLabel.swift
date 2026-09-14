import AppKit
import CoreText
import SpeedCore

enum MenuBarLabel {
    static func image(cpu: String, memory: String, diskRead: String, diskWrite: String,
                      download: String, upload: String, selection: MenuBarSelection) -> NSImage {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .medium),
            .foregroundColor: NSColor.black
        ]
        func group(_ minimumWidth: CGFloat, _ rows: [String]) -> (width: CGFloat, rows: [String]) {
            let widest = rows.map { text in
                let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
                return CTLineGetBoundsWithOptions(line, .useGlyphPathBounds).width
            }.max() ?? 0
            return (max(minimumWidth, ceil(widest) + 4), rows)
        }
        var groups: [(width: CGFloat, rows: [String])] = []
        var usageRows: [String] = []
        if selection.contains(.cpu) { usageRows.append("CPU \(cpu)") }
        if selection.contains(.memory) { usageRows.append("MEM \(memory)") }
        if !usageRows.isEmpty { groups.append(group(74, usageRows)) }
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
                for (index, text) in group.rows.enumerated() {
                    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
                    let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
                    let rowCenter = rect.maxY - (CGFloat(index) + 0.5) * rect.height / CGFloat(group.rows.count)
                    context.textPosition = CGPoint(x: left + group.width - 2 - ink.maxX, y: rowCenter - ink.midY)
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
