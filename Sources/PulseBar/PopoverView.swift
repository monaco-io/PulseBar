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
    var isDetached = false
    var onOpenDetails: ((PanelRoute) -> Void)?
    var onHoverModule: ((PanelRoute, Bool) -> Void)?
    var onHoverWindow: ((Bool) -> Void)?
    var onTogglePin: (() -> Void)?
    var onClose: (() -> Void)?
    var onPreferredHeight: ((CGFloat) -> Void)?
    @State private var inspectionTime: TimeInterval?
    @State private var inspectionEnd: TimeInterval?
    @State private var refreshDraft = ""
    @State private var historyDraft = ""
    @State private var resetFeedback = false
    @FocusState private var editingRefresh: Bool
    @FocusState private var editingHistory: Bool
    private var l10n: Localizer { preferences.localizer }
    private var route: PanelRoute { presentation.route }
    private var chartEnd: TimeInterval { inspectionEnd ?? monitor.timelineEnd }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if isDetached { detailHeader } else { header }
            }.fixedSize(horizontal: false, vertical: true).measurePanelHeight(.header)
            if showsHistoryControls {
                historyControls.fixedSize(horizontal: false, vertical: true).measurePanelHeight(.history)
            }
            GeometryReader { viewport in
                Group {
                    if route == .overview {
                        CompactHardwareView(monitor: monitor, preferences: preferences,
                                            panelWidth: presentation.overviewWidth,
                                            onOpen: { onOpenDetails?($0) }, onHoverModule: onHoverModule)
                    } else {
                        detailPanel
                    }
                }
                .frame(width: viewport.size.width, height: viewport.size.height, alignment: .top)
                .clipped()
            }
        }
        .frame(width: presentation.overviewWidth, height: presentation.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.locale, l10n.locale)
        .background(NativeHoverRegion { onHoverWindow?($0) })
        .onPreferenceChange(PanelHeightPreferenceKey.self) { heights in
            guard heights[.content] != nil else { return }
            onPreferredHeight?(heights.values.reduce(0, +))
        }
        .onAppear {
            refreshDraft = String(preferences.refreshSeconds)
            historyDraft = HistoryWindow.hoursText(seconds: preferences.historySeconds)
            if route == .settings { loginItem.refresh(); eventNotifications.refresh() }
        }
        .onDisappear { editingRefresh = false; editingHistory = false; inspect(nil) }
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
            inspect(nil)
            if destination == .settings { loginItem.refresh(); eventNotifications.refresh() }
        }
        .onChange(of: editingRefresh) { if !$0 { commitRefreshInterval() } }
        .onChange(of: editingHistory) { if !$0 { commitHistoryWindow() } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg").font(.system(size: 22, weight: .medium))
                .foregroundStyle(.tint).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("PulseBar").font(.system(size: 16, weight: .semibold))
                Text(resetFeedback ? l10n(.resetDone) : deviceDescription)
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 5)
            HStack(spacing: 4) {
                Circle().fill(monitor.networkError != nil || monitor.resources.hasError ? Color.orange : Color(nsColor: .systemGreen))
                    .frame(width: 4, height: 4)
                Text(monitor.networkError != nil || monitor.resources.hasError
                     ? l10n(.partialError) : l10n(.updatingEvery, preferences.refreshSeconds))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .fixedSize()
            NativeGlassButton(title: l10n(.settings), symbol: "gearshape", iconOnly: true) {
                onOpenDetails?(.settings)
            }
            .fixedSize()
            .overlay(alignment: .topTrailing) {
                if let version = softwareUpdater.pendingVersion {
                    Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                        .help(l10n(.newVersionAvailable, version)).allowsHitTesting(false)
                }
            }
            NativeGlassMenu(title: l10n(.moreActions), items: [
                .init(title: l10n(.events), symbol: "clock.arrow.circlepath") { onOpenDetails?(.events) },
                nil,
                .init(title: l10n(.checkForUpdates), symbol: "arrow.triangle.2.circlepath", enabled: softwareUpdater.canPresentUpdate,
                      action: softwareUpdater.checkForUpdates),
                .init(title: l10n(.downloadAndReleaseNotes), symbol: "arrow.down.circle") { NSWorkspace.shared.open(softwareUpdater.releasesURL) },
                nil,
                .init(title: l10n(.reset), symbol: "arrow.counterclockwise", action: monitor.reset),
                nil,
                .init(title: l10n(.quit), keyEquivalent: "q") { NSApp.terminate(nil) }
            ])
            .fixedSize()
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 14)
        .overlay {
            HStack {
                shortcut(.cpuDetails, key: "2")
                shortcut(.events, key: "3")
                shortcut(.settings, key: "4")
            }.hidden().accessibilityHidden(true)
        }
    }

    private var detailHeader: some View {
        HStack(spacing: 8) {
            Text(l10n(detailTitle)).font(.system(size: 16, weight: .semibold))
            Spacer()
            if route.isHardware {
                NativeGlassButton(title: l10n(presentation.isPinned ? .unpinWindow : .pinWindow),
                                  symbol: presentation.isPinned ? "pin.fill" : "pin",
                                  isSelected: presentation.isPinned, isToggle: true, iconOnly: true) { onTogglePin?() }
                    .fixedSize()
            }
            NativeGlassButton(title: l10n(.closeWindow), symbol: "xmark", iconOnly: true) { onClose?() }
                .fixedSize()
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 14)
    }

    private var deviceDescription: String {
        let name = monitor.gpuUsage.first?.name
        let memory = TrafficFormatter.total(ProcessInfo.processInfo.physicalMemory)
        let configuration = l10n(.deviceConfiguration, ProcessInfo.processInfo.processorCount, memory)
        return name.map { $0 + " · " + configuration } ?? configuration
    }

    private var showsHistoryControls: Bool {
        [.overview, .cpuDetails, .memoryDetails, .networkDetails, .storageDetails].contains(route)
    }

    private var historyControls: some View {
        HStack(spacing: 8) {
            Text(l10n(route == .overview ? .overview : .samplingSection))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Picker(l10n(.historyWindow), selection: Binding(
                get: { preferences.historySeconds }, set: { preferences.setHistorySeconds($0) }
            )) {
                ForEach(historyChoices, id: \.self) { seconds in
                    Text(l10n.duration(seconds)).tag(seconds)
                }
            }
            .pickerStyle(.segmented).labelsHidden().controlSize(.small)
            .frame(width: historyChoices.count > 3 ? 254 : 204)
            .help(l10n(.historyHint, l10n.duration(preferences.historySeconds)))
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
    }

    private var historyChoices: [Int] {
        let presets = [60, 300, 3600]
        return presets.contains(preferences.historySeconds) ? presets : (presets + [preferences.historySeconds]).sorted()
    }

    private func shortcut(_ destination: PanelRoute, key: KeyEquivalent) -> some View {
        Button("") { onOpenDetails?(destination) }.keyboardShortcut(key, modifiers: .command)
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if route.isApps {
                Picker(l10n(.appRanking), selection: Binding(get: { route }, set: { presentation.navigate($0) })) {
                    Text(l10n(.cpu)).tag(PanelRoute.cpuApps)
                    Text(l10n(.memory)).tag(PanelRoute.memoryApps)
                }
                .pickerStyle(.segmented).labelsHidden().padding(.horizontal, 20)
                .padding(.bottom, 12).measurePanelHeight(.history)
            }
            if route == .settings {
                FittingScrollView {
                    settingsContent
                        .padding(.horizontal, 20).padding(.top, 5).padding(.bottom, 20)
                }
            } else {
                FittingScrollView {
                    Group {
                        if route.isHardware {
                            HardwareDetailView(monitor: monitor, preferences: preferences, route: route,
                                               endingAt: chartEnd, inspectedTime: inspectionTime, onInspect: inspect)
                        } else if route.isApps {
                            RankingPane(monitor: monitor, preferences: preferences, metric: route == .cpuApps ? .cpu : .memory)
                        } else if route == .events {
                            EventTimelineView(monitor: monitor, localizer: l10n)
                        }
                    }
                    .id(route)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 20).padding(.top, 5).padding(.bottom, 20)
                }
                .frame(minHeight: 0, maxHeight: .infinity)
                .clipped()
            }
        }
        .font(.system(size: 12)).controlSize(.small)
    }

    private var detailTitle: TextKey {
        switch route {
        case .cpuDetails: return .cpu
        case .memoryDetails: return .memory
        case .networkDetails: return .network
        case .storageDetails: return .storage
        case .gpuDetails: return .gpu
        case .batteryDetails: return .battery
        case .events: return .events
        case .settings: return .settings
        default: return .appRanking
        }
    }

    private func inspect(_ timestamp: TimeInterval?) {
        guard let timestamp else { inspectionTime = nil; inspectionEnd = nil; return }
        if inspectionEnd == nil { inspectionEnd = monitor.timelineEnd }
        let histories = [monitor.resources.cpuHistory, monitor.resources.memoryHistory, monitor.resources.diskHistory, monitor.history]
        let reference = histories.max(by: { $0.count < $1.count }) ?? []
        let candidate = HistoryInspection.nearestSample(reference, at: timestamp)?.timestamp ?? timestamp
        inspectionTime = candidate >= chartEnd - Double(preferences.historySeconds) && candidate <= chartEnd ? candidate : timestamp
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(l10n(.menuBarItems)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        settingsMetric(.cpu)
                        settingsMetric(.memory)
                    }
                    HStack {
                        settingsMetric(.disk)
                        settingsMetric(.network)
                    }
                    if preferences.selection.metrics.count == 1 {
                        Text(l10n(.atLeastOne)).font(.caption).foregroundStyle(.secondary)
                    }
                    LabeledContent(l10n(.language)) {
                        Picker(l10n(.language), selection: $preferences.language) {
                            ForEach(AppLanguage.allCases, id: \.self) { language in
                                Text(language.label(using: l10n)).tag(language)
                            }
                        }.labelsHidden().fixedSize()
                    }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox(l10n(.samplingSection)) {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent(l10n(.refresh)) {
                        HStack {
                            TextField("", text: $refreshDraft)
                                .textFieldStyle(.roundedBorder).labelsHidden().frame(width: 76)
                                .multilineTextAlignment(.trailing)
                                .focused($editingRefresh)
                                .onSubmit { commitRefreshInterval(); editingRefresh = false }
                                .accessibilityLabel(l10n(.refresh))
                            Text(l10n(.secondsUnit)).foregroundStyle(.secondary)
                            NativeStepper(title: l10n(.refresh), value: Binding(
                                get: { Double(preferences.refreshSeconds) },
                                set: { preferences.setRefreshSeconds(Int($0)) }
                            ), range: Double(RefreshInterval.range.lowerBound)...Double(RefreshInterval.range.upperBound))
                                .fixedSize()
                        }
                    }
                    .help(l10n(.refreshHelp))
                    LabeledContent(l10n(.historyWindow)) {
                        HStack {
                            TextField("", text: $historyDraft)
                                .textFieldStyle(.roundedBorder).labelsHidden().frame(width: 76)
                                .multilineTextAlignment(.trailing)
                                .focused($editingHistory)
                                .onSubmit { commitHistoryWindow(); editingHistory = false }
                                .accessibilityLabel(l10n(.historyWindow))
                            Text(l10n(.hoursUnit)).foregroundStyle(.secondary)
                            NativeStepper(title: l10n(.historyWindow), value: historyBinding,
                                          range: HistoryWindow.hourRange, increment: 0.5).fixedSize()
                        }
                    }
                    .help(l10n(.historyHelp))
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox(l10n(.behaviorSection)) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(l10n(.launchAtLogin), isOn: Binding(
                        get: { loginItem.isRegistered }, set: { loginItem.setEnabled($0) }
                    ))
                    .help(l10n(.launchAtLoginHelp))
                    if loginItem.needsApproval {
                        Text(l10n(.loginApprovalRequired)).font(.caption).foregroundStyle(.orange)
                        NativeGlassButton(title: l10n(.openLoginSettings), symbol: "gearshape",
                                          action: loginItem.openSystemSettings).fixedSize()
                    }
                    if let error = loginItem.lastError {
                        Text(l10n(.loginItemFailed, error)).font(.caption).foregroundStyle(.orange)
                    }
                    Toggle(l10n(.notifications), isOn: Binding(
                        get: { preferences.notificationsEnabled },
                        set: { eventNotifications.setEnabled($0, preferences: preferences) }
                    ))
                    .disabled(eventNotifications.requesting)
                    .help(l10n(.notificationHelp))
                    LabeledContent(l10n(.notificationCooldown)) {
                        HStack {
                            Text("\(preferences.notificationCooldownMinutes) \(l10n(.minutesUnit))").monospacedDigit()
                            NativeStepper(title: l10n(.notificationCooldown), value: Binding(
                                get: { Double(preferences.notificationCooldownMinutes) },
                                set: { preferences.notificationCooldownMinutes = Int($0) }
                            ), range: 1...60).fixedSize()
                        }
                    }
                    Text(l10n(.notificationHelp)).font(.caption).foregroundStyle(.secondary)
                    if eventNotifications.requesting {
                        ProgressView(l10n(.notificationPending)).controlSize(.small)
                    }
                    if eventNotifications.denied {
                        Text(l10n(.notificationDenied)).font(.caption).foregroundStyle(.orange)
                        NativeGlassButton(title: l10n(.openNotificationSettings), symbol: "bell",
                                          action: eventNotifications.openSettings).fixedSize()
                    }
                    if let error = eventNotifications.lastError {
                        Text(l10n(.notificationFailed, error)).font(.caption).foregroundStyle(.orange)
                    }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox(l10n(.softwareUpdate)) {
                VStack(alignment: .leading, spacing: 10) {
                    SoftwareUpdateSettings(updater: softwareUpdater, localizer: l10n)
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .toggleStyle(.switch)
    }

    private func settingsMetric(_ metric: MonitorMetric) -> some View {
        visibilityToggle(metric).frame(maxWidth: .infinity, alignment: .leading)
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
        Toggle(l10n(metric.titleKey), isOn: Binding(
            get: { preferences.selection.contains(metric) },
            set: { preferences.setVisible(metric, $0) }
        ))
        .toggleStyle(.checkbox)
        .disabled(!preferences.selection.canToggle(metric))
        .help(preferences.selection.canToggle(metric) ? l10n(.showInMenuBar, l10n(metric.titleKey)) : l10n(.atLeastOne))
        .accessibilityLabel(l10n(.showInMenuBar, l10n(metric.titleKey)))
    }

}
