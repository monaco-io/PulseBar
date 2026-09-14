import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let p = CGFloat(pixels)
        let rect = NSRect(x: p * 0.08, y: p * 0.08, width: p * 0.84, height: p * 0.84)
        let background = NSBezierPath(roundedRect: rect, xRadius: p * 0.20, yRadius: p * 0.20)
        NSColor(calibratedRed: 0.04, green: 0.39, blue: 0.90, alpha: 1).setFill()
        background.fill()
        let arrows = NSBezierPath()
        arrows.lineWidth = p * 0.065
        arrows.lineCapStyle = .round
        arrows.lineJoinStyle = .round
        arrows.move(to: NSPoint(x: p * 0.36, y: p * 0.70))
        arrows.line(to: NSPoint(x: p * 0.36, y: p * 0.30))
        arrows.move(to: NSPoint(x: p * 0.23, y: p * 0.43))
        arrows.line(to: NSPoint(x: p * 0.36, y: p * 0.30))
        arrows.line(to: NSPoint(x: p * 0.49, y: p * 0.43))
        arrows.move(to: NSPoint(x: p * 0.64, y: p * 0.30))
        arrows.line(to: NSPoint(x: p * 0.64, y: p * 0.70))
        arrows.move(to: NSPoint(x: p * 0.51, y: p * 0.57))
        arrows.line(to: NSPoint(x: p * 0.64, y: p * 0.70))
        arrows.line(to: NSPoint(x: p * 0.77, y: p * 0.57))
        NSColor.white.setStroke()
        arrows.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let data = bitmap.representation(using: .png, properties: [:])!
        let suffix = scale == 2 ? "@2x" : ""
        try data.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
