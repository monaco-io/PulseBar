import AppKit
import SpeedCore
import SwiftUI

enum InsightStyle {
    // CPU colors describe utilization bands; memory uses the kernel's pressure level.
    static func cpuLoadColor(_ percent: Double?) -> Color {
        guard let percent, percent.isFinite else { return Color(nsColor: .disabledControlTextColor) }
        if percent > 80 { return Color(nsColor: .systemRed) }
        if percent >= 60 { return Color(nsColor: .systemYellow) }
        return Color(nsColor: .systemGreen)
    }

    static func pressureColor(_ pressure: MemoryPressure?) -> Color {
        switch pressure {
        case .normal: return Color(nsColor: .systemGreen)
        case .warning: return Color(nsColor: .systemYellow)
        case .critical: return Color(nsColor: .systemRed)
        case nil: return Color(nsColor: .disabledControlTextColor)
        }
    }

    static func time(_ date: Date, localizer: Localizer, includesDate: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = localizer.locale
        formatter.dateStyle = includesDate ? .short : .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    static func delta(_ points: [HistoryPoint]) -> String {
        guard points.count > 1, let first = points.first, let last = points.last else { return "—" }
        let amount = last.primary - first.primary
        return (amount > 0 ? "+" : amount < 0 ? "−" : "") + TrafficFormatter.total(UInt64(abs(amount)))
    }
}

/// Shared by live rankings and saved event snapshots. Cache native icons so
/// every metrics refresh does not ask Launch Services for the same artwork.
private enum AppIconCache {
    static let images: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 128
        return cache
    }()

    static func icon(for bundlePath: String?) -> NSImage? {
        guard let bundlePath else { return nil }
        let key = bundlePath as NSString
        if let cached = images.object(forKey: key) { return cached }
        guard FileManager.default.fileExists(atPath: bundlePath) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: bundlePath)
        images.setObject(icon, forKey: key)
        return icon
    }
}

private struct AppUsageIcon: View {
    let app: AppUsage

    var body: some View {
        Group {
            if let icon = AppIconCache.icon(for: app.bundlePath) {
                Image(nsImage: icon).renderingMode(.original).resizable().scaledToFit()
            } else {
                Image(systemName: app.bundlePath == nil ? "terminal" : "app")
                    .font(.system(size: 17)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 23, height: 23)
        .accessibilityHidden(true)
    }
}

struct AppRankingsView: View {
    let apps: [AppUsage]
    let metric: MonitorMetric
    let localizer: Localizer

    var body: some View {
        VStack(spacing: 0) {
            ForEach(apps) { app in
                HStack(spacing: 9) {
                    AppUsageIcon(app: app)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                            .help(app.name)
                        Text(localizer(.processCount, app.processCount)).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(metric == .cpu ? SystemFormatter.percent(app.cpuPercent) : TrafficFormatter.total(app.memoryBytes))
                            .font(.system(size: 12, weight: .medium)).monospacedDigit()
                        Text(metric == .cpu ? TrafficFormatter.total(app.memoryBytes) : "CPU " + SystemFormatter.percent(app.cpuPercent))
                            .font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 9)
                if app.id != apps.last?.id { Divider() }
            }
        }
    }
}

struct RankingPane: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var preferences: AppPreferences
    let metric: MonitorMetric
    var showsMemorySummary = true
    @State private var activityMonitorFailed = false
    private var l10n: Localizer { preferences.localizer }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if metric == .memory && showsMemorySummary {
                HStack {
                    Text(l10n(.memoryPressure))
                    Spacer()
                    Text(monitor.resources.pressure.map { l10n($0.titleKey) } ?? "—")
                        .foregroundStyle(InsightStyle.pressureColor(monitor.resources.pressure))
                }
                .help(l10n(.pressureHelp))
                HStack {
                    Text(l10n(.swap)); Spacer()
                    Text(monitor.resources.swap.map { TrafficFormatter.total($0.usedBytes) } ?? "—").monospacedDigit()
                }
                let points = HistoryInspection.window(monitor.resources.swapHistory, seconds: preferences.historySeconds,
                                                      endingAt: monitor.timelineEnd)
                Text(l10n(.swapChange, InsightStyle.delta(points))).font(.system(size: 10)).foregroundStyle(.secondary)
                HistoryChart(points: points, maximum: max(1, points.map(\.primary).max() ?? 1), primaryColor: .purple,
                             durationSeconds: preferences.historySeconds, endingAt: monitor.timelineEnd)
                    .frame(height: 45).accessibilityLabel(l10n(.swapTrend, l10n.duration(preferences.historySeconds)))
                Text(l10n(.swapHelp)).font(.system(size: 10)).foregroundStyle(.secondary)
                Divider()
            }
            if let error = monitor.processError {
                Text(l10n.describe(error) ?? l10n(.rankingUnavailable)).foregroundStyle(.orange)
            } else {
                let apps = metric == .cpu ? AppRanking.cpu(monitor.apps) : AppRanking.memory(monitor.apps)
                if apps.isEmpty { Text(l10n(.waiting)).foregroundStyle(.secondary) }
                else { AppRankingsView(apps: apps, metric: metric, localizer: l10n) }
            }
            if let date = monitor.rankingDate {
                Text(l10n(.rankingTime, InsightStyle.time(date, localizer: l10n)))
                    .font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit()
                Text(l10n(.rankingCoverage, monitor.processCount, monitor.skippedProcessCount))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Text(l10n(.rankingHelp)).font(.system(size: 10)).foregroundStyle(.secondary)
            NativeGlassButton(title: l10n(.activityMonitor), symbol: "arrow.up.forward.app") {
                guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") else {
                    activityMonitorFailed = true; return
                }
                NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
                    DispatchQueue.main.async { activityMonitorFailed = error != nil }
                }
            }
            .fixedSize()
            if activityMonitorFailed { Text(l10n(.activityMonitorFailed)).foregroundStyle(.orange) }
        }
        .font(.system(size: 11))
    }
}

