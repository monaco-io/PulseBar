import AppKit
import SpeedCore
import SwiftUI

struct PopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var loginItem: LoginItemController
    @ObservedObject var presentation: PopoverPresentation
    @ObservedObject var eventNotifications: EventNotifications
    @ObservedObject var softwareUpdater: SoftwareUpdater
    @State private var inspectionTime: TimeInterval?
    @State private var inspectionEnd: TimeInterval?
    @State private var refreshDraft = ""
    @State private var historyDraft = ""
    @State private var resetFeedback = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var editingRefresh: Bool
    @FocusState private var editingHistory: Bool
    private var l10n: Localizer { preferences.localizer }
    private var route: PanelRoute { presentation.route }
    private var historyDuration: String { l10n.duration(preferences.historySeconds) }
    private var chartEnd: TimeInterval { inspectionEnd ?? monitor.timelineEnd }
    private let downloadColor = Color(nsColor: .systemBlue)
    private let uploadColor = Color(nsColor: .systemGreen)
    private let cpuColor = Color(nsColor: .systemOrange)
    private let memoryColor = Color(nsColor: .systemPurple)

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            monitorPanel.frame(width: presentation.overviewWidth, height: panelHeight)
            if route.hasDetails && !presentation.usesInlineDetails {
                Divider()
                detailPanel
                    .frame(width: PanelLayout.detailWidth, height: panelHeight)
                    .background(Color.primary.opacity(0.025))
                    .modifier(PanelReveal())
            }
        }
        .frame(width: presentation.contentSize.width, height: panelHeight, alignment: .leading)
        // Leading alignment keeps the overview stationary when the outer
        // window changes width. Intrinsic sizing must not recenter its contents.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
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
        .onChange(of: preferences.historySeconds) { historyDraft = HistoryWindow.hoursText(seconds: $0); inspect(nil) }
        .onChange(of: monitor.sessionStart) { _ in
            inspect(nil)
            resetFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { resetFeedback = false }
        }
        .onChange(of: route) { destination in
            editingRefresh = false
            editingHistory = false
            if destination == .settings { loginItem.refresh(); eventNotifications.refresh() }
        }
        .onChange(of: editingRefresh) { if !$0 { commitRefreshInterval() } }
        .onChange(of: editingHistory) { if !$0 { commitHistoryWindow() } }
    }

    private var monitorPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if route.hasDetails && presentation.usesInlineDetails {
                detailPanel.frame(maxHeight: .infinity)
            } else {
                overviewContent.frame(maxHeight: .infinity, alignment: .top)
            }
            navigationBar
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(.tint)
                Text(l10n(.appTitle)).font(.system(size: 16, weight: .semibold))
                Spacer(minLength: 4)
                Circle().fill(monitor.networkError != nil || monitor.resources.hasError ? Color.orange : uploadColor)
                    .frame(width: 5, height: 5)
                Text(monitor.networkError != nil || monitor.resources.hasError
                     ? l10n(.partialError) : l10n(.updatingEvery, preferences.refreshSeconds))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Menu {
                    Button(l10n(.checkForUpdates), action: softwareUpdater.checkForUpdates)
                        .disabled(!softwareUpdater.canPresentUpdate)
                    Link(l10n(.downloadAndReleaseNotes), destination: softwareUpdater.releasesURL)
                    Divider()
                    Button(l10n(.reset), action: monitor.reset).help(l10n(.resetHelp))
                    Divider()
                    Button(l10n(.quit)) { NSApp.terminate(nil) }.keyboardShortcut("q")
                } label: {
                    Image(systemName: "ellipsis.circle").font(.system(size: 16))
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel(l10n(.moreActions)).help(l10n(.moreActions))
            }
            Text(resetFeedback ? l10n(.resetDone) : inspectionTime.map {
                l10n(.inspecting, InsightStyle.time(Date().addingTimeInterval($0 - ProcessInfo.processInfo.systemUptime), localizer: l10n))
            } ?? l10n(.liveHistory, historyDuration))
                .font(.system(size: 10)).foregroundStyle(resetFeedback ? uploadColor : Color.secondary)
                .monospacedDigit().lineLimit(1)
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 14)
    }

    private var overviewContent: some View {
        #if DEBUG
        ScrollViewReader { proxy in
            hardwareContent.onReceive(NotificationCenter.default.publisher(for: Notification.Name("PulseBar.hardware-preview-scroll"))) { _ in
                proxy.scrollTo("hardware-content", anchor: .bottom)
            }
        }
        #else
        hardwareContent
        #endif
    }

    private var hardwareContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                hardwareColumns {
                    VStack(alignment: .leading, spacing: 14) {
                        cpuSection
                        if !monitor.gpuUsage.isEmpty || temperature(.gpu) != nil {
                            Divider()
                            gpuSection
                        }
                    }
                } right: {
                    VStack(alignment: .leading, spacing: 14) {
                        memorySection
                        if let battery = displayableBattery {
                            Divider()
                            hardwareSection(.battery, symbol: "battery.100", color: uploadColor, component: .battery) {
                                batteryContent(battery)
                            }
                        }
                    }
                }
                Divider()
                hardwareColumns { storageSection } right: { networkSection }
            }
            .padding(14)
            .id("hardware-content")
            .padding(.horizontal, 14).padding(.bottom, 12)
        }
        .scrollIndicators(.automatic)
    }

    @ViewBuilder private func hardwareColumns<Left: View, Right: View>(
        @ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right
    ) -> some View {
        if presentation.overviewWidth >= 500 {
            HStack(alignment: .top, spacing: 28) {
                left().frame(maxWidth: .infinity, alignment: .topLeading)
                right().frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .overlay {
                Rectangle().fill(Color.primary.opacity(0.09)).frame(width: 0.5)
                    .allowsHitTesting(false)
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                left()
                Divider()
                right()
            }
        }
    }

    private var cpuSection: some View {
        hardwareSection(.cpu, symbol: "cpu", color: cpuColor, component: .cpu, destination: .cpuApps) {
            HStack(alignment: .firstTextBaseline) {
                Button { presentation.navigate(.cpuApps) } label: { usageValue(monitor.resources.cpu?.usedPercent) }
                    .buttonStyle(.plain).help(l10n(.cpuHelp))
                Spacer(minLength: 4)
                Text(l10n(.logicalCores, ProcessInfo.processInfo.processorCount))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Text(cpuDetail).font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            usageChart(monitor.resources.cpuHistory, color: cpuColor, metric: .cpu)
            errorLabel(monitor.resources.cpuError)
        }
    }

    private var memorySection: some View {
        hardwareSection(.memory, symbol: "memorychip", color: memoryColor, component: .memory, destination: .memoryApps) {
            HStack(alignment: .firstTextBaseline) {
                Button { presentation.navigate(.memoryApps) } label: { usageValue(monitor.resources.memory?.usedPercent) }
                    .buttonStyle(.plain).help(memoryHelp)
                Spacer(minLength: 4)
                Text(memoryDetail).font(.system(size: 11)).monospacedDigit().help(memoryHelp)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let memory = monitor.resources.memory {
                HStack(alignment: .top, spacing: 8) {
                    memoryAmount(.appMemory, memory.appBytes)
                    memoryAmount(.wiredMemory, memory.wiredBytes)
                    memoryAmount(.compressedMemory, memory.compressedBytes)
                }
            }
            usageChart(monitor.resources.memoryHistory, color: memoryColor, metric: .memory)
            memoryHealthRow
            errorLabel(monitor.resources.memoryError)
        }
    }

    private var gpuSection: some View {
        hardwareSection(.gpu, symbol: "square.3.layers.3d", color: Color(nsColor: .systemTeal), component: .gpu) {
            ForEach(monitor.gpuUsage) { gpu in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(gpu.name).font(.system(size: 11)).lineLimit(2).help(gpu.name)
                    Spacer(minLength: 4)
                    Text(SystemFormatter.percent(gpu.utilizationPercent))
                        .font(.system(size: 20, weight: .medium, design: .rounded)).monospacedDigit()
                        .fixedSize()
                }
                .help(l10n(.gpuUsageHelp))
            }
        }
    }

    private var storageSection: some View {
        hardwareSection(.storage, symbol: "internaldrive", color: downloadColor, component: .storage) {
            if let capacity = monitor.storageCapacity {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(l10n(.startupVolumeSpace)).foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Text(SystemFormatter.percent(capacity.usedPercent)).monospacedDigit()
                    }
                    Text(l10n(.capacityRatio, TrafficFormatter.total(capacity.usedBytes), TrafficFormatter.total(capacity.totalBytes)))
                        .font(.system(size: 14, weight: .medium)).monospacedDigit()
                    Text(l10n(.availableSpace, TrafficFormatter.total(capacity.availableBytes)))
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                .font(.system(size: 11)).help(l10n(.storageCapacityHelp))
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(l10n(.physicalDiskIO)).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(monitor.resources.disks.joined(separator: l10n(.listSeparator)))
                    .lineLimit(1).truncationMode(.middle)
                    .help(monitor.resources.disks.joined(separator: l10n(.listSeparator)))
            }
            .font(.system(size: 11)).help(l10n(.diskHelp))
            HStack(alignment: .top, spacing: 12) {
                speedColumn(.read, symbol: "arrow.down", speed: monitor.resources.diskRate?.read, color: downloadColor)
                speedColumn(.write, symbol: "arrow.up", speed: monitor.resources.diskRate?.write, color: memoryColor)
            }
            rateChart(monitor.resources.diskHistory, primaryColor: downloadColor, secondaryColor: memoryColor,
                      label: l10n(.diskChart, historyDuration))
            totalsRow(.sessionIO, first: monitor.resources.totalDiskRead, second: monitor.resources.totalDiskWritten,
                      firstColor: downloadColor, secondColor: memoryColor)
            errorLabel(monitor.resources.diskError)
        }
    }

    private var networkSection: some View {
        hardwareSection(.network, symbol: "network", color: uploadColor) {
            HStack(alignment: .top, spacing: 12) {
                speedColumn(.download, symbol: "arrow.down", speed: monitor.networkError == nil ? monitor.rate.download : nil,
                            color: downloadColor)
                speedColumn(.upload, symbol: "arrow.up", speed: monitor.networkError == nil ? monitor.rate.upload : nil,
                            color: uploadColor)
            }
            rateChart(monitor.history, primaryColor: downloadColor, secondaryColor: uploadColor,
                      label: l10n(.networkChart, historyDuration), primaryTitle: .download, secondaryTitle: .upload)
            totalsRow(.sessionTraffic, first: monitor.totalReceived, second: monitor.totalSent,
                      firstColor: downloadColor, secondColor: uploadColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(l10n(.interfaces)).foregroundStyle(.secondary)
                Text(monitor.interfaces.isEmpty ? l10n(.noInterfaces) : monitor.interfaceDescription(using: l10n))
                    .lineLimit(2).help(monitor.interfaceDescription(using: l10n) + "\n" + l10n(.networkHelp))
            }
            .font(.system(size: 11))
            errorLabel(monitor.networkError)
        }
    }

    private func hardwareSection<Content: View>(_ title: TextKey, symbol: String, color: Color,
                                                component: TemperatureComponent? = nil, destination: PanelRoute? = nil,
                                                @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let destination {
                    Button { presentation.navigate(destination) } label: {
                        HStack(spacing: 6) {
                            Label(l10n(title), systemImage: symbol)
                            Image(systemName: "chevron.right").font(.system(size: 9))
                        }
                        .foregroundStyle(color).font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain).help(l10n(title == .cpu ? .topCPU : .topMemory))
                } else {
                    Label(l10n(title), systemImage: symbol)
                        .foregroundStyle(color).font(.system(size: 12, weight: .semibold))
                }
                Spacer(minLength: 8)
                if let component, let reading = temperature(component) {
                    Label(String(format: "%.1f °C", locale: Locale(identifier: "en_US_POSIX"), reading.celsius), systemImage: "thermometer.medium")
                        .font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
                        .help(l10n(.temperatureHelp) + "\n" + reading.sensorIDs.joined(separator: ", "))
                        .accessibilityLabel(l10n(.componentTemperature, l10n(title), reading.celsius))
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n(title))
    }

    private func temperature(_ component: TemperatureComponent) -> TemperatureReading? {
        monitor.temperatures.first { $0.component == component }
    }

    private func usageValue(_ value: Double?) -> some View {
        Text(SystemFormatter.percent(value))
            .font(.system(size: 22, weight: .medium, design: .rounded)).monospacedDigit()
            .contentTransition(.identity)
    }

    private func usageChart(_ points: [HistoryPoint], color: Color, metric: MonitorMetric) -> some View {
        VStack(spacing: 4) {
            HistoryChart(points: visible(points), maximum: 100, primaryColor: color,
                         durationSeconds: preferences.historySeconds, endingAt: chartEnd,
                         inspectedTime: inspectionTime, onInspect: inspect)
                .frame(height: 24)
                .accessibilityLabel(l10n(.usageChart, l10n(metric.titleKey), historyDuration))
            chartSummary(points, speed: false).help(l10n(.statisticsHelp))
        }
    }

    private func memoryAmount(_ title: TextKey, _ bytes: UInt64) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l10n(title)).foregroundStyle(.secondary)
            Text(TrafficFormatter.total(bytes)).monospacedDigit()
        }
        .font(.system(size: 11)).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayableBattery: BatterySnapshot? {
        guard let battery = monitor.battery,
              battery.chargePercent != nil || battery.powerState != nil || battery.healthPercent != nil ||
              battery.cycleCount != nil || battery.timeEstimate != nil || temperature(.battery) != nil else { return nil }
        return battery
    }

    private func batteryContent(_ battery: BatterySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if battery.chargePercent != nil || battery.powerState != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let charge = battery.chargePercent { usageValue(charge) }
                    Spacer()
                    if let state = battery.powerState {
                        Text(batteryState(state)).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }
            if battery.healthPercent != nil || battery.cycleCount != nil {
                HStack {
                    if let health = battery.healthPercent {
                        Text(l10n(.batteryHealth, SystemFormatter.percent(health))).help(l10n(.batteryHealthHelp))
                    }
                    Spacer()
                    if let cycles = battery.cycleCount { Text(l10n(.batteryCycles, cycles)) }
                }
                .font(.system(size: 11)).monospacedDigit()
            }
            if let estimate = battery.timeEstimate {
                Text(l10n(estimate.kind == .untilFull ? .batteryTimeUntilFull : .batteryTimeUntilEmpty, estimate.minutes))
                    .font(.system(size: 11)).foregroundStyle(.secondary).help(l10n(.batteryTimeHelp))
            }
        }
    }

    private func batteryState(_ state: BatteryPowerState) -> String {
        switch state {
        case .charging: return l10n(.batteryCharging)
        case .full: return l10n(.batteryFull)
        case .onBattery: return l10n(.batteryOnBattery)
        case .externalPower: return l10n(.batteryExternalPower)
        }
    }

    private var navigationBar: some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 16)
            HStack(spacing: 3) {
                navigationItem(.overview, title: .overview, symbol: "waveform.path.ecg", key: "1")
                navigationItem(route.isApps ? route : .cpuApps, title: .appRanking, symbol: "square.stack.3d.up", key: "2")
                navigationItem(.events, title: .events, symbol: "clock.arrow.circlepath", key: "3")
                navigationItem(.settings, title: .settings, symbol: "slider.horizontal.3", key: "4")
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
    }

    private func navigationItem(_ destination: PanelRoute, title: TextKey, symbol: String, key: KeyEquivalent) -> some View {
        let selected = route == destination
        return Button { presentation.navigate(destination) } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .medium))
                Text(l10n(title)).font(.system(size: 10, weight: selected ? .semibold : .medium))
                if destination == .events && !monitor.events.isEmpty {
                    Text(String(monitor.events.count)).font(.system(size: 8, weight: .semibold))
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                if destination == .settings && softwareUpdater.pendingVersion != nil {
                    Circle().fill(.blue).frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 18)
        }
        .buttonStyle(PanelButtonStyle(selected: selected, padding: 7))
        .keyboardShortcut(key, modifiers: .command)
        .accessibilityLabel(l10n(title))
        .accessibilityValue(selected ? l10n(.selectedTab) : "")
        .help(l10n(title))
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Label(l10n(route == .settings ? .settings : route == .events ? .events : .appRanking),
                      systemImage: route == .settings ? "slider.horizontal.3" : route == .events ? "clock.arrow.circlepath" : "square.stack.3d.up")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { presentation.navigate(.overview) } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(PanelButtonStyle(padding: 6))
                .accessibilityLabel(l10n(.closeDetail)).help(l10n(.closeDetail))
            }
            if route.isApps {
                Picker(l10n(.appRanking), selection: Binding(get: { route }, set: { presentation.navigate($0) })) {
                    Text(l10n(.cpu)).tag(PanelRoute.cpuApps)
                    Text(l10n(.memory)).tag(PanelRoute.memoryApps)
                }
                .pickerStyle(.segmented).labelsHidden()
            }
            ScrollView {
                ZStack(alignment: .topLeading) {
                    Group {
                    switch route {
                    case .settings: settingsContent
                    case .events: EventTimelineView(monitor: monitor, localizer: l10n)
                    case .cpuApps, .memoryApps:
                        RankingPane(monitor: monitor, preferences: preferences, metric: route == .cpuApps ? .cpu : .memory)
                    case .overview: EmptyView()
                    }
                    }
                    .id(route)
                    .transition(.opacity)
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: route)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 3)
            }
        }
        .font(.system(size: 11)).controlSize(.small)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            Divider().padding(.vertical, 5)
            Label(l10n(.samplingSection), systemImage: "waveform.path")
                .font(.system(size: 11, weight: .semibold))
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
            Divider().padding(.vertical, 5)
            Label(l10n(.behaviorSection), systemImage: "switch.2")
                .font(.system(size: 11, weight: .semibold))
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
            Divider()
            Toggle(l10n(.notifications), isOn: Binding(
                get: { preferences.notificationsEnabled },
                set: { eventNotifications.setEnabled($0, preferences: preferences) }
            ))
            .toggleStyle(.switch).controlSize(.mini).disabled(eventNotifications.requesting)
            .help(l10n(.notificationHelp))
            HStack {
                Text(l10n(.notificationCooldown)); Spacer()
                Text("\(preferences.notificationCooldownMinutes) \(l10n(.minutesUnit))").monospacedDigit()
                Stepper(l10n(.notificationCooldown), value: $preferences.notificationCooldownMinutes, in: 1...60)
                    .labelsHidden().fixedSize()
            }
            Text(l10n(.notificationHelp)).font(.system(size: 10)).foregroundStyle(.secondary)
            if eventNotifications.requesting { Text(l10n(.notificationPending)).font(.system(size: 10)) }
            if eventNotifications.denied {
                Text(l10n(.notificationDenied)).font(.system(size: 10)).foregroundStyle(.orange)
                Button(l10n(.openNotificationSettings), action: eventNotifications.openSettings).buttonStyle(.link)
            }
            if let error = eventNotifications.lastError {
                Text(l10n(.notificationFailed, error)).font(.system(size: 10)).foregroundStyle(.orange)
            }
            Divider().padding(.vertical, 5)
            SoftwareUpdateSettings(updater: softwareUpdater, localizer: l10n)
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

    private func speedColumn(_ title: TextKey, symbol: String, speed: Double?, color: Color) -> some View {
        let amount = speed.map { TrafficFormatter.speed($0) }
        return VStack(alignment: .leading, spacing: 3) {
            Label(l10n(title), systemImage: symbol).font(.system(size: 11, weight: .medium)).foregroundStyle(color)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(amount?.value ?? "—").font(.system(size: 20, weight: .medium, design: .rounded))
                        .monospacedDigit().contentTransition(.identity)
                    Text(amount?.unit ?? "").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .fixedSize()
                VStack(alignment: .leading, spacing: 1) {
                    Text(amount?.value ?? "—").font(.system(size: 20, weight: .medium, design: .rounded)).monospacedDigit()
                    Text(amount?.unit ?? "").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n(.speedLabel, l10n(title), amount?.text ?? l10n(.waiting)))
    }

    private func rateChart(_ allPoints: [HistoryPoint], primaryColor: Color, secondaryColor: Color,
                           label: String, primaryTitle: TextKey = .read, secondaryTitle: TextKey = .write) -> some View {
        let points = visible(allPoints)
        let maximum = max(1_000, points.reduce(0.0) { max($0, max($1.primary, $1.secondary)) } * 1.15)
        let summary = inspectionTime == nil ? HistorySummary(points: points) : nil
        return VStack(spacing: 3) {
            HStack {
                Text(l10n(.secondsAgo, historyDuration))
                Spacer(minLength: 4)
                Text(l10n(.chartLimit, TrafficFormatter.speed(maximum).text))
                Spacer(minLength: 4)
                Text(l10n(.now))
            }
            .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
            HistoryChart(points: points, maximum: maximum, primaryColor: primaryColor,
                         secondaryColor: secondaryColor, durationSeconds: preferences.historySeconds, endingAt: chartEnd,
                         inspectedTime: inspectionTime, onInspect: inspect)
                .frame(height: 28).accessibilityLabel(label)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(l10n(primaryTitle)).foregroundStyle(primaryColor).fixedSize()
                    chartSummary(allPoints, speed: true, summary: summary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(l10n(secondaryTitle)).foregroundStyle(secondaryColor).fixedSize()
                    chartSummary(allPoints, speed: true, secondary: true, summary: summary)
                }
            }
            .font(.system(size: 11)).help(l10n(.statisticsHelp))
        }
        .padding(.top, 2)
    }

    private func totalsRow(_ title: TextKey, first: UInt64, second: UInt64,
                           firstColor: Color, secondColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(l10n(title)).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label(TrafficFormatter.total(first), systemImage: "arrow.down").foregroundStyle(firstColor)
                Spacer(minLength: 4)
                Label(TrafficFormatter.total(second), systemImage: "arrow.up").foregroundStyle(secondColor)
            }
            .monospacedDigit()
        }
        .font(.system(size: 11))
    }

    private func visible(_ points: [HistoryPoint]) -> [HistoryPoint] {
        HistoryInspection.window(points, seconds: preferences.historySeconds, endingAt: chartEnd)
    }

    private func inspect(_ timestamp: TimeInterval?) {
        guard let timestamp else { inspectionTime = nil; inspectionEnd = nil; return }
        if inspectionEnd == nil { inspectionEnd = monitor.timelineEnd }
        let histories = [monitor.resources.cpuHistory, monitor.resources.memoryHistory, monitor.resources.diskHistory, monitor.history]
        let reference = histories.max(by: { $0.count < $1.count }) ?? []
        let candidate = HistoryInspection.nearestSample(reference, at: timestamp)?.timestamp ?? timestamp
        inspectionTime = candidate >= chartEnd - Double(preferences.historySeconds) && candidate <= chartEnd ? candidate : timestamp
    }

    private func chartSummary(_ points: [HistoryPoint], speed: Bool, secondary: Bool = false,
                              summary: HistorySummary? = nil) -> some View {
        let format: (Double?) -> String = { value in
            if speed { return value.map { TrafficFormatter.speed($0).text } ?? "—" }
            return SystemFormatter.percent(value)
        }
        let text: String
        if let inspectionTime {
            if let point = HistoryInspection.sample(points, at: inspectionTime) {
                text = "● " + format(secondary ? point.secondary : point.primary)
            } else { text = l10n(.noSample) }
        } else {
            let summary = summary ?? HistorySummary(points: visible(points))
            text = l10n(.averagePeak, format(secondary ? summary.secondaryAverage : summary.primaryAverage),
                        format(secondary ? summary.secondaryPeak : summary.primaryPeak))
        }
        return Text(text).font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var memoryHealthRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if monitor.resources.pressure != nil || monitor.resources.swap != nil {
                HStack(spacing: 5) {
                    if let pressure = monitor.resources.pressure {
                        Text(l10n(.memoryPressure)).foregroundStyle(.secondary)
                        Circle().fill(InsightStyle.pressureColor(pressure)).frame(width: 5, height: 5)
                        Text(l10n(pressure.titleKey)).foregroundStyle(InsightStyle.pressureColor(pressure))
                    }
                    Spacer(minLength: 6)
                    if let swap = monitor.resources.swap {
                        Text("Swap " + TrafficFormatter.total(swap.usedBytes)).monospacedDigit()
                    }
                }
                .help(l10n(.pressureHelp))
            }
            if monitor.resources.swap != nil, !visible(monitor.resources.swapHistory).isEmpty {
                Text(l10n(.swapChange, InsightStyle.delta(visible(monitor.resources.swapHistory))))
                    .foregroundStyle(.secondary).monospacedDigit().help(l10n(.swapHelp))
            }
            errorLabel(monitor.resources.pressureError)
            errorLabel(monitor.resources.swapError)
        }
        .font(.system(size: 11))
    }

    @ViewBuilder private func errorLabel(_ error: Error?) -> some View {
        if let message = l10n.describe(error) {
            Text(message).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6).help(message)
        }
    }
}
