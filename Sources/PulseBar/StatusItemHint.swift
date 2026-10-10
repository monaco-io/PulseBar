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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
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
        let count = [MonitorMetric.cpu, .memory].filter { preferences.selection.contains($0) }.count
        switch target {
        case .rings: guard count > 0 else { return }
        case .disk: guard preferences.selection.contains(.disk) else { return }
        case .network: guard preferences.selection.contains(.network) else { return }
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
                monitor: monitor, preferences: preferences, target: target))
            displayedTarget = target
        }
        let anchorFrame = source.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let rows = count + (preferences.selection.contains(.memory) ? 1 : 0)
        let size = target == .rings ? NSSize(width: 240, height: CGFloat(24 + 24 * rows))
            : NSSize(width: 280, height: 156)
        let frame = PanelPlacement.frame(size: size, anchor: anchorFrame, visibleFrame: screen.visibleFrame)
        panel?.setFrame(frame, display: false)
        panel?.contentView?.layoutSubtreeIfNeeded()
        panel?.orderFrontRegardless()
    }
}

private struct StatusItemHintView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var preferences: AppPreferences
    let target: StatusItemHintTarget

    var body: some View {
        Group {
            switch target {
            case .rings: rings
            case .disk, .network: rates
            }
        }
        .font(.system(size: 13, weight: .medium))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    private var rings: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 0) {
            if preferences.selection.contains(.cpu) {
                metricRow(ring: .menuInnerRing, metric: .cpu, value: monitor.resources.cpu?.usedPercent)
            }
            if preferences.selection.contains(.memory) {
                metricRow(ring: .menuOuterRing, metric: .memory, value: monitor.resources.memory?.usedPercent)
            }
            if preferences.selection.contains(.memory) {
                GridRow {
                    Label {
                        let pressure = monitor.resources.pressure.map { preferences.localizer($0.titleKey) } ?? "—"
                        Text(preferences.localizer(.namedValue, preferences.localizer(.memoryPressure), pressure))
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(InsightStyle.pressureColor(monitor.resources.pressure))
                    }
                    .font(.system(size: 11))
                    .frame(height: 24)
                    .gridCellColumns(3)
                }
            }
        }
    }

    private var rates: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(preferences.localizer(target == .disk ? .diskIO : .network),
                  systemImage: target == .disk ? "internaldrive" : "arrow.up.arrow.down")
                .font(.system(size: 12, weight: .semibold))
                .frame(height: 24)
            if target == .disk {
                rateRow(.read, value: monitor.resources.diskRate?.read)
                rateRow(.write, value: monitor.resources.diskRate?.write)
            } else {
                rateRow(.download, value: monitor.networkError == nil ? monitor.rate.download : nil)
                rateRow(.upload, value: monitor.networkError == nil ? monitor.rate.upload : nil)
            }
            Divider().padding(.vertical, 6)
            if target == .disk {
                totalRow(.sessionRead, value: monitor.resources.totalDiskRead)
                totalRow(.sessionWrite, value: monitor.resources.totalDiskWritten)
            } else {
                totalRow(.sessionDownload, value: monitor.totalReceived)
                totalRow(.sessionUpload, value: monitor.totalSent)
            }
        }
    }

    private func rateRow(_ name: TextKey, value: Double?) -> some View {
        HStack {
            Text(preferences.localizer(name)).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value.map { TrafficFormatter.speed($0).text } ?? "—").monospacedDigit().fixedSize()
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

    private func metricRow(ring: TextKey, metric: TextKey, value: Double?) -> some View {
        GridRow {
            Text(preferences.localizer(ring))
                .foregroundStyle(.secondary)
                .fixedSize()
                .frame(height: 24)
            Text(preferences.localizer(metric))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(SystemFormatter.percent(value))
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
                .gridColumnAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
