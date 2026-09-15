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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        softwareUpdater.beforeUserInitiatedCheck = { [weak self] in self?.closePanel() }
        softwareUpdater.start()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "NetSpeedStatusItem"
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
        }
        presentation.$showsSettings.combineLatest(presentation.$insight)
            .map { settings, insight in settings ? 661 : (insight == nil ? 400 : 741) }
            .removeDuplicates().dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in self?.resizePanel() }
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
            self?.presentation.showsSettings = false
            self?.presentation.insight = .events
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
            let window = MonitorPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
            window.title = "PulseBar"
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
            ).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 12)))
            controller.sizingOptions = []
            window.contentViewController = controller
            panel = window
        }
        resizePanel(force: true)
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        panel?.makeFirstResponder(nil)
        button.highlight(true)
        popoverClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self, let window = self.panel, window.isVisible else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { self.closePanel(); return nil }
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
            self?.closePanel()
        }
    }

    private func resizePanel(force: Bool = false) {
        guard let panel, force || panel.isVisible,
              let anchorFrame, let availableFrame else { return }
        // A single window owns placement; expanding a sidebar keeps its left/top
        // edge fixed unless a display boundary requires a minimal adjustment.
        let size = presentation.contentSize
        let frame = PanelPlacement.frame(size: size, anchor: anchorFrame, visibleFrame: availableFrame)
        panel.setFrame(frame, display: true, animate: false)
        // Optional on-device geometry evidence, disabled during ordinary use.
        if let file = ProcessInfo.processInfo.environment["PULSEBAR_LAYOUT_LOG"] {
            let line = "\(Date()) settings=\(presentation.showsSettings) insight=\(String(describing: presentation.insight)) frame=\(frame) available=\(availableFrame)\n"
            if let data = line.data(using: .utf8) {
                if !FileManager.default.fileExists(atPath: file) { FileManager.default.createFile(atPath: file, contents: nil) }
                if let handle = FileHandle(forWritingAtPath: file) {
                    handle.seekToEndOfFile(); handle.write(data); try? handle.close()
                }
            }
        }
    }

    private func closePanel() {
        panel?.makeFirstResponder(nil)
        panel?.orderOut(nil)
        presentation.showsSettings = false
        presentation.insight = nil
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
