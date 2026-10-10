import AppKit
import Combine
import SpeedCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = SystemMonitor()
    private let preferences = AppPreferences()
    private let loginItem = LoginItemController()
    private let softwareUpdater = SoftwareUpdater()
    private let presentation = PopoverPresentation()
    private let eventNotifications = EventNotifications()
    private var statusItem: NSStatusItem!
    private var statusRings: MenuBarRingsHost?
    private var statusHoverRegions: [StatusItemHintTarget: StatusItemHoverRegion] = [:]
    private var statusHint: StatusItemHint?
    private var statusInteraction = StatusItemInteraction()
    private var panel: MonitorPanel?
    private var detailWindows: DetailWindowCoordinator?
    private var anchorFrame: NSRect?
    private var availableFrame: NSRect?
    private var globalClickMonitor: Any?
    private var subscriptions = Set<AnyCancellable>()
    private var popoverClickMonitor: Any?
    private var menuTrackingDepth = 0
    private var pendingReopen = false
    private var statusUpdateScheduled = false
    private var lastStatusImageKey: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        softwareUpdater.beforeUserInitiatedCheck = { [weak self] in self?.closePanel() }
        softwareUpdater.start()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "NetSpeedStatusItem"
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            let rings = MenuBarRingsHost()
            rings.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(rings)
            NSLayoutConstraint.activate([
                rings.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 6),
                rings.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                rings.widthAnchor.constraint(equalToConstant: MenuBarLabel.ringsWidth),
                rings.heightAnchor.constraint(equalToConstant: 22)
            ])
            statusRings = rings
            let hint = StatusItemHint(monitor: monitor, preferences: preferences)
            hint.canShow = { [weak self] in
                guard let self else { return false }
                return !self.statusInteraction.isPresented && self.menuTrackingDepth == 0
            }
            statusHoverRegions[.rings] = rings
            for target in [StatusItemHintTarget.disk, .network] {
                let region = StatusItemHoverRegion(frame: .zero)
                region.autoresizingMask = [.height]
                region.setAccessibilityElement(false)
                button.addSubview(region)
                statusHoverRegions[target] = region
            }
            for (target, region) in statusHoverRegions {
                region.onHoverChange = { [weak hint, weak region] inside in
                    guard let region else { return }
                    hint?.hover(target, anchor: region, inside: inside)
                }
            }
            statusHint = hint
        }
        presentation.onNavigate = { [weak self] in
            self?.panel?.makeFirstResponder(nil)
            self?.resizePanel()
        }
        presentation.onResize = { [weak self] in self?.resizePanel() }
        NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)
            .sink { [weak self] _ in self?.menuTrackingDepth += 1; self?.statusHint?.dismiss() }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.menuTrackingDepth = max(0, self.menuTrackingDepth - 1)
            }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.loginItem.refresh(); self?.eventNotifications.refresh() }
            .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.closePanel(); self?.statusHint?.dismiss(); self?.detailWindows?.close() }
            .store(in: &subscriptions)

        // Read the completed state once after synchronous @Published writes.
        // Keeping ResourceState in CombineLatest also retained its history arrays.
        monitor.objectWillChange.merge(with: preferences.objectWillChange)
            .sink { [weak self] _ in self?.scheduleStatusUpdate() }
            .store(in: &subscriptions)
        scheduleStatusUpdate()
        preferences.$refreshSeconds.dropFirst().removeDuplicates()
            .sink { [weak self] seconds in self?.monitor.setRefreshInterval(seconds) }
            .store(in: &subscriptions)
        monitor.onEvent = { [weak self] event in
            guard let self else { return }
            self.eventNotifications.send(event, preferences: self.preferences)
        }
        eventNotifications.onOpenEvent = { [weak self] in
            self?.showPopover()
            self?.detailWindows?.show(.events)
        }
        monitor.start(refreshSeconds: preferences.refreshSeconds)

        if pendingReopen || CommandLine.arguments.contains("--show") {
            pendingReopen = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.showPopover() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        requestReopen()
        return true
    }

    func requestReopen() {
        if statusItem == nil { pendingReopen = true }
        else { showPopover() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        closePanel()
        statusHint?.dismiss()
        detailWindows?.close()
        monitor.stop()
        subscriptions.removeAll()
    }

    @objc private func togglePopover() {
        statusHint?.dismiss()
        if let event = NSApp.currentEvent,
           event.type == .rightMouseDown || event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showStatusMenu()
            return
        }
        if statusInteraction.isPresented && panel?.isVisible == true && panel?.isOnActiveSpace == true { closePanel() }
        else { showPopover() }
    }

    private func showPopover() {
        guard let button = statusItem?.button, let statusWindow = button.window,
              let screen = statusWindow.screen else { return }
        statusHint?.dismiss()
        if #available(macOS 14.0, *) { NSApp.activate() }
        else { NSApp.activate(ignoringOtherApps: true) }
        loginItem.refresh()
        if statusInteraction.isPresented, panel?.isVisible == true, panel?.isOnActiveSpace == true {
            panel?.makeKeyAndOrderFront(nil)
            return
        }
        removePanelEventMonitors()
        let session = statusInteraction.present()
        // Capture the menu-bar anchor once. Live status text can change its width.
        anchorFrame = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
        availableFrame = screen.visibleFrame
        presentation.prepare(on: screen)
        if panel == nil {
            let window = MonitorPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.title = "PulseBar"
            window.identifier = NSUserInterfaceItemIdentifier("PulseBar.monitor")
            window.animationBehavior = .utilityWindow
            window.isReleasedWhenClosed = false
            window.level = .popUpMenu
            window.isMovable = false
            window.isMovableByWindowBackground = false
            window.hidesOnDeactivate = false
            window.hasShadow = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            let details = DetailWindowCoordinator(monitor: monitor, preferences: preferences, loginItem: loginItem,
                                                   notifications: eventNotifications, updater: softwareUpdater)
            details.sourceWindow = window
            detailWindows = details
            let controller = NativeGlassHostingController(rootView: PopoverView(
                monitor: monitor, preferences: preferences, loginItem: loginItem,
                presentation: presentation, eventNotifications: eventNotifications, softwareUpdater: softwareUpdater,
                onOpenDetails: { [weak details] route in details?.show(route) },
                onHoverModule: { [weak details] route, inside in details?.hover(route, inside: inside) },
                onPreferredHeight: { [weak self] height in self?.presentation.fitContentHeight(height) }
            ).ignoresSafeArea())
            window.contentViewController = controller
            panel = window
        }
        resizePanel(force: true)
        panel?.contentView?.layoutSubtreeIfNeeded()
        panel?.makeKeyAndOrderFront(nil)
        panel?.makeFirstResponder(nil)
        recordLayout("open")
        button.highlight(true)
        popoverClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self, self.statusInteraction.isPresented,
                  self.statusInteraction.generation == session, let window = self.panel else { return event }
            // Native menus have their own windows and handle Escape themselves.
            // They belong to this interaction and are not outside clicks.
            if self.menuTrackingDepth > 0 { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    if self.detailWindows?.contains(event.window) == true { self.detailWindows?.close() }
                    else { self.closePanel() }
                    return nil
                }
                return event
            }
            if event.window === window {
                if let editor = window.firstResponder as? NSTextView, editor.isFieldEditor,
                   let field = editor.delegate as? NSTextField,
                   !field.bounds.contains(field.convert(event.locationInWindow, from: nil)) {
                    window.makeFirstResponder(nil)
                }
            } else if self.detailWindows?.contains(event.window) != true,
                      event.window !== self.statusItem.button?.window,
                      !self.pointerIsInsideStatusItem {
                self.closePanel()
            }
            return event
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.statusInteraction.acceptsDismissal(from: session,
                isInsideStatusItem: self.pointerIsInsideStatusItem, isTrackingMenu: self.menuTrackingDepth > 0) else { return }
            self.closePanel()
        }
    }

    private func resizePanel(force: Bool = false) {
        guard let panel, force || panel.isVisible,
              let anchorFrame, let availableFrame else { return }
        let frame = PanelPlacement.frame(size: presentation.contentSize, anchor: anchorFrame, visibleFrame: availableFrame)
        if panel.frame != frame {
            panel.setFrame(frame, display: true, animate: panel.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.displayIfNeeded()
        }
        recordLayout("navigate", target: frame)
    }

    private func recordLayout(_ event: String, target: NSRect? = nil) {
        guard let file = ProcessInfo.processInfo.environment["PULSEBAR_LAYOUT_LOG"], let panel else { return }
        let line = "\(Date()) event=\(event) window=\(panel.windowNumber) route=\(presentation.route.rawValue) frame=\(panel.frame) target=\(target ?? panel.frame) visible=\(panel.isVisible)\n"
        guard let data = line.data(using: .utf8) else { return }
        if !FileManager.default.fileExists(atPath: file) { FileManager.default.createFile(atPath: file, contents: nil) }
        if let handle = FileHandle(forWritingAtPath: file) {
            handle.seekToEndOfFile(); handle.write(data); try? handle.close()
        }
    }

    private func showStatusMenu() {
        guard let button = statusItem.button else { return }
        let l10n = preferences.localizer
        let menu = NSMenu()
        for (route, title) in [(PanelRoute.overview, TextKey.overview), (.cpuApps, .topCPU),
                               (.memoryApps, .topMemory), (.events, .events), (.settings, .settings)] {
            let item = NSMenuItem(title: l10n(title), action: #selector(navigateFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = route.rawValue
            item.state = panel?.isVisible == true && presentation.route == route ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let update = NSMenuItem(title: l10n(.checkForUpdates), action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        update.isEnabled = softwareUpdater.canPresentUpdate
        menu.addItem(update)
        let reset = NSMenuItem(title: l10n(.reset), action: #selector(resetMonitoring), keyEquivalent: "")
        reset.target = self; menu.addItem(reset)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: l10n(.quit), action: #selector(quit), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        menu.autoenablesItems = false
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    @objc private func navigateFromMenu(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let route = PanelRoute(rawValue: value) else { return }
        showPopover()
        if route != .overview { detailWindows?.show(route) }
    }
    @objc private func checkForUpdates() { softwareUpdater.checkForUpdates() }
    @objc private func resetMonitoring() { monitor.reset() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func closePanel() {
        statusInteraction.dismiss()
        removePanelEventMonitors()
        statusHint?.dismiss()
        detailWindows?.closeTransient()
        panel?.makeFirstResponder(nil)
        recordLayout("close")
        panel?.orderOut(nil)
        presentation.navigate(.overview)
        statusItem.button?.highlight(false)
    }

    private func removePanelEventMonitors() {
        if let popoverClickMonitor { NSEvent.removeMonitor(popoverClickMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        popoverClickMonitor = nil
        globalClickMonitor = nil
    }

    private var pointerIsInsideStatusItem: Bool {
        guard let button = statusItem?.button, let window = button.window else { return false }
        return window.convertToScreen(button.convert(button.bounds, to: nil)).contains(NSEvent.mouseLocation)
    }

    private func scheduleStatusUpdate() {
        guard !statusUpdateScheduled else { return }
        statusUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.statusUpdateScheduled = false
            self.updateStatus(self.monitor.rate, error: self.monitor.networkError, resources: self.monitor.resources,
                selection: self.preferences.selection, localizer: self.preferences.localizer,
                historySeconds: self.preferences.historySeconds)
        }
    }

    private func updateStatus(_ rate: TrafficRate, error: Error?, resources: ResourceState,
                              selection: MenuBarSelection, localizer: Localizer, historySeconds: Int) {
        guard let button = statusItem?.button else { return }
        let down = error == nil ? TrafficFormatter.speed(rate.download) : nil
        let up = error == nil ? TrafficFormatter.speed(rate.upload) : nil
        let cpu = SystemFormatter.percent(resources.cpu?.usedPercent)
        let memory = SystemFormatter.percent(resources.memory?.usedPercent)
        let read = resources.diskRate.map { TrafficFormatter.speed($0.read) }
        let write = resources.diskRate.map { TrafficFormatter.speed($0.write) }
        statusRings?.update(cpu: resources.cpu?.usedPercent, memory: resources.memory?.usedPercent,
                            pressure: resources.pressure, selection: selection)
        let imageKey = selection.orderedMetrics.map(\.rawValue) + [read, write, down, up].map { $0?.value ?? "—" }
        if imageKey != lastStatusImageKey {
            let layout = MenuBarLabel.layout(diskRead: read?.value ?? "—", diskWrite: write?.value ?? "—",
                                            download: down?.value ?? "—", upload: up?.value ?? "—", selection: selection)
            if statusItem.length != layout.image.size.width + 12 { statusItem.length = layout.image.size.width + 12 }
            button.image = layout.image
            for target in [StatusItemHintTarget.disk, .network] {
                guard let region = statusHoverRegions[target] else { continue }
                if let frame = layout.regions[target] {
                    region.frame = NSRect(x: frame.minX + 6, y: 0, width: frame.width, height: button.bounds.height)
                    region.isHidden = false
                } else { region.isHidden = true }
            }
            lastStatusImageKey = imageKey
        }
        if panel?.isVisible == true, ProcessInfo.processInfo.environment["PULSEBAR_LAYOUT_LOG"] != nil {
            // Record the actual settled window geometry after normal sampling/layout.
            if let panel { NSLog("PulseBar settled frame %@", NSStringFromRect(panel.frame)) }
        }
        var values: [String] = []
        var errors: [Error?] = []
        for metric in selection.orderedMetrics {
            switch metric {
            case .cpu:
                values.append(localizer(.menuInnerCPU, cpu))
                errors.append(resources.cpuError)
            case .memory:
                values.append(localizer(.menuOuterMemory, memory))
                let pressure = resources.pressure.map { localizer($0.titleKey) } ?? "—"
                values.append(localizer(.namedValue, localizer(.memoryPressure), pressure))
                errors += [resources.memoryError, resources.pressureError]
            case .disk:
                values += [localizer(.namedValue, localizer(.diskRead), read?.text ?? "—"),
                           localizer(.namedValue, localizer(.diskWrite), write?.text ?? "—")]
                errors.append(resources.diskError)
            case .network:
                values += [localizer(.namedValue, localizer(.upload), up?.text ?? "—"),
                           localizer(.namedValue, localizer(.download), down?.text ?? "—")]
                errors.append(error)
            }
        }
        // Keep the fallback stable; live readings belong to the hover panel.
        // Reassigning toolTip every sample cancels its pending display timer.
        let toolTip = localizer(.menuHint, localizer.duration(historySeconds))
        if button.toolTip != toolTip { button.toolTip = toolTip }
        button.setAccessibilityLabel(localizer(.menuAccessibility))
        button.setAccessibilityValue(values.joined(separator: localizer(.listSeparator)))
        button.setAccessibilityHelp((errors.compactMap { localizer.describe($0) } + [toolTip]).joined(separator: "\n"))
    }
}

private final class MonitorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
