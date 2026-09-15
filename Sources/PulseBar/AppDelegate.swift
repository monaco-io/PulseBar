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
    private var panel: MonitorPanel?
    private var anchorFrame: NSRect?
    private var availableFrame: NSRect?
    private var globalClickMonitor: Any?
    private var subscriptions = Set<AnyCancellable>()
    private var popoverClickMonitor: Any?
    private var menuTrackingDepth = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        softwareUpdater.beforeUserInitiatedCheck = { [weak self] in self?.closePanel() }
        softwareUpdater.start()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "NetSpeedStatusItem"
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
        }
        presentation.onNavigate = { [weak self] in
            self?.panel?.makeFirstResponder(nil)
            self?.resizePanel()
        }
        NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)
            .sink { [weak self] _ in self?.menuTrackingDepth += 1 }
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
            .sink { [weak self] _ in self?.closePanel() }
            .store(in: &subscriptions)

        Publishers.CombineLatest3(monitor.$rate, monitor.$networkError, monitor.$resources)
            .combineLatest(preferences.$selection, preferences.$language, preferences.$historySeconds)
            .sink { [weak self] snapshot, selection, language, historySeconds in
                self?.updateStatus(snapshot.0, error: snapshot.1, resources: snapshot.2,
                                   selection: selection, localizer: Localizer(language: language), historySeconds: historySeconds)
            }
            .store(in: &subscriptions)
        preferences.$refreshSeconds.dropFirst().removeDuplicates()
            .sink { [weak self] seconds in self?.monitor.setRefreshInterval(seconds) }
            .store(in: &subscriptions)
        monitor.onEvent = { [weak self] event in
            guard let self else { return }
            self.eventNotifications.send(event, preferences: self.preferences)
        }
        eventNotifications.onOpenEvent = { [weak self] in
            self?.showPopover()
            self?.presentation.navigate(.events)
        }
        monitor.start(refreshSeconds: preferences.refreshSeconds)

        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.showPopover() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { monitor.stop() }

    @objc private func togglePopover() {
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showStatusMenu()
            return
        }
        if panel?.isVisible == true { closePanel() } else { showPopover() }
    }

    private func showPopover() {
        guard let button = statusItem?.button, let statusWindow = button.window,
              let screen = statusWindow.screen else { return }
        loginItem.refresh()
        if panel?.isVisible == true { panel?.makeKeyAndOrderFront(nil); return }
        // Capture the menu-bar anchor once. Live status text can change its width.
        anchorFrame = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
        availableFrame = screen.visibleFrame
        presentation.prepare(on: screen)
        if panel == nil {
            let window = MonitorPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.title = "PulseBar"
            window.identifier = NSUserInterfaceItemIdentifier("PulseBar.monitor")
            window.animationBehavior = .none
            window.isReleasedWhenClosed = false
            window.level = .popUpMenu
            window.isMovable = false
            window.isMovableByWindowBackground = false
            window.hidesOnDeactivate = false
            window.hasShadow = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            let controller = NSHostingController(rootView: PopoverView(
                monitor: monitor, preferences: preferences, loginItem: loginItem,
                presentation: presentation, eventNotifications: eventNotifications, softwareUpdater: softwareUpdater
            ).ignoresSafeArea().background(PanelMaterial().ignoresSafeArea()).clipShape(RoundedRectangle(cornerRadius: 14)))
            controller.sizingOptions = []
            window.contentViewController = controller
            panel = window
        }
        resizePanel(force: true)
        panel?.contentView?.layoutSubtreeIfNeeded()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel?.alphaValue = reduceMotion ? 1 : 0
        panel?.makeKeyAndOrderFront(nil)
        panel?.makeFirstResponder(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0 : 0.12
            panel?.animator().alphaValue = 1
        }
        recordLayout("open")
        button.highlight(true)
        popoverClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self, let window = self.panel, window.isVisible else { return event }
            // Native menus have their own windows and handle Escape themselves.
            // They belong to this interaction and are not outside clicks.
            if self.menuTrackingDepth > 0 { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    if self.presentation.route.hasDetails { self.presentation.navigate(.overview) }
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
            } else if event.window !== self.statusItem.button?.window {
                self.closePanel()
            }
            return event
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.menuTrackingDepth == 0 else { return }
            self.closePanel()
        }
    }

    private func resizePanel(force: Bool = false) {
        guard let panel, force || panel.isVisible,
              let anchorFrame, let availableFrame else { return }
        let frame = PanelPlacement.frame(size: presentation.contentSize, anchor: anchorFrame, visibleFrame: availableFrame)
        // AppKit frame interpolation competes with NSHostingView layout and
        // briefly offsets individual rows. Commit geometry atomically; SwiftUI
        // animates only the detail reveal and controls inside the stable window.
        if panel.frame != frame {
            panel.setFrame(frame, display: false, animate: false)
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
        presentation.navigate(route)
    }
    @objc private func checkForUpdates() { softwareUpdater.checkForUpdates() }
    @objc private func resetMonitoring() { monitor.reset() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func closePanel() {
        panel?.makeFirstResponder(nil)
        recordLayout("close")
        panel?.orderOut(nil)
        panel?.alphaValue = 1
        presentation.navigate(.overview)
        if let popoverClickMonitor { NSEvent.removeMonitor(popoverClickMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        popoverClickMonitor = nil
        globalClickMonitor = nil
        statusItem.button?.highlight(false)
    }

    private func updateStatus(_ rate: TrafficRate, error: Error?, resources: ResourceState,
                              selection: MenuBarSelection, localizer: Localizer, historySeconds: Int) {
        guard let button = statusItem?.button else { return }
        let down = error == nil ? TrafficFormatter.speed(rate.download).text : "—"
        let up = error == nil ? TrafficFormatter.speed(rate.upload).text : "—"
        let cpu = SystemFormatter.percent(resources.cpu?.usedPercent)
        let memory = SystemFormatter.percent(resources.memory?.usedPercent)
        let read = resources.diskRate.map { TrafficFormatter.speed($0.read).text } ?? "—"
        let write = resources.diskRate.map { TrafficFormatter.speed($0.write).text } ?? "—"
        let image = MenuBarLabel.image(cpu: cpu, memory: memory, diskRead: read, diskWrite: write,
                                       download: down, upload: up, selection: selection)
        if statusItem.length != image.size.width + 12 { statusItem.length = image.size.width + 12 }
        if panel?.isVisible == true, ProcessInfo.processInfo.environment["PULSEBAR_LAYOUT_LOG"] != nil {
            // Record the actual settled window geometry after normal sampling/layout.
            if let panel { NSLog("PulseBar settled frame %@", NSStringFromRect(panel.frame)) }
        }
        button.image = image
        var values: [String] = []
        var errors: [Error?] = []
        for metric in selection.orderedMetrics {
            switch metric {
            case .cpu:
                values.append(localizer(.namedValue, localizer(.cpu), cpu))
                errors.append(resources.cpuError)
            case .memory:
                values.append(localizer(.namedValue, localizer(.memory), memory))
                errors.append(resources.memoryError)
            case .disk:
                values += [localizer(.namedValue, localizer(.diskRead), read), localizer(.namedValue, localizer(.diskWrite), write)]
                errors.append(resources.diskError)
            case .network:
                values += [localizer(.namedValue, localizer(.download), down), localizer(.namedValue, localizer(.upload), up)]
                errors.append(error)
            }
        }
        button.toolTip = (values + errors.compactMap { localizer.describe($0) }
                         + [localizer(.menuHint, localizer.duration(historySeconds))]).joined(separator: "\n")
        button.setAccessibilityLabel(localizer(.menuAccessibility))
        button.setAccessibilityValue(values.joined(separator: localizer(.listSeparator)))
    }
}

private final class MonitorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
