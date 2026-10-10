import AppKit
import SwiftUI

/// Menu-bar panels can be key without activating the application. Track their
/// pointer regions even in that state, without intercepting button clicks.
struct NativeHoverRegion: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> HoverTrackingView { HoverTrackingView() }
    func updateNSView(_ view: HoverTrackingView, context: Context) { view.onChange = onChange }
}

final class HoverTrackingView: NSView {
    var onChange: ((Bool) -> Void)?
    private var pointerTracking: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerTracking { removeTrackingArea(pointerTracking) }
        let area = NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag],
            owner: self, userInfo: nil)
        addTrackingArea(area)
        pointerTracking = area
    }

    override func mouseEntered(with event: NSEvent) { onChange?(true) }
    override func mouseExited(with event: NSEvent) { onChange?(false) }
}
