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
            Divider()
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
                    .font(.system(size: 22, weight: .semibold)).foregroundStyle(.tint)
                Text(l10n(.appTitle)).font(.system(size: 20, weight: .semibold))
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
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 14)
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
            VStack(alignment: .leading, spacing: 16) {
                hardwarePair {
                    cpuSection
                } right: {
                    memorySection
                } leftHistory: {
                    usageChart(monitor.resources.cpuHistory, color: cpuColor, metric: .cpu)
                } rightHistory: {
                    usageChart(monitor.resources.memoryHistory, color: memoryColor, metric: .memory)
                }
                Divider()
                hardwarePair {
                    storageSection
                } right: {
                    networkSection
                } leftHistory: {
                    VStack(spacing: 12) {
                        rateChart(monitor.resources.diskHistory, primaryColor: downloadColor, secondaryColor: memoryColor,
                                  label: l10n(.diskChart, historyDuration))
                        totalsRow(.sessionRead, .sessionWrite, first: monitor.resources.totalDiskRead,
                                  second: monitor.resources.totalDiskWritten)
                    }
                } rightHistory: {
                    VStack(spacing: 12) {
                        rateChart(monitor.history, primaryColor: downloadColor, secondaryColor: uploadColor,
                                  label: l10n(.networkChart, historyDuration), primaryTitle: .download, secondaryTitle: .upload)
                        totalsRow(.sessionDownload, .sessionUpload, first: monitor.totalReceived, second: monitor.totalSent)
                    }
                }
                if hasGPU || displayableBattery != nil {
                    Divider()
                    if hasGPU, let battery = displayableBattery {
                        hardwareColumns { gpuSection } right: { batterySection(battery) }
                    } else if hasGPU {
                        gpuSection
                    } else if let battery = displayableBattery {
                        batterySection(battery)
                    }
                }
            }
            .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 18)
            .id("hardware-content")
        }
        .scrollIndicators(.automatic)
    }

    /// Separate Grid rows let the taller module set the shared history baseline.
    /// A narrow panel keeps each module and its history together in reading order.
    @ViewBuilder private func hardwarePair<Left: View, Right: View, LeftHistory: View, RightHistory: View>(
        @ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right,
        @ViewBuilder leftHistory: () -> LeftHistory, @ViewBuilder rightHistory: () -> RightHistory
    ) -> some View {
        if presentation.overviewWidth >= 500 {
            Grid(alignment: .topLeading, horizontalSpacing: 28, verticalSpacing: 12) {
                GridRow {
                    left().frame(maxWidth: .infinity, alignment: .topLeading)
                    right().frame(maxWidth: .infinity, alignment: .topLeading)
                }
                GridRow {
                    leftHistory().frame(maxWidth: .infinity, alignment: .topLeading)
                    rightHistory().frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                left()
                leftHistory()
                Divider().padding(.vertical, 4)
                right()
                rightHistory()
            }
        }
    }

    @ViewBuilder private func hardwareColumns<Left: View, Right: View>(
        @ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right
    ) -> some View {
        if presentation.overviewWidth >= 500 {
            HStack(alignment: .top, spacing: 28) {
                left().frame(maxWidth: .infinity, alignment: .topLeading)
                right().frame(maxWidth: .infinity, alignment: .topLeading)
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                left()
                Divider()
                right()
            }
        }
    }

    private var cpuSection: some View {
        hardwareSection(.cpu, symbol: "cpu", component: .cpu, destination: .cpuApps) {
            primaryMetric(l10n(.utilization), value: monitor.resources.cpu?.usedPercent, destination: .cpuApps)
                .help(l10n(.cpuHelp))
            metricRow(l10n(.logicalCoresLabel), value: String(ProcessInfo.processInfo.processorCount))
            HStack(alignment: .top, spacing: 12) {
                compositionValue(l10n(.cpuUser), value: SystemFormatter.percent(monitor.resources.cpu?.userPercent))
                compositionValue(l10n(.cpuSystem), value: SystemFormatter.percent(monitor.resources.cpu?.systemPercent))
            }
            errorLabel(monitor.resources.cpuError)
        }
    }

    private var memorySection: some View {
        hardwareSection(.memory, symbol: "memorychip", component: .memory, destination: .memoryApps) {
            primaryMetric(l10n(.utilization), value: monitor.resources.memory?.usedPercent, destination: .memoryApps)
                .help(memoryHelp)
            metricRow(l10n(.usedTotal), value: memoryDetail).help(memoryHelp)
            if let memory = monitor.resources.memory {
                HStack(alignment: .top, spacing: 12) {
                    compositionValue(l10n(.appMemory), value: TrafficFormatter.total(memory.appBytes))
                    compositionValue(l10n(.wiredMemory), value: TrafficFormatter.total(memory.wiredBytes))
                    compositionValue(l10n(.compressedMemory), value: TrafficFormatter.total(memory.compressedBytes))
                }
            }
            memoryHealthRow
            errorLabel(monitor.resources.memoryError)
        }
    }

    private var hasGPU: Bool { !monitor.gpuUsage.isEmpty || temperature(.gpu) != nil }

    private var gpuSection: some View {
        hardwareSection(.gpu, symbol: "square.3.layers.3d", component: .gpu) {
            ForEach(monitor.gpuUsage) { gpu in
                primaryMetric(gpu.name, value: gpu.utilizationPercent)
                    .help(gpu.name + "\n" + l10n(.gpuUsageHelp))
            }
        }
    }

    private var storageSection: some View {
        hardwareSection(.storage, symbol: "internaldrive", component: .storage) {
            if let capacity = monitor.storageCapacity {
                primaryMetric(l10n(.startupVolumeUsed), value: capacity.usedPercent)
                metricRow(l10n(.usedTotal), value: capacityRatio(used: capacity.usedBytes, total: capacity.totalBytes))
                metricRow(l10n(.availableSpaceLabel), value: TrafficFormatter.total(capacity.availableBytes))
                    .help(l10n(.storageCapacityHelp))
            }
            metricRow(l10n(.physicalDiskIO),
                      value: monitor.resources.disks.isEmpty ? "—" : monitor.resources.disks.joined(separator: l10n(.listSeparator)))
                .help(l10n(.diskHelp))
            HStack(alignment: .top, spacing: 12) {
                speedColumn(.read, symbol: "arrow.down", speed: monitor.resources.diskRate?.read, color: downloadColor)
                speedColumn(.write, symbol: "arrow.up", speed: monitor.resources.diskRate?.write, color: memoryColor)
            }
            errorLabel(monitor.resources.diskError)
        }
    }

    private var networkSection: some View {
        hardwareSection(.network, symbol: "network") {
            HStack(alignment: .top, spacing: 12) {
                speedColumn(.download, symbol: "arrow.down", speed: monitor.networkError == nil ? monitor.rate.download : nil,
                            color: downloadColor)
                speedColumn(.upload, symbol: "arrow.up", speed: monitor.networkError == nil ? monitor.rate.upload : nil,
                            color: uploadColor)
            }
            metricRow(l10n(.interfaces), value: monitor.interfaces.isEmpty ? l10n(.noInterfaces) : monitor.interfaceDescription(using: l10n))
                .help(monitor.interfaceDescription(using: l10n) + "\n" + l10n(.networkHelp))
            errorLabel(monitor.networkError)
        }
    }

    private func hardwareSection<Content: View>(_ title: TextKey, symbol: String,
                                                component: TemperatureComponent? = nil, destination: PanelRoute? = nil,
                                                @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let destination {
                    Button { presentation.navigate(destination) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: symbol).foregroundStyle(.secondary)
                            Text(l10n(title))
                            Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary).font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain).help(l10n(title == .cpu ? .topCPU : .topMemory))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: symbol).foregroundStyle(.secondary)
                        Text(l10n(title))
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                Spacer(minLength: 8)
                if let component, let reading = temperature(component) {
                    Label(String(format: "%.1f °C", locale: Locale(identifier: "en_US_POSIX"), reading.celsius), systemImage: "thermometer.medium")
                        .font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary).fixedSize()
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

    private func primaryMetric(_ title: String, value: Double?, destination: PanelRoute? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let destination {
                Button { presentation.navigate(destination) } label: { usageValue(value) }
                    .buttonStyle(.plain)
            } else {
                usageValue(value)
            }
        }
    }

    private func usageValue(_ value: Double?) -> some View {
        let percent = SystemFormatter.percent(value)
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(percent.hasSuffix("%") ? String(percent.dropLast()) : percent)
                .font(.system(size: 28, weight: .medium)).monospacedDigit().contentTransition(.identity)
            if percent.hasSuffix("%") {
                Text("%").font(.system(size: 14)).foregroundStyle(.secondary)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(percent)
    }

    private func metricRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true).layoutPriority(1)
            Spacer(minLength: 4)
            Text(value).monospacedDigit().multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11))
    }

    private func compositionValue(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(value).font(.system(size: 13)).monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func usageChart(_ points: [HistoryPoint], color: Color, metric: MonitorMetric) -> some View {
        VStack(spacing: 5) {
            chartAxis()
            HistoryChart(points: visible(points), maximum: 100, primaryColor: color,
                         durationSeconds: preferences.historySeconds, endingAt: chartEnd,
                         inspectedTime: inspectionTime, onInspect: inspect)
                .frame(height: 28)
                .accessibilityLabel(l10n(.usageChart, l10n(metric.titleKey), historyDuration))
            chartSummary(points, speed: false).help(l10n(.statisticsHelp))
        }
    }

    private var displayableBattery: BatterySnapshot? {
        guard let battery = monitor.battery,
              battery.chargePercent != nil || battery.powerState != nil || battery.healthPercent != nil ||
              battery.cycleCount != nil || battery.timeEstimate != nil || temperature(.battery) != nil else { return nil }
        return battery
    }

    private func batterySection(_ battery: BatterySnapshot) -> some View {
        hardwareSection(.battery, symbol: "battery.100", component: .battery) {
            batteryContent(battery)
        }
    }

    private func batteryContent(_ battery: BatterySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let charge = battery.chargePercent {
                primaryMetric(l10n(.batteryCharge), value: charge)
            }
            if let state = battery.powerState {
                metricRow(l10n(.batteryPowerState), value: batteryState(state))
            }
            if let health = battery.healthPercent {
                metricRow(l10n(.batteryHealthLabel), value: SystemFormatter.percent(health)).help(l10n(.batteryHealthHelp))
            }
            if let cycles = battery.cycleCount {
                metricRow(l10n(.batteryCyclesLabel), value: String(cycles))
            }
            if let estimate = battery.timeEstimate {
                metricRow(l10n(estimate.kind == .untilFull ? .batteryTimeUntilFullLabel : .batteryTimeUntilEmptyLabel),
                          value: String(estimate.minutes) + " " + l10n(.minutesUnit))
                    .help(l10n(.batteryTimeHelp))
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

    private var memoryDetail: String {
        guard let memory = monitor.resources.memory else { return l10n(.waiting) }
        return capacityRatio(used: memory.usedBytes, total: memory.totalBytes)
    }

    private func capacityRatio(used: UInt64, total: UInt64) -> String {
        let usedAmount = TrafficFormatter.amount(used, unitFor: total)
        let totalAmount = TrafficFormatter.amount(total)
        return l10n(.memoryRatio, usedAmount.value, totalAmount.value, totalAmount.unit)
    }

    private var memoryHelp: String {
        guard let memory = monitor.resources.memory else { return l10n(.memoryHelp) }
        return l10n(.memoryHelp) + "\n" + l10n(.memoryBreakdown, SystemFormatter.memory(memory.appBytes),
                                             SystemFormatter.memory(memory.wiredBytes), SystemFormatter.memory(memory.compressedBytes))
    }

    private func speedColumn(_ title: TextKey, symbol: String, speed: Double?, color: Color) -> some View {
        let amount = speed.map { TrafficFormatter.speed($0) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol).foregroundStyle(color)
                Text(l10n(title)).foregroundStyle(.secondary)
            }
            .font(.system(size: 11))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Spacer(minLength: 0)
                Text(amount?.value ?? "—").font(.system(size: 24, weight: .medium))
                    .monospacedDigit().contentTransition(.identity)
                Text(amount?.unit ?? "").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n(.speedLabel, l10n(title), amount?.text ?? l10n(.waiting)))
    }

    private func chartAxis(limit: String? = nil) -> some View {
        HStack(spacing: 4) {
            Text(l10n(.secondsAgo, historyDuration))
            Spacer(minLength: 0)
            if let limit {
                Text(l10n(.chartLimit, limit)).monospacedDigit()
                Spacer(minLength: 0)
            }
            Text(l10n(.now))
        }
        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
    }

    private func rateChart(_ allPoints: [HistoryPoint], primaryColor: Color, secondaryColor: Color,
                           label: String, primaryTitle: TextKey = .read, secondaryTitle: TextKey = .write) -> some View {
        let points = visible(allPoints)
        let maximum = max(1_000, points.reduce(0.0) { max($0, max($1.primary, $1.secondary)) } * 1.15)
        let summary = HistorySummary(points: points)
        return VStack(spacing: 5) {
            chartAxis(limit: TrafficFormatter.speed(maximum).text)
            HistoryChart(points: points, maximum: maximum, primaryColor: primaryColor,
                         secondaryColor: secondaryColor, durationSeconds: preferences.historySeconds, endingAt: chartEnd,
                         inspectedTime: inspectionTime, onInspect: inspect)
                .frame(height: 28).accessibilityLabel(label)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                if let inspectionTime {
                    GridRow {
                        Text(l10n(.direction))
                        Text(l10n(.inspecting, inspectionLabel(inspectionTime)))
                            .gridCellColumns(2).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .foregroundStyle(.secondary)
                    inspectionRateRow(primaryTitle, point: HistoryInspection.sample(allPoints, at: inspectionTime), secondary: false)
                    inspectionRateRow(secondaryTitle, point: HistoryInspection.sample(allPoints, at: inspectionTime), secondary: true)
                } else {
                    GridRow {
                        Text(l10n(.direction)).foregroundStyle(.secondary)
                        Text(l10n(.average)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                        Text(l10n(.peak)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    rateStatisticsRow(primaryTitle, average: summary.primaryAverage, peak: summary.primaryPeak)
                    rateStatisticsRow(secondaryTitle, average: summary.secondaryAverage, peak: summary.secondaryPeak)
                }
            }
            .font(.system(size: 11)).monospacedDigit().help(l10n(.statisticsHelp))
        }
    }

    private func rateStatisticsRow(_ title: TextKey, average: Double?, peak: Double?) -> some View {
        GridRow {
            Text(l10n(title)).foregroundStyle(.secondary)
            Text(average.map { TrafficFormatter.speed($0).text } ?? "—")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(peak.map { TrafficFormatter.speed($0).text } ?? "—")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func inspectionRateRow(_ title: TextKey, point: HistoryPoint?, secondary: Bool) -> some View {
        GridRow {
            Text(l10n(title)).foregroundStyle(.secondary)
            Text(point.map { TrafficFormatter.speed(secondary ? $0.secondary : $0.primary).text } ?? "—")
                .gridCellColumns(2).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func totalsRow(_ firstTitle: TextKey, _ secondTitle: TextKey, first: UInt64, second: UInt64) -> some View {
        HStack(alignment: .top, spacing: 12) {
            compositionValue(l10n(firstTitle), value: TrafficFormatter.total(first))
            compositionValue(l10n(secondTitle), value: TrafficFormatter.total(second))
        }
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
        return Group {
            if let inspectionTime {
                let point = HistoryInspection.sample(points, at: inspectionTime)
                metricRow(l10n(.inspecting, inspectionLabel(inspectionTime)),
                          value: point.map { format(secondary ? $0.secondary : $0.primary) } ?? "—")
            } else {
                let statistics = summary ?? HistorySummary(points: visible(points))
                HStack(spacing: 12) {
                    statisticCell(.average, value: format(secondary ? statistics.secondaryAverage : statistics.primaryAverage))
                    statisticCell(.peak, value: format(secondary ? statistics.secondaryPeak : statistics.primaryPeak))
                }
            }
        }
    }

    private func statisticCell(_ title: TextKey, value: String) -> some View {
        HStack(spacing: 4) {
            Text(l10n(title))
            Spacer(minLength: 0)
            Text(value).monospacedDigit()
        }
        .font(.system(size: 11)).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }

    private func inspectionLabel(_ timestamp: TimeInterval) -> String {
        InsightStyle.time(Date().addingTimeInterval(timestamp - ProcessInfo.processInfo.systemUptime), localizer: l10n)
    }

    private var memoryHealthRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let pressure = monitor.resources.pressure {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(l10n(.memoryPressure)).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Circle().fill(InsightStyle.pressureColor(pressure)).frame(width: 5, height: 5)
                    Text(l10n(pressure.titleKey)).foregroundStyle(InsightStyle.pressureColor(pressure))
                }
                .help(l10n(.pressureHelp))
            }
            if let swap = monitor.resources.swap {
                metricRow(l10n(.swapUsed), value: TrafficFormatter.total(swap.usedBytes)).help(l10n(.swapHelp))
                if !visible(monitor.resources.swapHistory).isEmpty {
                    metricRow(l10n(.swapChangeWindow, historyDuration), value: InsightStyle.delta(visible(monitor.resources.swapHistory)))
                        .help(l10n(.swapHelp))
                }
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
