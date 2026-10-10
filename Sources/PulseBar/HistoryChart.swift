import Charts
import SpeedCore
import SwiftUI

/// Swift Charts owns plotting, axes, clipping, and accessibility. Inspection
/// still reads actual samples from the shared monitoring timeline.
struct HistoryChart: View {
    let points: [HistoryPoint]
    let maximum: Double
    let primaryColor: Color
    var secondaryColor: Color?
    let durationSeconds: Int
    let endingAt: TimeInterval
    var inspectedTime: TimeInterval?
    var onInspect: ((TimeInterval?) -> Void)?
    var showsGrid = true
    var fillsArea = true

    var body: some View {
        GeometryReader { geometry in
            let plotted = HistoryWindow.plotPoints(points, maximumCount: max(6, Int(geometry.size.width * 2)))
            Chart {
                ForEach(Array(plotted.enumerated()), id: \.offset) { _, point in
                    if fillsArea {
                        AreaMark(x: .value("Time", point.timestamp),
                                 yStart: .value("Baseline", 0),
                                 yEnd: .value("Value", point.primary),
                                 series: .value("Series", "Primary"))
                            .foregroundStyle(primaryColor.opacity(0.12))
                    }
                    LineMark(x: .value("Time", point.timestamp), y: .value("Value", point.primary),
                             series: .value("Series", "Primary"))
                        .foregroundStyle(primaryColor)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    if let secondaryColor {
                        LineMark(x: .value("Time", point.timestamp), y: .value("Value", point.secondary),
                                 series: .value("Series", "Secondary"))
                            .foregroundStyle(secondaryColor)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
                if let inspectedTime, inspectedTime >= endingAt - Double(durationSeconds), inspectedTime <= endingAt {
                    RuleMark(x: .value("Time", inspectedTime))
                        .foregroundStyle(.secondary)
                    if let sample = HistoryInspection.sample(points, at: inspectedTime) {
                        PointMark(x: .value("Time", sample.timestamp), y: .value("Value", sample.primary))
                            .foregroundStyle(primaryColor)
                        if let secondaryColor {
                            PointMark(x: .value("Time", sample.timestamp), y: .value("Value", sample.secondary))
                                .foregroundStyle(secondaryColor)
                        }
                    }
                }
            }
            .chartXScale(domain: (endingAt - Double(durationSeconds))...endingAt)
            .chartYScale(domain: 0...max(1, maximum))
            .chartXAxis(.hidden)
            .chartYAxis {
                if showsGrid {
                    AxisMarks(values: [0, max(1, maximum) / 2, max(1, maximum)]) {
                        AxisGridLine()
                    }
                }
            }
            .chartLegend(.hidden)
            .chartPlotStyle { $0.clipped() }
            .chartOverlay { proxy in
                GeometryReader { chartGeometry in
                    Color.clear.contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case let .active(location):
                                let plot = chartGeometry[proxy.plotAreaFrame]
                                let x = min(plot.width, max(0, location.x - plot.minX))
                                let timestamp: Double? = proxy.value(atX: x)
                                onInspect?(timestamp)
                            case .ended: onInspect?(nil)
                            }
                        }
                }
                .allowsHitTesting(onInspect != nil)
            }
        }
    }
}
