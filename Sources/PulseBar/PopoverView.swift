import AppKit
import SpeedCore
import SwiftUI

struct PopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var loginItem: LoginItemController
    @ObservedObject var presentation: PopoverPresentation
    @State private var refreshDraft = ""
    @State private var historyDraft = ""
    @FocusState private var editingRefresh: Bool
    @FocusState private var editingHistory: Bool
    private var l10n: Localizer { preferences.localizer }
    private var showsSettings: Bool { presentation.showsSettings }
    private var historyDuration: String { l10n.duration(preferences.historySeconds) }
    private let downloadColor = Color(nsColor: .systemBlue)
    private let uploadColor = Color(nsColor: .systemGreen)
    private let cpuColor = Color(nsColor: .systemOrange)
    private let memoryColor = Color(nsColor: .systemPurple)

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            monitorPanel.frame(width: 400, height: panelHeight)
            if showsSettings {
                Divider()
                VStack(alignment: .leading, spacing: 18) {
                    Label(l10n(.settings), systemImage: "gearshape")
                        .font(.system(size: 14, weight: .semibold))
                    settingsContent
                    Spacer(minLength: 0)
                }
                .font(.system(size: 11)).controlSize(.small)
                .padding(20)
                .frame(width: 260, height: panelHeight, alignment: .top)
            }
        }
        .frame(width: presentation.contentSize.width, height: panelHeight)
        .environment(\.locale, l10n.locale)
        .onAppear {
            refreshDraft = String(preferences.refreshSeconds)
            historyDraft = HistoryWindow.hoursText(seconds: preferences.historySeconds)
            editingRefresh = false
            editingHistory = false
        }
        .onDisappear {
            editingRefresh = false
            editingHistory = false
        }
        .onChange(of: preferences.refreshSeconds) { refreshDraft = String($0) }
        .onChange(of: preferences.historySeconds) { historyDraft = HistoryWindow.hoursText(seconds: $0) }
        .onChange(of: editingRefresh) { if !$0 { commitRefreshInterval() } }
        .onChange(of: editingHistory) { if !$0 { commitHistoryWindow() } }
    }

    private var monitorPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 18, weight: .medium)).foregroundStyle(.secondary)
                    Text(l10n(.appTitle)).font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Circle().fill(monitor.networkError != nil || monitor.resources.hasError ? Color.orange : uploadColor)
                        .frame(width: 6, height: 6)
                    Text(monitor.networkError != nil || monitor.resources.hasError
                         ? l10n(.partialError) : l10n(.updatingEvery, preferences.refreshSeconds))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 10)

            Group {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 24) {
                        usageColumn(.cpu, symbol: "cpu", value: monitor.resources.cpu?.usedPercent,
                                    detail: cpuDetail, points: monitor.resources.cpuHistory, color: cpuColor,
                                    error: monitor.resources.cpuError, help: l10n(.cpuHelp))
                        usageColumn(.memory, symbol: "memorychip", value: monitor.resources.memory?.usedPercent,
                                    detail: memoryDetail, points: monitor.resources.memoryHistory, color: memoryColor,
                                    error: monitor.resources.memoryError, help: memoryHelp)
                    }
                    .padding(.bottom, 10)
                    Divider()

                    HStack {
                        Label(l10n(.diskIO), systemImage: "internaldrive").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(monitor.resources.disks.isEmpty ? "—" : monitor.resources.disks.joined(separator: l10n(.listSeparator)))
                            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            .help(l10n(.diskHelp))
                    }
                    .padding(.top, 10).padding(.bottom, 6)
                    HStack(spacing: 24) {
                        speedColumn(.read, symbol: "arrow.down", speed: monitor.resources.diskRate?.read, color: downloadColor)
                        speedColumn(.write, symbol: "arrow.up", speed: monitor.resources.diskRate?.write, color: memoryColor)
                    }
                    rateChart(monitor.resources.diskHistory, primaryColor: downloadColor, secondaryColor: memoryColor,
                              label: l10n(.diskChart, historyDuration))
                    totalsRow(.sessionIO, first: monitor.resources.totalDiskRead, second: monitor.resources.totalDiskWritten,
                              firstColor: downloadColor, secondColor: memoryColor)
                        .padding(.top, 6)
                    errorLabel(monitor.resources.diskError)
                    Divider().padding(.top, 10)

                    HStack {
                        Label(l10n(.network), systemImage: "network").font(.system(size: 12, weight: .semibold))
                        Spacer()
                    }
                    .padding(.top, 10).padding(.bottom, 6)
                    HStack(spacing: 24) {
                        speedColumn(.download, symbol: "arrow.down", speed: monitor.networkError == nil ? monitor.rate.download : nil,
                                    color: downloadColor)
                        speedColumn(.upload, symbol: "arrow.up", speed: monitor.networkError == nil ? monitor.rate.upload : nil,
                                    color: uploadColor)
                    }
                    rateChart(monitor.history, primaryColor: downloadColor, secondaryColor: uploadColor,
                              label: l10n(.networkChart, historyDuration))
                    totalsRow(.sessionTraffic, first: monitor.totalReceived, second: monitor.totalSent,
                              firstColor: downloadColor, secondColor: uploadColor)
                        .padding(.top, 6)
                    HStack(alignment: .top) {
                        Text(l10n(.interfaces)).foregroundStyle(.secondary)
                        Spacer(minLength: 16)
                        Text(monitor.interfaces.isEmpty ? l10n(.noInterfaces) : monitor.interfaceDescription(using: l10n))
                            .multilineTextAlignment(.trailing).lineLimit(2).help(l10n(.networkHelp))
                    }
                    .font(.system(size: 10)).padding(.top, 6)
                    errorLabel(monitor.networkError)
                }
                .padding(.horizontal, 20).padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Divider().padding(.horizontal, 20)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Button {
                        editingRefresh = false
                        editingHistory = false
                        presentation.showsSettings.toggle()
                        if showsSettings { loginItem.refresh() }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: showsSettings ? "chevron.left" : "chevron.right")
                                .font(.system(size: 8, weight: .semibold)).frame(width: 8)
                            Label(l10n(.settings), systemImage: "gearshape")
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel(l10n(.settings))
                    .accessibilityValue(l10n(showsSettings ? .settingsExpanded : .settingsCollapsed))
                    Spacer()
                    Button(l10n(.reset), action: monitor.reset).help(l10n(.resetHelp))
                    Button(l10n(.quit)) { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 11)).controlSize(.small)
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 12)
        }
    }

    private var panelHeight: CGFloat {
        presentation.height
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n(.menuBarItems)).foregroundStyle(.secondary)
                HStack(spacing: 24) {
                    settingsMetric(.cpu)
                    settingsMetric(.memory)
                }
                HStack(spacing: 24) {
                    settingsMetric(.disk)
                    settingsMetric(.network)
                }
                if preferences.selection.metrics.count == 1 {
                    Text(l10n(.atLeastOne)).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                Text(l10n(.language))
                Spacer()
                Picker(l10n(.language), selection: $preferences.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.label(using: l10n)).tag(language)
                    }
                }
                .labelsHidden().pickerStyle(.menu).frame(width: 132)
                .accessibilityLabel(l10n(.language))
            }
            HStack(spacing: 4) {
                Text(l10n(.refresh))
                Spacer()
                TextField(l10n(.refresh), text: $refreshDraft)
                    .textFieldStyle(.roundedBorder).frame(width: 64).multilineTextAlignment(.trailing)
                    .focused($editingRefresh)
                    .onSubmit {
                        commitRefreshInterval()
                        editingRefresh = false
                    }
                    .accessibilityLabel(l10n(.refresh))
                Text(l10n(.secondsUnit)).foregroundStyle(.secondary).frame(minWidth: 24, alignment: .leading)
                Stepper(l10n(.refresh), value: refreshBinding, in: RefreshInterval.range)
                    .labelsHidden().fixedSize().accessibilityLabel(l10n(.refresh))
            }
            .help(l10n(.refreshHelp))
            HStack(spacing: 4) {
                Text(l10n(.historyWindow))
                Spacer()
                TextField(l10n(.historyWindow), text: $historyDraft)
                    .textFieldStyle(.roundedBorder).frame(width: 64).multilineTextAlignment(.trailing)
                    .focused($editingHistory)
                    .onSubmit {
                        commitHistoryWindow()
                        editingHistory = false
                    }
                    .accessibilityLabel(l10n(.historyWindow))
                Text(l10n(.hoursUnit)).foregroundStyle(.secondary).frame(minWidth: 24, alignment: .leading)
                Stepper(l10n(.historyWindow), value: historyBinding, in: HistoryWindow.hourRange, step: 0.5)
                    .labelsHidden().fixedSize().accessibilityLabel(l10n(.historyWindow))
            }
            .help(l10n(.historyHelp))
            Divider()
            HStack {
                Text(l10n(.launchAtLogin))
                Spacer()
                Toggle(l10n(.launchAtLogin), isOn: Binding(
                    get: { loginItem.isRegistered }, set: { loginItem.setEnabled($0) }
                ))
                .toggleStyle(.switch).labelsHidden().controlSize(.mini)
                .accessibilityLabel(l10n(.launchAtLogin))
            }
            .help(l10n(.launchAtLoginHelp))
            if loginItem.needsApproval {
                Text(l10n(.loginApprovalRequired)).font(.system(size: 10)).foregroundStyle(.orange)
                Button(l10n(.openLoginSettings), action: loginItem.openSystemSettings)
                    .buttonStyle(.link)
            }
            if let error = loginItem.lastError {
                Text(l10n(.loginItemFailed, error)).font(.system(size: 10)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingsMetric(_ metric: MonitorMetric) -> some View {
        HStack {
            Text(l10n(metric.titleKey))
            Spacer()
            visibilityToggle(metric)
        }
        .frame(maxWidth: .infinity)
    }

    private var refreshBinding: Binding<Int> {
        Binding(get: { preferences.refreshSeconds }, set: { preferences.setRefreshSeconds($0) })
    }

    private var historyBinding: Binding<Double> {
        Binding(get: { Double(preferences.historySeconds) / 3600 }, set: { hours in
            if let seconds = HistoryWindow.seconds(hours: hours) { preferences.setHistorySeconds(seconds) }
        })
    }

    private func commitRefreshInterval() {
        if let seconds = Int(refreshDraft.trimmingCharacters(in: .whitespacesAndNewlines)) {
            preferences.setRefreshSeconds(seconds)
        }
        refreshDraft = String(preferences.refreshSeconds)
    }

    private func commitHistoryWindow() {
        if let hours = Double(historyDraft.trimmingCharacters(in: .whitespacesAndNewlines)),
           let seconds = HistoryWindow.seconds(hours: hours) {
            preferences.setHistorySeconds(seconds)
        }
        historyDraft = HistoryWindow.hoursText(seconds: preferences.historySeconds)
    }

    private func visibilityToggle(_ metric: MonitorMetric) -> some View {
        Toggle(l10n(.showInMenuBar, l10n(metric.titleKey)), isOn: Binding(
            get: { preferences.selection.contains(metric) },
            set: { preferences.setVisible(metric, $0) }
        ))
        .toggleStyle(.switch).labelsHidden().controlSize(.mini)
        .disabled(!preferences.selection.canToggle(metric))
        .help(preferences.selection.canToggle(metric) ? l10n(.showInMenuBar, l10n(metric.titleKey)) : l10n(.atLeastOne))
        .accessibilityLabel(l10n(.showInMenuBar, l10n(metric.titleKey)))
    }

    private var cpuDetail: String {
        guard let cpu = monitor.resources.cpu else { return l10n(.waiting) }
        return l10n(.userSystem, SystemFormatter.percent(cpu.userPercent), SystemFormatter.percent(cpu.systemPercent))
    }

    private var memoryDetail: String {
        guard let memory = monitor.resources.memory else { return l10n(.waiting) }
        let used = TrafficFormatter.amount(memory.usedBytes, unitFor: memory.totalBytes)
        let total = TrafficFormatter.amount(memory.totalBytes)
        return l10n(.memoryRatio, used.value, total.value, total.unit)
    }

    private var memoryHelp: String {
        guard let memory = monitor.resources.memory else { return l10n(.memoryHelp) }
        return l10n(.memoryHelp) + "\n" + l10n(.memoryBreakdown, SystemFormatter.memory(memory.appBytes),
                                             SystemFormatter.memory(memory.wiredBytes), SystemFormatter.memory(memory.compressedBytes))
    }

    private func usageColumn(_ metric: MonitorMetric, symbol: String, value: Double?, detail: String,
                             points: [HistoryPoint], color: Color, error: Error?, help: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(l10n(metric.titleKey), systemImage: symbol)
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(color).help(help)
                Spacer(minLength: 4)
            }
            Text(SystemFormatter.percent(value)).font(.system(size: 25, weight: .medium, design: .rounded))
                .monospacedDigit().contentTransition(.identity).help(help)
                .accessibilityLabel(l10n(.usageLabel, l10n(metric.titleKey), SystemFormatter.percent(value)))
            Text(error == nil ? detail : l10n(.retrying))
                .font(.system(size: 10)).foregroundStyle(error == nil ? Color.secondary : .orange)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8).help(l10n.describe(error) ?? help)
            HistoryChart(points: HistoryWindow.visiblePoints(points, seconds: preferences.historySeconds),
                         maximum: 100, primaryColor: color, durationSeconds: preferences.historySeconds)
                .frame(height: 24).padding(.top, 3)
                .accessibilityLabel(l10n(.usageChart, l10n(metric.titleKey), historyDuration))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func speedColumn(_ title: TextKey, symbol: String, speed: Double?, color: Color) -> some View {
        let amount = speed.map { TrafficFormatter.speed($0) }
        return VStack(alignment: .leading, spacing: 4) {
            Label(l10n(title), systemImage: symbol).font(.system(size: 11, weight: .medium)).foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(amount?.value ?? "—").font(.system(size: 24, weight: .medium, design: .rounded))
                    .monospacedDigit().contentTransition(.identity)
                Text(amount?.unit ?? "").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n(.speedLabel, l10n(title), amount?.text ?? l10n(.waiting)))
    }

    private func rateChart(_ allPoints: [HistoryPoint], primaryColor: Color, secondaryColor: Color,
                           label: String) -> some View {
        let points = HistoryWindow.visiblePoints(allPoints, seconds: preferences.historySeconds)
        let maximum = max(1_000, points.reduce(0.0) { max($0, max($1.primary, $1.secondary)) } * 1.15)
        return VStack(spacing: 4) {
            HStack {
                Text(l10n(.secondsAgo, historyDuration))
                Spacer()
                Text(l10n(.chartLimit, TrafficFormatter.speed(maximum).text))
                Spacer()
                Text(l10n(.now))
            }
            .font(.system(size: 9)).foregroundStyle(.secondary).monospacedDigit()
            HistoryChart(points: points, maximum: maximum, primaryColor: primaryColor,
                         secondaryColor: secondaryColor, durationSeconds: preferences.historySeconds)
                .frame(height: 36).accessibilityLabel(label)
        }
        .padding(.top, 6)
    }

    private func totalsRow(_ title: TextKey, first: UInt64, second: UInt64,
                           firstColor: Color, secondColor: Color) -> some View {
        HStack {
            Text(l10n(title)).foregroundStyle(.secondary)
            Spacer()
            Label(TrafficFormatter.total(first), systemImage: "arrow.down").foregroundStyle(firstColor)
            Label(TrafficFormatter.total(second), systemImage: "arrow.up").foregroundStyle(secondColor)
        }
        .font(.system(size: 10)).monospacedDigit()
    }

    @ViewBuilder private func errorLabel(_ error: Error?) -> some View {
        if let message = l10n.describe(error) {
            Text(message).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6).help(message)
        }
    }
}

private struct HistoryChart: View {
    let points: [HistoryPoint]
    let maximum: Double
    let primaryColor: Color
    var secondaryColor: Color?
    let durationSeconds: Int

    var body: some View {
        Canvas { context, size in
            context.clip(to: Path(CGRect(origin: .zero, size: size)))
            for fraction in [0.0, 0.5, 1.0] {
                var grid = Path()
                let y = 1 + (size.height - 2) * fraction
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(grid, with: .color(.secondary.opacity(0.16)),
                               style: StrokeStyle(lineWidth: 0.5, dash: fraction == 1 ? [] : [3, 4]))
            }
            guard points.count > 1, let now = points.last?.timestamp else { return }
            let plotted = HistoryWindow.plotPoints(points, maximumCount: max(6, Int(size.width * 2)))
            for isPrimary in [true, false] {
                guard let color = isPrimary ? primaryColor : secondaryColor else { continue }
                let positions = plotted.map { point in
                    CGPoint(x: (point.timestamp - now + Double(durationSeconds)) / Double(durationSeconds) * size.width,
                            y: size.height - 1 - min(1, max(0, (isPrimary ? point.primary : point.secondary) / maximum)) * (size.height - 2))
                }
                var line = Path()
                line.addLines(positions)
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
    }
}
