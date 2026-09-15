import AppKit
import SpeedCore
import SwiftUI

enum InsightStyle {
    static func pressureColor(_ pressure: MemoryPressure?) -> Color {
        switch pressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        case nil: return .secondary
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
                        Text(app.name).font(.system(size: 11, weight: .medium)).lineLimit(1).truncationMode(.middle)
                            .help(app.name)
                        Text(localizer(.processCount, app.processCount)).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(metric == .cpu ? SystemFormatter.percent(app.cpuPercent) : TrafficFormatter.total(app.memoryBytes))
                            .font(.system(size: 12, weight: .medium)).monospacedDigit()
                        Text(metric == .cpu ? TrafficFormatter.total(app.memoryBytes) : "CPU " + SystemFormatter.percent(app.cpuPercent))
                            .font(.system(size: 9)).monospacedDigit().foregroundStyle(.secondary)
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
    @State private var activityMonitorFailed = false
    private var l10n: Localizer { preferences.localizer }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if metric == .memory {
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
            Button(l10n(.activityMonitor)) {
                guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") else {
                    activityMonitorFailed = true; return
                }
                NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
                    DispatchQueue.main.async { activityMonitorFailed = error != nil }
                }
            }
            .buttonStyle(.link)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizer(.eventRules)).font(.system(size: 10)).foregroundStyle(.secondary)
            if let error = monitor.eventStoreError {
                Text(localizer(.eventStoreFailed, error.localizedDescription)).font(.system(size: 10)).foregroundStyle(.orange)
            }
            if monitor.events.isEmpty {
                Text(localizer(.eventsEmpty)).font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 20)
            }
            ForEach(monitor.events) { event in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                            expandedID = expandedID == event.id ? nil : event.id
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: event.kind == .highCPU ? "cpu" : "memorychip")
                                .foregroundStyle(event.kind == .memoryCritical ? Color.red : .orange)
                                .frame(width: 18).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizer(event.kind.titleKey)).font(.system(size: 12, weight: .medium))
                                Text(InsightStyle.time(event.date, localizer: localizer, includesDate: true))
                                    .font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit()
                                Text(localizer(.eventDuration, localizer.duration(Int(event.duration))))
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 2)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                                .rotationEffect(.degrees(expandedID == event.id ? 90 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PanelButtonStyle(selected: expandedID == event.id, padding: 7))
                    .padding(-7)
                    if expandedID == event.id {
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
                        Text(localizer(.eventSnapshotHelp)).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                Divider()
            }
            Text(localizer(.eventsHelp)).font(.system(size: 10)).foregroundStyle(.secondary)
            if !monitor.events.isEmpty {
                Button(localizer(.clearEvents)) { confirmsClear = true }.buttonStyle(.link)
                    .confirmationDialog(localizer(.clearEvents), isPresented: $confirmsClear) {
                        Button(localizer(.clearEvents), role: .destructive, action: monitor.clearEvents)
                    }
            }
        }
    }
}
