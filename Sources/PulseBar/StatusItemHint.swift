import AppKit
import SpeedCore
import SwiftUI

/// One passive native panel follows the hovered metric. Sampling updates
/// its labels in place, without restarting AppKit's tooltip dwell timer.
final class StatusItemHint {
    var canShow: () -> Bool = { true }
    private weak var anchor: StatusItemHoverRegion?
    private var target: StatusItemHintTarget?
    private var displayedTarget: StatusItemHintTarget?
    private var generation: UInt64 = 0
    private let monitor: SystemMonitor
    private let preferences: AppPreferences
    private var panel: NSPanel?
    private var pendingShow: DispatchWorkItem?

    init(monitor: SystemMonitor, preferences: AppPreferences) {
        self.monitor = monitor
        self.preferences = preferences
    }

    func hover(_ target: StatusItemHintTarget, anchor: StatusItemHoverRegion, inside: Bool) {
        guard inside else {
            // AppKit can deliver the previous region's exit after the next
            // region's enter. It must not dismiss the new metric's preview.
            if self.target == target, self.anchor === anchor { dismiss() }
            return
        }
        dismiss()
        self.target = target
        self.anchor = anchor
        let session = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == session, self.target == target,
                  self.anchor?.isPointerInside == true, self.canShow() else { return }
            self.pendingShow = nil
            self.show(target)
        }
        pendingShow = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    func dismiss() {
        generation &+= 1
        pendingShow?.cancel()
        pendingShow = nil
        target = nil
        anchor = nil
        panel?.orderOut(nil)
    }

    private func show(_ target: StatusItemHintTarget) {
        guard let anchor, !anchor.isHidden, let source = anchor.window, let screen = source.screen else { return }
        let count = preferences.selection.ringMetrics.count
        switch target {
        case .rings: guard count > 0 else { return }
        case .usage: guard preferences.selection.showsNumber(.cpu) || preferences.selection.showsNumber(.memory) else { return }
        case .disk: guard preferences.selection.visibleNumberMetrics.contains(where: { $0.monitorMetric == .disk }) else { return }
        case .network: guard preferences.selection.visibleNumberMetrics.contains(where: { $0.monitorMetric == .network }) else { return }
        }
        if panel == nil {
            let window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
            window.title = "PulseBar Metrics"
            window.identifier = NSUserInterfaceItemIdentifier("PulseBar.statusHint")
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .popUpMenu
            window.hidesOnDeactivate = false
            window.ignoresMouseEvents = true
            window.animationBehavior = .utilityWindow
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel = window
        }
        if displayedTarget != target {
            panel?.contentViewController = NativeGlassHostingController(rootView: StatusItemHintView(
                monitor: monitor, preferences: preferences, target: target), interactive: false)
            displayedTarget = target
        }
        let anchorFrame = source.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let rows = count + (preferences.selection.ringMetrics.contains(.memory) ? 1 : 0)
            + (preferences.selection.ringMetrics.contains(.storage) ? 1 : 0)
        let numberRows = preferences.selection.visibleNumberMetrics.filter { $0 == .cpu || $0 == .memory }.count
        let rateRows = preferences.selection.visibleNumberMetrics.filter {
            $0.monitorMetric == (target == .disk ? .disk : .network)
        }.count
        let size: NSSize
        switch target {
        case .rings: size = NSSize(width: 240, height: CGFloat(24 + 24 * rows))
        case .usage: size = NSSize(width: 240, height: CGFloat(24 + 24 * numberRows))
        case .disk, .network: size = NSSize(width: 280, height: CGFloat(64 + 46 * rateRows))
        }
        let frame = PanelPlacement.frame(size: size, anchor: anchorFrame, visibleFrame: screen.visibleFrame)
        panel?.setFrame(frame, display: false)
        panel?.contentView?.layoutSubtreeIfNeeded()
        panel?.orderFrontRegardless()
    }
}

private struct StatusItemRateValue: Identifiable {
    let metric: MenuBarNumberMetric
    let rate: Double?
    let totalName: TextKey
    let total: UInt64
    var id: MenuBarNumberMetric { metric }
}

