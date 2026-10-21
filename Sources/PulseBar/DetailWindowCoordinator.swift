import AppKit
import SpeedCore
import SwiftUI

/// A single reusable inspector. Hardware previews never become pinned by a click.
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
    private var isNavigationPresented = false
    private var requestGeneration: UInt64 = 0
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
            guard !isNavigationPresented else { return }
            pendingShow?.cancel()
            requestGeneration &+= 1
            // Switching an already visible inspector should not wait through
            // another dwell period or rebuild a same-route hosting hierarchy.
            if panel?.isVisible == true {
                present(route, takesFocus: false)
                return
            }
            let generation = requestGeneration
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.requestGeneration == generation,
                      self.hoveredRoute == route, !self.isNavigationPresented else { return }
                self.present(route, takesFocus: false)
            }
            pendingShow = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        } else if hoveredRoute == route {
            hoveredRoute = nil
            pendingShow?.cancel()
            requestGeneration &+= 1
            scheduleHide()
        }
    }

    func show(_ route: PanelRoute) { present(route, takesFocus: true) }

    private func present(_ route: PanelRoute, takesFocus: Bool) {
        guard route != .overview, let sourceWindow, sourceWindow.isVisible else { return }
        pendingShow?.cancel()
        pendingHide?.cancel()
        pendingShow = nil
        pendingHide = nil
        requestGeneration &+= 1
        // Settings, events and rankings use ordinary click navigation. Merely
        // crossing a hardware row must not interrupt editing those destinations.
        isNavigationPresented = !route.isHardware
        if panel?.isVisible == true, presentation.route == route {
            if takesFocus { panel?.makeKeyAndOrderFront(nil) }
            return
        }
        let screen = sourceWindow.screen ?? NSScreen.main
        presentation.prepareDetail(route, on: screen)
        if panel == nil { makePanel() }
        guard let panel else { return }
        panel.title = "PulseBar · " + preferences.localizer(title(for: route))
        panel.appearance = sourceWindow.appearance
        panel.level = sourceWindow.level
        let visible = screen?.visibleFrame ?? sourceWindow.frame
        let frame = PanelPlacement.detailFrame(size: presentation.contentSize, beside: sourceWindow.frame, visibleFrame: visible)
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        panel.contentView?.layoutSubtreeIfNeeded()
        // The first layout can measure a different content height while the
        // panel is still hidden. Apply it before revealing the window.
        resizeToFitContent(animated: false)
        if takesFocus { panel.makeKeyAndOrderFront(nil); panel.makeFirstResponder(nil) }
        else { panel.orderFront(nil) }
        recordPreview("show")
    }

    func contains(_ window: NSWindow?) -> Bool { window != nil && window === panel }

    func close() {
        requestGeneration &+= 1
        pendingShow?.cancel()
        pendingHide?.cancel()
        pendingShow = nil
        pendingHide = nil
        hoveredRoute = nil
        panel?.makeFirstResponder(nil)
        panel?.orderOut(nil)
        recordPreview("close")
        isNavigationPresented = false
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
        panel.isMovableByWindowBackground = false
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
        let frame = PanelPlacement.detailFrame(size: presentation.contentSize, beside: sourceWindow.frame, visibleFrame: visible)
        guard panel.frame != frame else { return }
        NativePanelMotion.resize(panel, to: frame, animated: animated)
        recordPreview("resize")
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard measuredHeight > 0, let panel, panel.isVisible else { return }
        presentation.fitContentHeight(measuredHeight, on: panel.screen)
    }

    private func scheduleHide() {
        pendingHide?.cancel()
        guard !isNavigationPresented else { return }
        let generation = requestGeneration
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.requestGeneration == generation,
                  !self.isNavigationPresented, !self.isHoveringDetail,
                  self.hoveredRoute == nil else { return }
            // Give the pointer room to cross the small gap between the windows.
            if self.panel?.frame.contains(NSEvent.mouseLocation) == true { return }
            self.close()
        }
        pendingHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
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
        let line = "detail=\(event) route=\(presentation.route.rawValue) navigation=\(isNavigationPresented) visible=\(panel.isVisible) frame=\(panel.frame) source=\(sourceWindow?.frame ?? .zero) screenVisible=\(panel.screen?.visibleFrame ?? .zero)\n"
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
