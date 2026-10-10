import AppKit
import SpeedCore
import SwiftUI

/// A passive native panel follows the ring's tracking area. Sampling updates
/// its labels in place, without restarting AppKit's tooltip dwell timer.
final class StatusItemHint {
    weak var anchor: MenuBarRingsHost?
    var canShow: () -> Bool = { true }
    private let monitor: SystemMonitor
    private let preferences: AppPreferences
    private var panel: NSPanel?
    private var pendingShow: DispatchWorkItem?

    init(monitor: SystemMonitor, preferences: AppPreferences) {
        self.monitor = monitor
        self.preferences = preferences
    }

    func hover(_ inside: Bool) {
        dismiss()
        guard inside else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.anchor?.isPointerInside == true, self.canShow() else { return }
            self.show()
        }
        pendingShow = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    func dismiss() {
        pendingShow?.cancel()
        pendingShow = nil
        panel?.orderOut(nil)
    }

    private func show() {
        guard let anchor, !anchor.isHidden, let source = anchor.window, let screen = source.screen else { return }
        let count = [MonitorMetric.cpu, .memory].filter { preferences.selection.contains($0) }.count
        guard count > 0 else { return }
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
            window.contentViewController = NativeGlassHostingController(rootView: StatusItemHintView(
                monitor: monitor, preferences: preferences))
            panel = window
        }
        let anchorFrame = source.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let rows = count + (preferences.selection.contains(.memory) ? 1 : 0)
        let size = NSSize(width: 240, height: CGFloat(24 + 24 * rows))
        let frame = PanelPlacement.frame(size: size, anchor: anchorFrame, visibleFrame: screen.visibleFrame)
        panel?.setFrame(frame, display: false)
        panel?.contentView?.layoutSubtreeIfNeeded()
        panel?.orderFrontRegardless()
    }
}

private struct StatusItemHintView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 0) {
            if preferences.selection.contains(.memory) {
                metricRow(ring: .menuOuterRing, metric: .memory, value: monitor.resources.memory?.usedPercent)
            }
            if preferences.selection.contains(.cpu) {
                metricRow(ring: .menuInnerRing, metric: .cpu, value: monitor.resources.cpu?.usedPercent)
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
        .font(.system(size: 13, weight: .medium))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
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