private struct StatusItemHintView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var preferences: AppPreferences
    let target: StatusItemHintTarget

    var body: some View {
        Group {
            switch target {
            case .rings: rings
            case .usage: percentages
            case .disk, .network: rates
            }
        }
        .font(.system(size: 13, weight: .medium))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private var rings: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 0) {
            ForEach(MenuBarRingPosition.allCases, id: \.self) { position in
                let metric = preferences.selection.ringMetric(at: position)
                let readings = MenuBarRingReadings(monitor: monitor)
                metricRow(ring: position.titleKey, metric: metric.titleKey, value: readings.value(for: metric),
                          tint: readings.tint(for: metric))
            }
            if preferences.selection.ringMetrics.contains(.memory) {
                let pressure = monitor.resources.pressure.map { preferences.localizer($0.titleKey) } ?? "—"
                ringDetailRow(.memoryPressure, value: pressure)
            }
            if preferences.selection.ringMetrics.contains(.storage) {
                let available = monitor.storageCapacity.map { TrafficFormatter.total($0.availableBytes) } ?? "—"
                ringDetailRow(.availableSpaceLabel, value: available)
            }
        }
    }

    private var percentages: some View {
        VStack(spacing: 0) {
            ForEach(preferences.selection.visibleNumberMetrics.filter { $0 == .cpu || $0 == .memory }, id: \.self) { metric in
                HStack {
                    Text(preferences.localizer(metric.titleKey)).foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(SystemFormatter.percent(metric == .cpu ? monitor.resources.cpu?.usedPercent : monitor.resources.memory?.usedPercent))
                        .monospacedDigit()
                }
                .frame(height: 24)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func ringDetailRow(_ name: TextKey, value: String) -> some View {
        GridRow {
            Text(preferences.localizer(.namedValue, preferences.localizer(name), value))
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .frame(height: 24).gridCellColumns(3)
        }
    }

    private var rates: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(preferences.localizer(target == .disk ? .diskIO : .network),
                  systemImage: target == .disk ? "internaldrive" : "arrow.up.arrow.down")
                .font(.system(size: 12, weight: .semibold))
                .frame(height: 24)
            ForEach(rateValues) { value in
                rateRow(value.metric.titleKey, value: value.rate)
            }
            Divider().padding(.vertical, 6)
            ForEach(rateValues) { value in
                totalRow(value.totalName, value: value.total)
            }
        }
    }

    private var rateValues: [StatusItemRateValue] {
        let values: [StatusItemRateValue]
        if target == .disk {
            values = [
                .init(metric: .diskRead, rate: monitor.resources.diskRate?.read,
                      totalName: .sessionRead, total: monitor.resources.totalDiskRead),
                .init(metric: .diskWrite, rate: monitor.resources.diskRate?.write,
                      totalName: .sessionWrite, total: monitor.resources.totalDiskWritten)
            ]
        } else {
            values = [
                .init(metric: .upload, rate: monitor.networkError == nil ? monitor.rate.upload : nil,
                      totalName: .sessionUpload, total: monitor.totalSent),
                .init(metric: .download, rate: monitor.networkError == nil ? monitor.rate.download : nil,
                      totalName: .sessionDownload, total: monitor.totalReceived)
            ]
        }
        return values.filter { preferences.selection.showsNumber($0.metric) }
    }

    private func rateRow(_ name: TextKey, value: Double?) -> some View {
        HStack {
            Text(preferences.localizer(name)).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value.map {
                TrafficFormatter.speed($0, mode: target == .disk ? preferences.diskSpeedMode : preferences.networkSpeedMode).text
            } ?? "—").monospacedDigit().fixedSize()
        }
        .frame(height: 24)
        .accessibilityElement(children: .combine)
    }

    private func totalRow(_ name: TextKey, value: UInt64) -> some View {
        HStack {
            Text(preferences.localizer(name))
            Spacer(minLength: 12)
            Text(TrafficFormatter.total(value)).monospacedDigit().fixedSize()
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(height: 22)
        .accessibilityElement(children: .combine)
    }

    private func metricRow(ring: TextKey, metric: TextKey, value: Double?, tint: Color) -> some View {
        GridRow {
            Text(preferences.localizer(ring))
                .foregroundStyle(.secondary)
                .fixedSize()
                .frame(height: 24)
            HStack(spacing: 5) {
                Circle().fill(tint).frame(width: 6, height: 6).accessibilityHidden(true)
                Text(preferences.localizer(metric))
            }
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(SystemFormatter.percent(value))
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
                .gridColumnAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
