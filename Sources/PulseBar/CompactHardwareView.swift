import AppKit
import SpeedCore
import SwiftUI

enum HardwarePalette {
    static let cpu = Color(nsColor: .systemBlue)
    static let memory = Color(nsColor: .systemPurple)
    static let download = Color(nsColor: .systemBlue)
    static let upload = InsightStyle.normalColor
}

struct MetricNumber: View {
    let value: String
    var unit = ""
    var size: CGFloat = 24

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value).font(.system(size: size, weight: .medium)).monospacedDigit()
                .contentTransition(.identity)
            if !unit.isEmpty { Text(unit).font(.system(size: 11)).foregroundStyle(.secondary) }
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
    }
}

struct MetricRing: View {
    let value: Double?
    let symbol: String
    let color: Color

    var body: some View {
        Gauge(value: min(100, max(0, value ?? 0)), in: 0...100) {
            EmptyView()
        } currentValueLabel: {
            Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(color)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(color)
        .controlSize(.small)
        .accessibilityHidden(true)
    }
}

struct CompactHardwareView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var preferences: AppPreferences
    let panelWidth: CGFloat
    let onOpen: (PanelRoute) -> Void
    var onHoverModule: ((PanelRoute, Bool) -> Void)?
    private var l10n: Localizer { preferences.localizer }
    private var tileWidth: CGFloat { max(0, (panelWidth - 40) / 2) }
    private var tileHeight: CGFloat { max(188, tileWidth) }
    private var compact: Bool { tileWidth < 190 }
    private var showsGPU: Bool { !monitor.gpuUsage.isEmpty || temperature(.gpu) != nil }

