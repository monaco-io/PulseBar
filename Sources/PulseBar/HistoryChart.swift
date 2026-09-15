import SpeedCore
import SwiftUI

struct HistoryChart: View {
    let points: [HistoryPoint]
    let maximum: Double
    let primaryColor: Color
    var secondaryColor: Color?
    let durationSeconds: Int
    let endingAt: TimeInterval
    var inspectedTime: TimeInterval?
    var onInspect: ((TimeInterval?) -> Void)?

    var body: some View {
        Canvas { context, size in
            context.clip(to: Path(CGRect(origin: .zero, size: size)))
            for fraction in [0.0, 0.5, 1.0] {
                var grid = Path()
                let y = 1 + (size.height - 2) * fraction
                grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(grid, with: .color(.secondary.opacity(0.16)),
                               style: StrokeStyle(lineWidth: 0.5, dash: fraction == 1 ? [] : [3, 4]))
            }
            if points.count > 1 {
                let plotted = HistoryWindow.plotPoints(points, maximumCount: max(6, Int(size.width * 2)))
                for isPrimary in [true, false] {
                    guard let color = isPrimary ? primaryColor : secondaryColor else { continue }
                    let positions = plotted.map { point in
                        CGPoint(x: x(point.timestamp, width: size.width),
                                y: y(isPrimary ? point.primary : point.secondary, height: size.height))
                    }
                    var line = Path(); line.addLines(positions)
                    if isPrimary, let first = positions.first, let last = positions.last {
                        var fill = line
                        fill.addLine(to: CGPoint(x: last.x, y: size.height))
                        fill.addLine(to: CGPoint(x: first.x, y: size.height))
                        fill.closeSubpath()
                        context.fill(fill, with: .linearGradient(
                            Gradient(colors: [color.opacity(0.22), color.opacity(0.01)]),
                            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                    }
                    context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                }
            }
            if let inspectedTime, inspectedTime >= endingAt - Double(durationSeconds), inspectedTime <= endingAt {
                let position = x(inspectedTime, width: size.width)
                var cursor = Path()
                cursor.move(to: CGPoint(x: position, y: 0)); cursor.addLine(to: CGPoint(x: position, y: size.height))
                context.stroke(cursor, with: .color(.primary.opacity(0.65)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                if let point = HistoryInspection.sample(points, at: inspectedTime) {
                    for primary in [true, false] {
                        guard let color = primary ? primaryColor : secondaryColor else { continue }
                        let dot = CGRect(x: position - 2.5, y: y(primary ? point.primary : point.secondary, height: size.height) - 2.5,
                                         width: 5, height: 5)
                        context.fill(Path(ellipseIn: dot), with: .color(color))
                    }
                }
            }
        }
        .overlay {
            GeometryReader { geometry in
                Color.clear.contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case let .active(location):
                            let fraction = min(1, max(0, location.x / max(1, geometry.size.width)))
                            onInspect?(endingAt - Double(durationSeconds) * (1 - fraction))
                        case .ended: onInspect?(nil)
                        }
                    }
            }
        }
    }

    private func x(_ time: TimeInterval, width: CGFloat) -> CGFloat {
        (time - endingAt + Double(durationSeconds)) / Double(durationSeconds) * width
    }
    private func y(_ value: Double, height: CGFloat) -> CGFloat {
        height - 1 - min(1, max(0, value / max(1, maximum))) * (height - 2)
    }
}
