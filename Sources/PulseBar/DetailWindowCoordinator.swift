import AppKit
import SpeedCore
import SwiftUI

/// A single reusable inspector: hover previews, click/pin keeps it open.
/// The overview never changes size or replaces its content to show a detail.
final class DetailWindowCoordinator: NSObject, NSWindowDelegate {
    weak var sourceWindow: NSWindow?
    private let monitor: SystemMonitor
    private let preferences: AppPreferences
    private let loginItem: LoginItemController
    private let notifications: EventNotifications
    private let updater: SoftwareUpdater
    private let presentation = PopoverPresentation()
    private var panel: DetailPanel?
    private var pendingShow: DispatchWorkItem?
    private var pendingHide: DispatchWorkItem?
    private var hoveredRoute: PanelRoute?
    private var isHoveringDetail = false
    private var measuredHeight: CGFloat = 0

    init(monitor: SystemMonitor, preferences: AppPreferences, loginItem: LoginItemController,
         notifications: EventNotifications, updater: SoftwareUpdater) {
        self.monitor = monitor
        self.preferences = preferences
        self.loginItem = loginItem
        self.notifications = notifications
        self.updater = updater
        super.init()
        presentation.onResize = { [weak self] in self?.resizeToFitContent() }
    }

    func hover(_ route: PanelRoute, inside: Bool) {
        if inside {
            hoveredRoute = route
            pendingHide?.cancel()
            guard !presentation.isPinned else { return }
            pendingShow?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.hoveredRoute == route, !self.presentation.isPinned else { return }
                self.show(route, pinned: false)
            }
            pendingShow = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        } else if hoveredRoute == route {
            hoveredRoute = nil
            pendingShow?.cancel()
            scheduleHide()
        }
    }

    func show(_ route: PanelRoute, pinned: Bool = true) {
        guard route != .overview, let sourceWindow, sourceWindow.isVisible else { return }
        pendingShow?.cancel()
        pendingHide?.cancel()
        let keepPosition = panel?.isVisible == true && presentation.isPinned
        let screen = (keepPosition ? panel?.screen : sourceWindow.screen) ?? NSScreen.main
        presentation.isPinned = pinned
        presentation.prepareDetail(route, on: screen)
        if panel == nil { makePanel() }
        guard let panel else { return }
        panel.title = "PulseBar · " + preferences.localizer(title(for: route))
        panel.appearance = sourceWindow.appearance
        panel.level = sourceWindow.level
        let visible = screen?.visibleFrame ?? sourceWindow.frame
        var frame = PanelPlacement.detailFrame(size: presentation.contentSize, beside: sourceWindow.frame, visibleFrame: visible)
        if keepPosition {
            frame.origin.x = max(visible.minX, min(panel.frame.minX, visible.maxX - frame.width))
            frame.origin.y = max(visible.minY, min(panel.frame.maxY, visible.maxY) - frame.height)
        }
        panel.setFrame(frame, display: false)
        panel.contentView?.layoutSubtreeIfNeeded()
        // The first layout can measure a different content height while the
        // panel is still hidden. Apply it before revealing the window.
        resizeToFitContent(animated: false)
        if pinned { panel.makeKeyAndOrderFront(nil); panel.makeFirstResponder(nil) }
        else { panel.orderFront(nil) }
        recordPreview("show")
    }

    func contains(_ window: NSWindow?) -> Bool { window != nil && window === panel }

    func closeTransient() {
        pendingShow?.cancel()
        hoveredRoute = nil
        if !presentation.isPinned { close() }
    }

    func close() {
        pendingShow?.cancel()
        pendingHide?.cancel()
        panel?.makeFirstResponder(nil)
        panel?.orderOut(nil)
        recordPreview("close")
        presentation.isPinned = false
        isHoveringDetail = false
    }

    private func makePanel() {
        let panel = DetailPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
        panel.identifier = NSUserInterfaceItemIdentifier("PulseBar.detail")
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.animationBehavior = .utilityWindow
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.onClose = { [weak self] in self?.close() }
        panel.contentViewController = NativeGlassHostingController(rootView: PopoverView(
            monitor: monitor, preferences: preferences, loginItem: loginItem,
            presentation: presentation, eventNotifications: notifications, softwareUpdater: updater,
            isDetached: true,
            onHoverWindow: { [weak self] inside in
                guard let self else { return }
                self.isHoveringDetail = inside
                if inside { self.pendingHide?.cancel() } else { self.scheduleHide() }
            },
            onTogglePin: { [weak self] in
                guard let self else { return }
                self.presentation.isPinned.toggle()
                if self.presentation.isPinned { self.panel?.makeKeyAndOrderFront(nil) }
                else { self.scheduleHide() }
            },
            onClose: { [weak self] in self?.close() },
            onPreferredHeight: { [weak self] height in
                guard let self else { return }
                self.measuredHeight = height
                self.presentation.fitContentHeight(height, on: self.panel?.screen ?? self.sourceWindow?.screen)
            }
        ).ignoresSafeArea())
        self.panel = panel
    }

    private func resizeToFitContent(animated: Bool = true) {
        guard let panel, let sourceWindow else { return }
        let visible = (panel.screen ?? sourceWindow.screen ?? NSScreen.main)?.visibleFrame ?? sourceWindow.frame
        var frame = PanelPlacement.detailFrame(size: presentation.contentSize, beside: sourceWindow.frame, visibleFrame: visible)
        if presentation.isPinned {
            frame.origin.x = max(visible.minX, min(panel.frame.minX, visible.maxX - frame.width))
            frame.origin.y = max(visible.minY, min(panel.frame.maxY, visible.maxY) - frame.height)
        }
        guard panel.frame != frame else { return }
        panel.setFrame(frame, display: true,
                       animate: animated && panel.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        recordPreview("resize")
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard measuredHeight > 0, let panel, panel.isVisible else { return }
        presentation.fitContentHeight(measuredHeight, on: panel.screen)
    }

    private func scheduleHide() {
        pendingHide?.cancel()
        guard !presentation.isPinned else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.presentation.isPinned, !self.isHoveringDetail,
                  self.hoveredRoute == nil else { return }
            // Give the pointer room to cross the small gap between the windows.
            if self.panel?.frame.contains(NSEvent.mouseLocation) == true { return }
            self.close()
        }
        pendingHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func title(for route: PanelRoute) -> TextKey {
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

    private func recordPreview(_ event: String) {
        #if DEBUG
        guard let path = Bundle.main.object(forInfoDictionaryKey: "PulseBarPreviewDiagnostics") as? String,
              let panel else { return }
        let line = "detail=\(event) route=\(presentation.route.rawValue) pinned=\(presentation.isPinned) visible=\(panel.isVisible) frame=\(panel.frame) source=\(sourceWindow?.frame ?? .zero) screenVisible=\(panel.screen?.visibleFrame ?? .zero)\n"
        if let data = line.data(using: .utf8), let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        }
        #endif
    }
}

private final class DetailPanel: NSPanel {
    var onClose: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onClose?() }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "q" {
            NSApp.terminate(nil)
            return true
        }
        if event.keyCode == 53 || (event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w") {
            onClose?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