struct EventTimelineView: View {
    @ObservedObject var monitor: SystemMonitor
    let localizer: Localizer
    @State private var expandedID: UUID?
    @State private var confirmsClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizer(.eventRules)).font(.system(size: 10)).foregroundStyle(.secondary)
            if let error = monitor.eventStoreError {
                Text(localizer(.eventStoreFailed, error.localizedDescription)).font(.system(size: 10)).foregroundStyle(.orange)
            }
            if monitor.events.isEmpty {
                Text(localizer(.eventsEmpty)).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).padding(.vertical, 20)
            }
            ForEach(monitor.events) { event in
                DisclosureGroup(isExpanded: Binding(
                    get: { expandedID == event.id },
                    set: { expandedID = $0 ? event.id : nil }
                )) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("CPU " + SystemFormatter.percent(event.cpuPercent))
                            Spacer()
                            Text("Swap " + (event.swapBytes.map(TrafficFormatter.total) ?? "—"))
                        }
                        .font(.system(size: 10)).monospacedDigit()
                        Text(localizer(.eventSnapshot)).font(.system(size: 11, weight: .semibold)).padding(.top, 4)
                        if event.rankingAvailable {
                            Text(localizer(.topCPU)).font(.system(size: 10)).foregroundStyle(.secondary)
                            if event.topCPU.isEmpty { Text(localizer(.rankingUnavailable)).font(.system(size: 10)) }
                            AppRankingsView(apps: event.topCPU, metric: .cpu, localizer: localizer)
                            Text(localizer(.topMemory)).font(.system(size: 10)).foregroundStyle(.secondary)
                            AppRankingsView(apps: event.topMemory, metric: .memory, localizer: localizer)
                        } else { Text(localizer(.rankingUnavailable)).font(.system(size: 10)).foregroundStyle(.secondary) }
                        Text(localizer(.eventSnapshotHelp)).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localizer(event.kind.titleKey)).font(.headline)
                            Text(InsightStyle.time(event.date, localizer: localizer, includesDate: true))
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            Text(localizer(.eventDuration, localizer.duration(Int(event.duration))))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: event.kind == .highCPU ? "cpu" : "memorychip")
                            .foregroundStyle(event.kind == .memoryCritical ? Color.red : .orange)
                    }
                }
                Divider()
            }
            Text(localizer(.eventsHelp)).font(.system(size: 10)).foregroundStyle(.secondary)
            if !monitor.events.isEmpty {
                NativeGlassButton(title: localizer(.clearEvents), symbol: "trash") { confirmsClear = true }
                    .fixedSize()
                    .confirmationDialog(localizer(.clearEvents), isPresented: $confirmsClear) {
                        Button(localizer(.clearEvents), role: .destructive, action: monitor.clearEvents)
                    }
            }
        }
    }
}