    var body: some View {
        ScrollViewReader { proxy in
          FittingScrollView {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    tile {
                        VStack(spacing: 0) {
                            module(.cpu, route: .cpuDetails) { cpu }
                            if showsGPU {
                                Divider().padding(.horizontal, 14)
                                module(.gpu, route: .gpuDetails, verticalPadding: 10) { gpu }
                                    .frame(height: 45)
                            }
                        }
                    }
                    tile { module(.memory, route: .memoryDetails) { memory } }
                }
                HStack(alignment: .top, spacing: 12) {
                    tile { module(.network, route: .networkDetails) { network } }
                    tile { module(.storage, route: .storageDetails) { storage } }
                }
                if let battery = monitor.battery, battery.isDisplayable || temperature(.battery) != nil {
                    module(.battery, route: .batteryDetails, verticalPadding: 12) { batteryRow(battery) }
                        .frame(height: 48)
                        .background(cardBackground)
                }
                HStack {
                    Text(l10n(.sessionUpload) + " " + TrafficFormatter.total(monitor.totalSent))
                    Spacer(minLength: 8)
                    Text(l10n(.sessionDownload) + " " + TrafficFormatter.total(monitor.totalReceived))
                }
                .font(.system(size: compact ? 10 : 11)).foregroundStyle(.secondary).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.85)
                .padding(.horizontal, 5)
            }
            .padding(.horizontal, 14).padding(.bottom, 8)
            .id("hardware-content")
          }
          .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PulseBar.hardware-preview-scroll"))) { _ in
              proxy.scrollTo("hardware-content", anchor: .bottom)
          }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.quinary.opacity(0.45))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
            }
    }

    private func tile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: tileWidth, height: tileHeight)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func module<Content: View>(_ title: TextKey, route: PanelRoute, verticalPadding: CGFloat = 14,
                                      @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            // One borderless native hit area per action; only the tile draws
            // a surface, so CPU/GPU never acquire a doubled bezel at their join.
            NativeGlassButton(title: l10n(.hardwareDetails, l10n(title)), symbol: "", iconOnly: true,
                              fillsBounds: true) { onOpen(route) }
                .accessibilityHidden(true)
            content().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 14).padding(.vertical, verticalPadding)
                .allowsHitTesting(false)
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n(.hardwareDetails, l10n(title)))
        .accessibilityValue(accessibilityValue(for: route))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onOpen(route) }
        .background(NativeHoverRegion { onHoverModule?(route, $0) })
    }

    private func accessibilityValue(for route: PanelRoute) -> String {
        switch route {
        case .cpuDetails: return SystemFormatter.percent(monitor.resources.cpu?.usedPercent)
        case .memoryDetails:
            return monitor.resources.memory.map { TrafficFormatter.total($0.usedBytes) + " / " + TrafficFormatter.total($0.totalBytes) }
                ?? l10n(.waiting)
        case .networkDetails:
            guard monitor.networkError == nil else { return l10n(.retrying) }
            return l10n(.upload) + " " + TrafficFormatter.speed(monitor.rate.upload, mode: preferences.networkSpeedMode).text + ", "
                + l10n(.download) + " " + TrafficFormatter.speed(monitor.rate.download, mode: preferences.networkSpeedMode).text
        case .storageDetails: return monitor.storageCapacity.map { l10n(.availableSpace, TrafficFormatter.total($0.availableBytes)) } ?? l10n(.waiting)
        case .gpuDetails: return monitor.gpuUsage.map { $0.name + " " + SystemFormatter.percent($0.utilizationPercent) }.joined(separator: ", ")
        case .batteryDetails: return SystemFormatter.percent(monitor.battery?.chargePercent)
        default: return ""
        }
    }

    private func title<Trailing: View>(_ key: TextKey, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 7) {
            Text(l10n(key)).font(.system(size: 13, weight: .semibold))
            Spacer(minLength: 4)
            trailing().font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
        }
    }

    private var cpu: some View {
        VStack(alignment: .leading, spacing: 8) {
            title(.cpu) { temperatureLabel(.cpu) }
            HStack(spacing: 10) {
                if !compact { MetricRing(value: monitor.resources.cpu?.usedPercent, symbol: "cpu", color: HardwarePalette.cpu) }
                percent(monitor.resources.cpu?.usedPercent)
            }
            if tileWidth >= 160 {
                Text(l10n(.userSystem, SystemFormatter.percent(monitor.resources.cpu?.userPercent),
                          SystemFormatter.percent(monitor.resources.cpu?.systemPercent)))
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
            spark(monitor.resources.cpuHistory, maximum: 100, color: HardwarePalette.cpu, height: showsGPU ? 24 : 40)
            HardwareErrorLabel(error: monitor.resources.cpuError, localizer: l10n)
        }
    }

    private var memory: some View {
        VStack(alignment: .leading, spacing: 8) {
            title(.memory) { temperatureLabel(.memory) }
            HStack(spacing: 10) {
                if !compact { MetricRing(value: monitor.resources.memory?.usedPercent, symbol: "memorychip", color: HardwarePalette.memory) }
                if let memory = monitor.resources.memory {
                    let amount = TrafficFormatter.amount(memory.usedBytes, unitFor: memory.totalBytes)
                    MetricNumber(value: amount.value, unit: amount.unit, size: compact ? 24 : 27)
                } else { MetricNumber(value: "—") }
            }
            if let memory = monitor.resources.memory {
                Text(l10n(.usedPercent, SystemFormatter.percent(memory.usedPercent)) + " · " + TrafficFormatter.total(memory.totalBytes))
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.85)
            }
            if let pressure = monitor.resources.pressure {
                HStack(spacing: 5) {
                    Circle().fill(InsightStyle.pressureColor(pressure)).frame(width: 5, height: 5)
                    Text(l10n(.pressureState, l10n(pressure.titleKey)))
                        .foregroundStyle(InsightStyle.pressureColor(pressure))
                }.font(.system(size: 10)).lineLimit(1)
            }
            Spacer(minLength: 0)
            if let swap = monitor.resources.swap {
                Text("Swap " + TrafficFormatter.total(swap.usedBytes))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            spark(monitor.resources.memoryHistory, maximum: 100, color: HardwarePalette.memory, height: 30)
            HardwareErrorLabel(error: monitor.resources.memoryError ?? monitor.resources.pressureError ?? monitor.resources.swapError,
                               localizer: l10n)
        }
    }

    private var network: some View {
        VStack(alignment: .leading, spacing: 8) {
            title(.network) { EmptyView() }
            Text(monitor.interfaces.isEmpty ? l10n(.noInterfaces) : monitor.interfaceDescription(using: l10n))
                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            trafficRow(.upload, value: monitor.networkError == nil ? monitor.rate.upload : nil, color: HardwarePalette.upload)
            trafficRow(.download, value: monitor.networkError == nil ? monitor.rate.download : nil, color: HardwarePalette.download)
            Spacer(minLength: 0)
            spark(monitor.history, maximum: rateMaximum(monitor.history), color: HardwarePalette.download,
                  secondary: HardwarePalette.upload, height: 40)
            HardwareErrorLabel(error: monitor.networkError, localizer: l10n)
        }
    }

    private var storage: some View {
        VStack(alignment: .leading, spacing: 8) {
            title(.storage) { temperatureLabel(.storage) }
            if tileWidth >= 160 {
                Text(monitor.storageCapacity?.name ?? l10n(.startupVolumeSpace))
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            if let capacity = monitor.storageCapacity {
                let amount = TrafficFormatter.amount(capacity.availableBytes)
                MetricNumber(value: amount.value, unit: amount.unit + " " + l10n(.availableShort), size: compact ? 24 : 27)
                Text(l10n(.usedPercent, SystemFormatter.percent(capacity.usedPercent)))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                ProgressView(value: capacity.usedPercent, total: 100)
                    .progressViewStyle(.linear).tint(HardwarePalette.download)
                    .accessibilityLabel(l10n(.startupVolumeUsed))
                    .accessibilityValue(SystemFormatter.percent(capacity.usedPercent))
                Text(capacityText(capacity)).font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit()
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(l10n(.diskRateSummary,
                          monitor.resources.diskRate.map { TrafficFormatter.speed($0.read, mode: preferences.diskSpeedMode).text } ?? "—",
                          monitor.resources.diskRate.map { TrafficFormatter.speed($0.write, mode: preferences.diskSpeedMode).text } ?? "—"))
                    .font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit()
                    .lineLimit(tileWidth < 160 ? 2 : 1).minimumScaleFactor(0.85)
            } else {
                HStack(spacing: 16) {
                    rate(.read, value: monitor.resources.diskRate?.read, color: HardwarePalette.download)
                    rate(.write, value: monitor.resources.diskRate?.write, color: HardwarePalette.memory)
                }
            }
            HardwareErrorLabel(error: monitor.resources.diskError, localizer: l10n)
        }
    }

    private var gpu: some View {
        HStack(spacing: 5) {
            Text(l10n(.gpu)).fontWeight(.semibold)
            Spacer(minLength: 3)
            if let usage = monitor.gpuUsage.map(\.utilizationPercent).max() {
                Text(SystemFormatter.percent(usage)).monospacedDigit()
            }
            if !compact { temperatureLabel(.gpu).font(.system(size: 10)).foregroundStyle(.secondary) }
            Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .font(.system(size: 11))
    }

    private func batteryRow(_ battery: BatterySnapshot) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "battery.100").foregroundStyle(.secondary)
            Text(l10n(.battery)).fontWeight(.semibold)
            if let state = battery.powerState { Text(l10n(state.titleKey)).font(.system(size: 11)).foregroundStyle(.secondary) }
            Spacer(minLength: 4)
            Text(SystemFormatter.percent(battery.chargePercent)).monospacedDigit()
            Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .font(.system(size: 12))
    }

    private func rate(_ title: TextKey, value: Double?, color: Color) -> some View {
        let amount = value.map { TrafficFormatter.speed($0, mode: preferences.diskSpeedMode) }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 4, height: 4)
                Text(l10n(title)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            MetricNumber(value: amount?.value ?? "—", unit: amount?.unit ?? "", size: 21)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trafficRow(_ title: TextKey, value: Double?, color: Color) -> some View {
        let amount = value.map { TrafficFormatter.speed($0, mode: preferences.networkSpeedMode) }
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Circle().fill(color).frame(width: 4, height: 4).alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
            if tileWidth < 160 {
                Image(systemName: title == .upload ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10)).foregroundStyle(.secondary).accessibilityLabel(l10n(title))
            } else {
                Text(l10n(title)).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            MetricNumber(value: amount?.value ?? "—", unit: amount?.unit ?? "", size: compact ? 17 : 21)
        }
    }

    private func percent(_ value: Double?) -> some View {
        MetricNumber(value: value.map { String(format: "%.1f", $0) } ?? "—", unit: value == nil ? "" : "%", size: compact ? 24 : 27)
    }

    private func spark(_ points: [HistoryPoint], maximum: Double, color: Color, secondary: Color? = nil,
                       height: CGFloat = 40) -> some View {
        HistoryChart(points: HistoryInspection.window(points, seconds: preferences.historySeconds, endingAt: monitor.timelineEnd),
                     maximum: maximum, primaryColor: color, secondaryColor: secondary,
                     durationSeconds: preferences.historySeconds, endingAt: monitor.timelineEnd, showsGrid: false)
            .frame(maxWidth: .infinity).frame(height: height)
            .accessibilityHidden(true)
    }

    private func rateMaximum(_ points: [HistoryPoint]) -> Double {
        let visible = HistoryInspection.window(points, seconds: preferences.historySeconds, endingAt: monitor.timelineEnd)
        return max(1_000, visible.reduce(0) { max($0, $1.primary, $1.secondary) } * 1.15)
    }

    private func temperature(_ component: TemperatureComponent) -> TemperatureReading? {
        monitor.temperatures.first { $0.component == component }
    }

    @ViewBuilder private func temperatureLabel(_ component: TemperatureComponent) -> some View {
        if let reading = temperature(component) {
            Text(String(format: "%.1f °C", reading.celsius)).monospacedDigit()
                .help(l10n(.temperatureHelp))
        }
    }

    private func capacityText(_ capacity: StorageCapacity) -> String {
        let used = TrafficFormatter.amount(capacity.usedBytes, unitFor: capacity.totalBytes)
        return used.value + " / " + TrafficFormatter.amount(capacity.totalBytes).text
    }
}

struct HardwareErrorLabel: View {
    let error: Error?
    let localizer: Localizer

    var body: some View {
        if let message = localizer.describe(error) {
            Text(message).font(.system(size: 11)).foregroundStyle(.orange)
                .lineLimit(2).help(message)
        }
    }
}

extension BatterySnapshot {
    var isDisplayable: Bool {
        chargePercent != nil || powerState != nil || healthPercent != nil || cycleCount != nil || timeEstimate != nil
    }
}

extension BatteryPowerState {
    var titleKey: TextKey {
        switch self {
        case .charging: return .batteryCharging
        case .full: return .batteryFull
        case .onBattery: return .batteryOnBattery
        case .externalPower: return .batteryExternalPower
        }
    }
}
