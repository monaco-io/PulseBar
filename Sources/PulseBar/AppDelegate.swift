import AppKit
import Combine
import SpeedCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let monitor = SystemMonitor()
    private let preferences = AppPreferences()
    private let loginItem = LoginItemController()
    private let presentation = PopoverPresentation()
    private var statusItem: NSStatusItem!
    private var popover = NSPopover()
    private var subscriptions = Set<AnyCancellable>()
    private var popoverClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "NetSpeedStatusItem"
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
        }
        presentation.$showsSettings.dropFirst().removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.popover.isShown else { return }
                    self.showPopover(preservingSettings: true)
                }
            }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.loginItem.refresh() }
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
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }

    private func showPopover(preservingSettings: Bool = false) {
        guard let button = statusItem?.button else { return }
        loginItem.refresh()
        // Reopening a visible panel only needs to focus its existing window.
        if popover.isShown && !preservingSettings {
            popover.contentViewController?.view.window?.makeKey()
            return
        }
        if !preservingSettings {
            presentation.prepare(on: button.window?.screen ?? NSScreen.main ?? NSScreen.screens.first)
        }
        // Start each width with a freshly positioned popover. Resizing a visible
        // status-item popover can shift it above the screen's menu-bar boundary.
        popover.contentViewController?.view.window?.makeFirstResponder(nil)
        popover.delegate = nil
        popover.close()
        removePopoverClickMonitor()
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        let controller = NSHostingController(rootView: PopoverView(
            monitor: monitor, preferences: preferences, loginItem: loginItem, presentation: presentation
        ))
        controller.sizingOptions = []
        popover.contentViewController = controller
        popover.contentSize = presentation.contentSize
        NSApplication.shared.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if let window = popover.contentViewController?.view.window {
            window.makeKey()
            // A monitoring panel should open without automatically editing a setting.
            window.makeFirstResponder(nil)
        }
        popoverClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let window = self?.popover.contentViewController?.view.window,
                  event.window === window,
                  let editor = window.firstResponder as? NSTextView, editor.isFieldEditor,
                  let field = editor.delegate as? NSTextField else { return event }
            // Finish editing before delivering an outside click to its normal control.
            if !field.bounds.contains(field.convert(event.locationInWindow, from: nil)) {
                window.makeFirstResponder(nil)
            }
            return event
        }
        button.highlight(true)
    }

    func popoverWillClose(_ notification: Notification) {
        guard notification.object as? NSPopover === popover else { return }
        popover.contentViewController?.view.window?.makeFirstResponder(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        guard notification.object as? NSPopover === popover else { return }
        presentation.showsSettings = false
        removePopoverClickMonitor()
        statusItem.button?.highlight(false)
    }

    private func removePopoverClickMonitor() {
        if let popoverClickMonitor { NSEvent.removeMonitor(popoverClickMonitor) }
        popoverClickMonitor = nil
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
        button.image = image
        if popover.isShown { popover.positioningRect = button.bounds }
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
