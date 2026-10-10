import AppKit

enum StatusItemHintTarget {
    case rings, disk, network
}

/// A stable tracking area that leaves the native status button's clicks intact.
class StatusItemHoverRegion: NSView {
    var onHoverChange: ((Bool) -> Void)?
    private var pointerTracking: NSTrackingArea?
    private(set) var isPointerInside = false

    override var isHidden: Bool {
        didSet { if isHidden { leave() } }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // inVisibleRect follows resized readings without restarting dwell on
        // every sample when the pointer remains within the same metric.
        guard pointerTracking == nil else { return }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        pointerTracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isHidden, !isPointerInside else { return }
        isPointerInside = true
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) { leave() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { leave() }
    }

    private func leave() {
        guard isPointerInside else { return }
        isPointerInside = false
        onHoverChange?(false)
    }
}
