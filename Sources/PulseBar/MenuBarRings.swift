import AppKit
import SpeedCore
import SwiftUI

struct MenuBarRingReadings: Equatable {
    var cpu: Double?
    var memory: Double?
    var storage: Double?
    var gpu: Double?
    var battery: Double?
    var pressure: MemoryPressure?

    init(cpu: Double? = nil, memory: Double? = nil, storage: Double? = nil,
         gpu: Double? = nil, battery: Double? = nil, pressure: MemoryPressure? = nil) {
        self.cpu = cpu; self.memory = memory; self.storage = storage
        self.gpu = gpu; self.battery = battery; self.pressure = pressure
    }

    init(monitor: SystemMonitor) {
        self.init(cpu: monitor.resources.cpu?.usedPercent, memory: monitor.resources.memory?.usedPercent,
                  storage: monitor.storageCapacity?.usedPercent,
                  gpu: monitor.gpuUsage.map(\.utilizationPercent).max(),
                  battery: monitor.battery?.chargePercent, pressure: monitor.resources.pressure)
    }

    func value(for metric: MenuBarRingMetric) -> Double? {
        let reading: Double?
        switch metric {
        case .cpu: reading = cpu
        case .memory: reading = memory
        case .storage: reading = storage
        case .gpu: reading = gpu
        case .battery: reading = battery
        }
        return reading.flatMap { $0.isFinite ? min(100, max(0, $0)) : nil }
    }

    func tint(for metric: MenuBarRingMetric) -> Color {
        guard let value = value(for: metric) else { return Color(nsColor: .disabledControlTextColor) }
        if metric == .memory { return InsightStyle.pressureColor(pressure) }
        if metric == .battery {
            return value <= 10 ? InsightStyle.dangerColor : value <= 20
                ? Color(nsColor: .systemYellow) : Color(nsColor: .systemGreen)
        }
        return InsightStyle.utilizationColor(value)
    }
}

private final class MenuBarRingsState: ObservableObject {
    @Published var readings = MenuBarRingReadings()
    @Published var selection = MenuBarSelection()
}

/// Keep the status item's native button, tooltip, highlighting and click target.
/// Only the gauges are colored; the disk/network image remains a template.
final class MenuBarRingsHost: StatusItemHoverRegion {
    private let state: MenuBarRingsState
    private let hosting: NSHostingView<MenuBarRingsContent>

    init() {
        let state = MenuBarRingsState()
        self.state = state
        hosting = NSHostingView(rootView: MenuBarRingsContent(state: state))
        super.init(frame: NSRect(x: 0, y: 0, width: MenuBarLabel.ringsWidth, height: 22))
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init()") }

    func update(readings: MenuBarRingReadings, selection: MenuBarSelection) {
        isHidden = !selection.showsRings
        // Keep the hosted view alive so sampling interpolates existing arcs.
        if state.readings != readings { state.readings = readings }
        if state.selection != selection { state.selection = selection }
    }
}

private struct MenuBarRingsContent: View {
    @ObservedObject var state: MenuBarRingsState

    var body: some View { MenuBarRings(readings: state.readings, selection: state.selection) }
}

struct MenuBarRings: View {
    let readings: MenuBarRingReadings
    let selection: MenuBarSelection
    var body: some View {
        ZStack {
            // 22 / 13 pt, equal 3.5 pt strokes: a 1 pt clear gap and 6 pt
            // hollow center remain legible at the actual menu-bar size.
            if selection.showsRings {
                ForEach(MenuBarRingPosition.allCases, id: \.self) { position in
                    let metric = selection.ringMetric(at: position)
                    MenuBarRing(value: readings.value(for: metric), diameter: position == .outer ? 22 : 13,
                                thickness: 3.5, tint: readings.tint(for: metric))
                }
            }
        }
        .frame(width: MenuBarLabel.ringsWidth, height: 22)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

}

private struct MenuBarRing: View {
    let value: Double?
    let diameter: CGFloat
    let thickness: CGFloat
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let normalized = value.flatMap { $0.isFinite ? min(100, max(0, $0)) : nil }
        return Gauge(value: normalized ?? 0, in: 0...100) { EmptyView() }
            .gaugeStyle(MenuBarCapacityGaugeStyle(thickness: thickness))
            .tint(normalized == nil ? Color(nsColor: .disabledControlTextColor) : tint)
            .labelsHidden()
            .frame(width: diameter, height: diameter)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: normalized)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: tint)
    }
}

/// Gauge's public styling API provides a predictable stroke at menu-bar size,
/// without shrinking a full-size accessory gauge and its line width.
private struct MenuBarCapacityGaugeStyle: GaugeStyle {
    let thickness: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            // Keep a complete, neutral circle visible when the progress tint changes.
            Circle().strokeBorder(lineWidth: thickness)
                .foregroundStyle(Color(nsColor: .systemGray)).opacity(0.45)
            Circle().inset(by: thickness / 2)
                .trim(from: 0, to: configuration.value)
                .stroke(style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                .foregroundStyle(.tint)
                .rotationEffect(.degrees(-90))
        }
    }
}
