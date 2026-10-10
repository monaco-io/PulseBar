import SpeedCore
import SwiftUI

struct HardwareDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var preferences: AppPreferences
    let route: PanelRoute
    let endingAt: TimeInterval
    let inspectedTime: TimeInterval?
    let onInspect: (TimeInterval?) -> Void
    private var l10n: Localizer { preferences.localizer }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch route {
            case .cpuDetails: cpu
            case .memoryDetails: memory
            case .networkDetails: network
            case .storageDetails: storage
            case .gpuDetails: gpu
            case .batteryDetails: battery
            default: EmptyView()
            }
        }
        .font(.system(size: 12))
    }

    private var cpu: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(l10n(.utilization)).foregroundStyle(.secondary)
                    percent(monitor.resources.cpu?.usedPercent)
                }
                Spacer(minLength: 10)
                VStack(spacing: 6) {
                    fact(.cpuUser, SystemFormatter.percent(monitor.resources.cpu?.userPercent))
                    fact(.cpuSystem, SystemFormatter.percent(monitor.resources.cpu?.systemPercent))
                    fact(.logicalCoresLabel, String(ProcessInfo.processInfo.processorCount))
                }
                .frame(width: 150)
            }
            temperature(.cpu)
            HardwareErrorLabel(error: monitor.resources.cpuError, localizer: l10n)
            history(monitor.resources.cpuHistory, color: HardwarePalette.cpu, metric: .cpu)
            rankings(.cpu)
        }
    }

    private var memory: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(l10n(.usedTotal)).foregroundStyle(.secondary)
                    Spacer()
                    if let pressure = monitor.resources.pressure {
                        Label(l10n(.pressureState, l10n(pressure.titleKey)), systemImage: "circle.fill")
                            .font(.system(size: 11)).foregroundStyle(InsightStyle.pressureColor(pressure))
                            .help(l10n(.pressureHelp))
                    }
                }
                if let memory = monitor.resources.memory {
                    let used = TrafficFormatter.amount(memory.usedBytes, unitFor: memory.totalBytes)
                    MetricNumber(value: used.value, unit: "/ " + TrafficFormatter.amount(memory.totalBytes).text, size: 32)
                } else { MetricNumber(value: "—", size: 32) }
            }
            if let memory = monitor.resources.memory {
                HStack(spacing: 16) {
                    smallValue(.appMemory, TrafficFormatter.total(memory.appBytes))
                    smallValue(.wiredMemory, TrafficFormatter.total(memory.wiredBytes))
                    smallValue(.compressedMemory, TrafficFormatter.total(memory.compressedBytes))
                }
                .help(l10n(.memoryHelp))
            }
            HardwareErrorLabel(error: monitor.resources.memoryError ?? monitor.resources.pressureError, localizer: l10n)
            history(monitor.resources.memoryHistory, color: HardwarePalette.memory, metric: .memory)
            if let swap = monitor.resources.swap {
                let samples = visible(monitor.resources.swapHistory)
                HStack {
                    Text(l10n(.swapUsed)).foregroundStyle(.secondary)
                    Text(TrafficFormatter.total(swap.usedBytes)).monospacedDigit()
                    Spacer()
                    Text(l10n(.swapChange, InsightStyle.delta(samples))).foregroundStyle(.secondary).monospacedDigit()
                }
                .font(.system(size: 11)).help(l10n(.swapHelp))
                HistoryChart(points: samples, maximum: max(1, samples.map(\.primary).max() ?? 1),
                             primaryColor: HardwarePalette.memory, durationSeconds: preferences.historySeconds,
                             endingAt: endingAt, inspectedTime: inspectedTime, onInspect: onInspect, showsGrid: false)
                    .frame(height: 34).accessibilityLabel(l10n(.swapTrend, l10n.duration(preferences.historySeconds)))
            }
            HardwareErrorLabel(error: monitor.resources.swapError, localizer: l10n)
            temperature(.memory)
            rankings(.memory)
        }
    }

    private var network: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 24) {
                speed(.download, value: monitor.networkError == nil ? monitor.rate.download : nil, color: HardwarePalette.download)
                speed(.upload, value: monitor.networkError == nil ? monitor.rate.upload : nil, color: HardwarePalette.upload)
            }
            HardwareErrorLabel(error: monitor.networkError, localizer: l10n)
            history(monitor.history, color: HardwarePalette.download, secondary: HardwarePalette.upload, metric: .network)
            Divider()
            fact(.interfaces, monitor.interfaces.isEmpty ? l10n(.noInterfaces) : monitor.interfaceDescription(using: l10n))
            fact(.sessionDownload, TrafficFormatter.total(monitor.totalReceived))
            fact(.sessionUpload, TrafficFormatter.total(monitor.totalSent))
            Text(l10n(.networkHelp)).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private var storage: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let capacity = monitor.storageCapacity {
                VStack(alignment: .leading, spacing: 6) {
                    Text(capacity.name).foregroundStyle(.secondary)
                    let available = TrafficFormatter.amount(capacity.availableBytes)
                    MetricNumber(value: available.value, unit: available.unit + " " + l10n(.availableShort), size: 32)
                    ProgressView(value: capacity.usedPercent, total: 100).tint(HardwarePalette.download)
                    fact(.usedTotal, TrafficFormatter.amount(capacity.usedBytes, unitFor: capacity.totalBytes).value
                         + " / " + TrafficFormatter.amount(capacity.totalBytes).text)
                }
                .help(l10n(.storageCapacityHelp))
            }
            temperature(.storage)
            HStack(spacing: 24) {
                speed(.read, value: monitor.resources.diskRate?.read, color: HardwarePalette.download)
                speed(.write, value: monitor.resources.diskRate?.write, color: HardwarePalette.memory)
            }
            HardwareErrorLabel(error: monitor.resources.diskError, localizer: l10n)
            history(monitor.resources.diskHistory, color: HardwarePalette.download, secondary: HardwarePalette.memory, metric: .disk)
            Divider()
            fact(.physicalDiskIO, monitor.resources.disks.isEmpty ? "—" : monitor.resources.disks.joined(separator: l10n(.listSeparator)))
            fact(.sessionRead, TrafficFormatter.total(monitor.resources.totalDiskRead))
            fact(.sessionWrite, TrafficFormatter.total(monitor.resources.totalDiskWritten))
            Text(l10n(.diskHelp)).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private var gpu: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(monitor.gpuUsage) { gpu in
                HStack {
                    Text(gpu.name).font(.system(size: 14, weight: .medium))
                    Spacer()
                    percent(gpu.utilizationPercent)
                }
                Divider()
            }
            temperature(.gpu)
            Text(l10n(.gpuUsageHelp)).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var battery: some View {
        if let battery = monitor.battery {
            VStack(alignment: .leading, spacing: 16) {
                if let charge = battery.chargePercent { percent(charge) }
                if let state = battery.powerState { fact(.batteryPowerState, l10n(state.titleKey)) }
                if let health = battery.healthPercent {
                    fact(.batteryHealthLabel, SystemFormatter.percent(health)).help(l10n(.batteryHealthHelp))
                }
                if let cycles = battery.cycleCount { fact(.batteryCyclesLabel, String(cycles)) }
                if let estimate = battery.timeEstimate {
                    fact(estimate.kind == .untilFull ? .batteryTimeUntilFullLabel : .batteryTimeUntilEmptyLabel,
                         String(estimate.minutes) + " " + l10n(.minutesUnit)).help(l10n(.batteryTimeHelp))
                }
                temperature(.battery)
            }
        }
    }

    private func rankings(_ metric: MonitorMetric) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text(l10n(metric == .cpu ? .topCPU : .topMemory)).font(.system(size: 13, weight: .semibold))
            RankingPane(monitor: monitor, preferences: preferences, metric: metric, showsMemorySummary: false)
        }
    }

    private func history(_ allPoints: [HistoryPoint], color: Color, secondary: Color? = nil, metric: MonitorMetric) -> some View {
        let points = visible(allPoints)
        let rates = metric == .disk || metric == .network
        let maximum = rates ? max(1_000, points.reduce(0) { max($0, $1.primary, $1.secondary) } * 1.15) : 100
        let summary = HistorySummary(points: points)
        let first: TextKey = metric == .network ? .download : metric == .disk ? .read : .utilization
        let second: TextKey = metric == .network ? .upload : .write
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(l10n(.historyHint, l10n.duration(preferences.historySeconds)))
                Spacer()
                Text(rates ? l10n(.chartLimit, TrafficFormatter.speed(maximum).text) : "0–100%")
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            HistoryChart(points: points, maximum: maximum, primaryColor: color, secondaryColor: secondary,
                         durationSeconds: preferences.historySeconds, endingAt: endingAt,
                         inspectedTime: inspectedTime, onInspect: onInspect)
                .frame(height: 118)
                .accessibilityLabel(rates ? l10n(metric == .network ? .networkChart : .diskChart, l10n.duration(preferences.historySeconds))
                                    : l10n(.usageChart, l10n(metric.titleKey), l10n.duration(preferences.historySeconds)))
            HStack {
                if let inspectedTime {
                    Text(l10n(.inspecting, InsightStyle.time(Date().addingTimeInterval(inspectedTime - ProcessInfo.processInfo.systemUptime), localizer: l10n)))
                } else {
                    Text(l10n(.secondsAgo, l10n.duration(preferences.historySeconds)))
                }
                Spacer()
                Text(l10n(.now))
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            if let inspectedTime {
                let sample = HistoryInspection.sample(allPoints, at: inspectedTime)
                fact(first, formatted(sample?.primary, rates: rates))
                if secondary != nil { fact(second, formatted(sample?.secondary, rates: rates)) }
            } else {
                statistics(first, average: summary.primaryAverage, peak: summary.primaryPeak, rates: rates, color: color)
                if let secondary { statistics(second, average: summary.secondaryAverage, peak: summary.secondaryPeak, rates: true, color: secondary) }
            }
        }
        .help(l10n(.statisticsHelp))
    }

    private func statistics(_ title: TextKey, average: Double?, peak: Double?, rates: Bool, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 4, height: 4)
            Text(l10n(title))
            Spacer(minLength: 4)
            Text(l10n(.averagePeak, formatted(average, rates: rates), formatted(peak, rates: rates)))
                .monospacedDigit()
        }
        .font(.system(size: 11)).foregroundStyle(.secondary)
    }

    private func formatted(_ value: Double?, rates: Bool) -> String {
        rates ? value.map { TrafficFormatter.speed($0).text } ?? "—" : SystemFormatter.percent(value)
    }

    private func visible(_ points: [HistoryPoint]) -> [HistoryPoint] {
        HistoryInspection.window(points, seconds: preferences.historySeconds, endingAt: endingAt)
    }

    private func fact(_ key: TextKey, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(l10n(key)).foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value).monospacedDigit().multilineTextAlignment(.trailing)
        }
        .font(.system(size: 11))
    }

    private func smallValue(_ key: TextKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(l10n(key)).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 13)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percent(_ value: Double?) -> some View {
        MetricNumber(value: value.map { String(format: "%.1f", $0) } ?? "—", unit: value == nil ? "" : "%", size: 32)
    }

    private func speed(_ key: TextKey, value: Double?, color: Color) -> some View {
        let amount = value.map(TrafficFormatter.speed)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(l10n(key)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            MetricNumber(value: amount?.value ?? "—", unit: amount?.unit ?? "", size: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func temperature(_ component: TemperatureComponent) -> some View {
        if let reading = monitor.temperatures.first(where: { $0.component == component }) {
            Label(String(format: "%.1f °C", reading.celsius), systemImage: "thermometer.medium")
                .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                .help(l10n(.temperatureHelp) + "\n" + reading.sensorIDs.joined(separator: ", "))
        }
    }
}
