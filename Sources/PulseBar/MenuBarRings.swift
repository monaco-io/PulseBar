import AppKit
import SpeedCore
import SwiftUI

/// Keep the status item's native button, tooltip, highlighting and click target.
/// Only the gauges are colored; the disk/network image remains a template.
final class MenuBarRingsHost: NSView {
    var onHoverChange: ((Bool) -> Void)?
    private var pointerTracking: NSTrackingArea?
    private(set) var isPointerInside = false
    private let hosting = NSHostingView(rootView: MenuBarRings(
        cpu: nil, memory: nil, pressure: nil, selection: MenuBarSelection()))

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: MenuBarLabel.ringsWidth, height: 22))
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init()") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // inVisibleRect follows geometry itself. Replacing this area on every
        // sample would repeatedly reset a stationary pointer's hover state.
        guard pointerTracking == nil else { return }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        pointerTracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        isPointerInside = true
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        isPointerInside = false
        onHoverChange?(false)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { isPointerInside = false; onHoverChange?(false) }
    }

    func update(cpu: Double?, memory: Double?, pressure: MemoryPressure?, selection: MenuBarSelection) {
        isHidden = !selection.contains(.cpu) && !selection.contains(.memory)
        if isHidden { isPointerInside = false; onHoverChange?(false) }
        hosting.rootView = MenuBarRings(cpu: cpu, memory: memory, pressure: pressure, selection: selection)
    }
}

private struct MenuBarRings: View {
    let cpu: Double?
    let memory: Double?
    let pressure: MemoryPressure?
    let selection: MenuBarSelection
    var body: some View {
        ZStack {
            if selection.contains(.memory) {
                MenuBarRing(value: memory, diameter: 22, thickness: 3, tint: InsightStyle.pressureColor(pressure))
            }
            if selection.contains(.cpu) {
                MenuBarRing(value: cpu, diameter: 12, thickness: 3, tint: InsightStyle.cpuLoadColor(cpu))
            }
        }
        .frame(width: MenuBarLabel.ringsWidth, height: 22)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

}

private struct MenuBarRing: View {
    let value: Double?
    let diameter: CGFloat
    let thickness: CGFloat
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let normalized = value.flatMap { $0.isFinite ? min(100, max(0, $0)) : nil }
        return Gauge(value: normalized ?? 0, in: 0...100) { EmptyView() }
            .gaugeStyle(MenuBarCapacityGaugeStyle(thickness: thickness))
            .tint(normalized == nil ? Color(nsColor: .disabledControlTextColor) : tint)
            .labelsHidden()
            .frame(width: diameter, height: diameter)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: normalized)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: tint)
    }
}

/// Gauge's public styling API provides a predictable stroke at menu-bar size,
/// without shrinking a full-size accessory gauge and its line width.
private struct MenuBarCapacityGaugeStyle: GaugeStyle {
    let thickness: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            // Keep a complete, neutral circle visible when the progress tint changes.
            Circle().strokeBorder(lineWidth: thickness)
                .foregroundStyle(Color(nsColor: .systemGray)).opacity(0.45)
            Circle().inset(by: thickness / 2)
                .trim(from: 0, to: configuration.value)
                .stroke(style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                .foregroundStyle(.tint)
                .rotationEffect(.degrees(-90))
        }
    }
}
