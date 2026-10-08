#if DEBUG
import AppKit
import Foundation
import ServiceManagement
import SpeedCore
import SwiftUI

/// Runs the real hardware view in an isolated debug window. This entry point
/// must be called before acquiring AppInstance or constructing AppDelegate.
enum HardwarePreview {
    static func run() -> Never {
        let arguments = CommandLine.arguments
        func value(for flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag),
                  arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }

        let languageValue = value(for: "--preview-language") ?? "en"
        guard let language = AppLanguage(rawValue: languageValue), language != .system else {
            fputs("--preview-language must be en or zh-Hans\n", stderr)
            exit(2)
        }
        let heightValue = value(for: "--preview-height") ?? "660"
        guard let height = Int(heightValue), [520, 660, 820].contains(height) else {
            fputs("--preview-height must be 520, 660 or 820\n", stderr)
            exit(2)
        }
        let widthValue = value(for: "--preview-width") ?? "560"
        guard let width = Int(widthValue), [400, 560].contains(width) else {
            fputs("--preview-width must be 400 or 560\n", stderr)
            exit(2)
        }
        let scrollBottom = value(for: "--preview-scroll") == "bottom"
        let appearanceValue = value(for: "--preview-appearance") ?? "system"
        guard ["system", "light", "dark"].contains(appearanceValue) else {
            fputs("--preview-appearance must be system, light or dark\n", stderr)
            exit(2)
        }
        let appearance: NSAppearance? = appearanceValue == "system" ? nil
            : NSAppearance(named: appearanceValue == "dark" ? .darkAqua : .aqua)
        let regressionPath = value(for: "--preview-interactions")
        if let regressionPath, !regressionPath.hasPrefix("/") {
            fputs("--preview-interactions must be an absolute directory path\n", stderr)
            exit(2)
        }
        let outputPath = value(for: "--preview-output")
        if let outputPath, !outputPath.hasPrefix("/") {
            fputs("--preview-output must be an absolute PNG path\n", stderr)
            exit(2)
        }

        let app = NSApplication.shared
        let session = HardwarePreviewSession(language: language, height: CGFloat(height), width: CGFloat(width),
            appearance: appearance, regressionURL: regressionPath.map { URL(fileURLWithPath: $0, isDirectory: true) },
            outputURL: outputPath.map { URL(fileURLWithPath: $0) }, scrollBottom: scrollBottom,
            exitAfterCapture: arguments.contains("--preview-exit"))
        app.setActivationPolicy(.regular)
        app.delegate = session
        withExtendedLifetime(session) { app.run() }
        session.cleanup()
        exit(0)
    }
}

private final class PreviewLoginItemService: LoginItemService {
    var status: SMAppService.Status { .notRegistered }
    // The preview cannot register or unregister a real launch-at-login item.
    func register() throws { throw CocoaError(.featureUnsupported) }
    func unregister() throws { throw CocoaError(.featureUnsupported) }
}

private final class HardwarePreviewSession: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let suiteName: String
    private let eventDirectory: URL
    private let language: AppLanguage
    private let height: CGFloat
    private let width: CGFloat
    private let appearance: NSAppearance?
    private let regressionURL: URL?
    private let outputURL: URL?
    private let scrollBottom: Bool
    private let exitAfterCapture: Bool
    private let defaults: UserDefaults
    private let preferences: AppPreferences
    private let monitor: SystemMonitor
    private let presentation = PopoverPresentation()
    private let loginItem = LoginItemController(service: PreviewLoginItemService())
    private var eventNotifications: EventNotifications?
    private var softwareUpdater: SoftwareUpdater?
    private var window: NSWindow?
    private var cleanedUp = false
    private var interactionResults: [[String: Any]] = []
    private var initialWindowOrigin: NSPoint?
    private var initialWindowNumber: Int?

    init(language: AppLanguage, height: CGFloat, width: CGFloat, appearance: NSAppearance?,
         regressionURL: URL?, outputURL: URL?, scrollBottom: Bool, exitAfterCapture: Bool) {
        let suiteName = "PulseBar.HardwarePreview." + UUID().uuidString
        let eventDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseBar-HardwarePreview-" + UUID().uuidString, isDirectory: true)
        self.suiteName = suiteName
        self.eventDirectory = eventDirectory
        self.language = language
        self.height = height
        self.width = width
        self.appearance = appearance
        self.regressionURL = regressionURL
        self.outputURL = outputURL
        self.scrollBottom = scrollBottom
        self.exitAfterCapture = exitAfterCapture
        let defaults = UserDefaults(suiteName: suiteName)!
        self.defaults = defaults
        defaults.removePersistentDomain(forName: suiteName)
        preferences = AppPreferences(defaults: defaults)
        preferences.language = language
        preferences.setRefreshSeconds(1)
        preferences.notificationsEnabled = false
        monitor = SystemMonitor(eventStore: PerformanceEventStore(
            url: eventDirectory.appendingPathComponent("events.json")))
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.start(refreshSeconds: preferences.refreshSeconds)
        // RunLoop continues while the real reader and sampler collect data.
        // No production status item, notification callback, or updater is started.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.showWindow() }
    }

    private func showWindow() {
        presentation.prepare(on: NSScreen.main)
        presentation.setPreviewHeight(height)
        // A 560-point overview on the real screen must retain production
        // sidebar behavior. Only the narrow fixture limits the screen width.
        if width < PanelLayout.overviewWidth { presentation.setPreviewWidth(width) }
        let notifications = EventNotifications()
        let updater = SoftwareUpdater()
        eventNotifications = notifications
        softwareUpdater = updater
        let content = PopoverView(monitor: monitor, preferences: preferences,
            loginItem: loginItem, presentation: presentation,
            eventNotifications: notifications, softwareUpdater: updater)
            .background(PanelMaterial())
            .background(Color(nsColor: .windowBackgroundColor))
        let hosting = NSHostingView(rootView: content)
        hosting.appearance = appearance
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: presentation.contentSize),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "PulseBar Hardware Preview"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.appearance = appearance
        window.contentView = hosting
        self.window = window
        presentation.onNavigate = { [weak self] in
            guard let self else { return }
            self.window?.setContentSize(self.presentation.contentSize)
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        initialWindowOrigin = window.frame.origin
        initialWindowNumber = window.windowNumber
        NSApplication.shared.activate(ignoringOtherApps: true)
        print("HARDWARE_PREVIEW_READY language=\(language.rawValue) size=\(Int(width))x\(Int(height))")
        fflush(stdout)
        if regressionURL != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.runInteraction(at: 0) }
            return
        }
        if outputURL != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                if self.scrollBottom { self.scrollToBottom() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.savePNG() }
            }
        }
    }

    // Scroll the actual SwiftUI hardware viewport; fixed header and navigation
    // retain their production positions. All readings still use real readers.
    private func scrollToBottom() {
        NotificationCenter.default.post(name: Notification.Name("PulseBar.hardware-preview-scroll"), object: nil)
        print("HARDWARE_PREVIEW_SCROLL requested=bottom")
        fflush(stdout)
    }

    private func savePNG() {
        guard let outputURL else { return }
        if capturePNG(to: outputURL), exitAfterCapture { window?.close() }
    }

    @discardableResult private func capturePNG(to outputURL: URL) -> Bool {
        guard let view = window?.contentView else { return false }
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            fputs("Hardware preview could not create a display bitmap\n", stderr)
            return false
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fputs("Hardware preview could not encode PNG\n", stderr)
            return false
        }
        do {
            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try png.write(to: outputURL, options: .atomic)
            print("HARDWARE_PREVIEW_PNG \(outputURL.path) \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
            fflush(stdout)
            return true
        } catch {
            fputs("Hardware preview PNG failed: \(error.localizedDescription)\n", stderr)
            return false
        }
    }

    private enum InteractionAction { case click(NSPoint), closeWindow, reopenWindow }
    private struct Interaction {
        let name: String
        let action: InteractionAction
        let route: PanelRoute
        var visible = true
        var screenshot: String?
    }

    private var interactions: [Interaction] {
        let narrow = width < 500
        let cpu = NSPoint(x: 70, y: 90)
        let memory = NSPoint(x: narrow ? 90 : 350, y: narrow ? 308 : 90)
        let memoryValue = NSPoint(x: narrow ? 90 : 340, y: narrow ? 344 : 119)
        let overview = NSPoint(x: width * 0.125, y: height - 25)
        let apps = NSPoint(x: width * 0.375, y: height - 25)
        let events = NSPoint(x: width * 0.625, y: height - 25)
        let settings = NSPoint(x: width * 0.875, y: height - 25)
        let close = NSPoint(x: presentation.usesInlineDetails ? width - 25 : PanelLayout.expandedWidth - 25,
                            y: presentation.usesInlineDetails ? 95 : 27)
        return [
            Interaction(name: "CPU heading opens Apps", action: .click(cpu), route: .cpuApps, screenshot: "cpu-apps"),
            Interaction(name: "Detail close returns overview", action: .click(close), route: .overview),
            Interaction(name: "CPU value opens Apps", action: .click(NSPoint(x: 70, y: 119)), route: .cpuApps),
            Interaction(name: "Overview navigation returns", action: .click(overview), route: .overview),
            Interaction(name: "Memory heading opens Apps", action: .click(memory), route: .memoryApps, screenshot: "memory-apps"),
            Interaction(name: "Memory detail closes", action: .click(close), route: .overview),
            Interaction(name: "Memory value opens Apps", action: .click(memoryValue), route: .memoryApps),
            Interaction(name: "Overview returns from Memory", action: .click(overview), route: .overview),
            Interaction(name: "Apps navigation opens", action: .click(apps), route: .cpuApps),
            Interaction(name: "Repeated Apps stays open", action: .click(apps), route: .cpuApps),
            Interaction(name: "Events navigation opens", action: .click(events), route: .events, screenshot: "events"),
            Interaction(name: "Repeated Events stays open", action: .click(events), route: .events),
            Interaction(name: "Settings navigation opens", action: .click(settings), route: .settings, screenshot: "settings"),
            Interaction(name: "Repeated Settings stays open", action: .click(settings), route: .settings),
            Interaction(name: "Settings detail closes", action: .click(close), route: .overview),
            Interaction(name: "Window closes", action: .closeWindow, route: .overview, visible: false),
            Interaction(name: "Same window reopens", action: .reopenWindow, route: .overview),
            Interaction(name: "CPU opens after reopen", action: .click(cpu), route: .cpuApps),
            Interaction(name: "Window closes with CPU detail active", action: .closeWindow, route: .cpuApps, visible: false),
            Interaction(name: "Reopen resets CPU detail", action: .reopenWindow, route: .overview),
            Interaction(name: "Memory opens after reopen", action: .click(memory), route: .memoryApps),
            Interaction(name: "Window closes with Memory detail active", action: .closeWindow, route: .memoryApps, visible: false),
            Interaction(name: "Reopen resets Memory detail", action: .reopenWindow, route: .overview),
            Interaction(name: "Events opens after reopen", action: .click(events), route: .events),
            Interaction(name: "Window closes with Events detail active", action: .closeWindow, route: .events, visible: false),
            Interaction(name: "Reopen resets Events detail", action: .reopenWindow, route: .overview),
            Interaction(name: "Settings opens after reopen", action: .click(settings), route: .settings),
            Interaction(name: "Window closes with Settings detail active", action: .closeWindow, route: .settings, visible: false),
            Interaction(name: "Reopen resets Settings detail", action: .reopenWindow, route: .overview, screenshot: "overview-final")
        ]
    }

    private func runInteraction(at index: Int) {
        guard let regressionURL, let window else { return }
        if index == 0, !capturePNG(to: regressionURL.appendingPathComponent("overview.png")) {
            finishRegression(error: "Initial screenshot failed")
            return
        }
        guard index < interactions.count else { finishRegression(error: nil); return }
        let step = interactions[index]
        switch step.action {
        case let .click(topPoint):
            guard let view = window.contentView else { finishRegression(error: "No content view"); return }
            let point = view.convert(NSPoint(x: topPoint.x, y: view.isFlipped ? topPoint.y : view.bounds.height - topPoint.y), to: nil)
            let timestamp = ProcessInfo.processInfo.systemUptime
            // Queue both events before AppKit enters button tracking. These
            // activate the actual SwiftUI buttons; no route is assigned here.
            for kind in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                guard let event = NSEvent.mouseEvent(with: kind, location: point, modifierFlags: [],
                    timestamp: timestamp, windowNumber: window.windowNumber, context: nil,
                    eventNumber: index, clickCount: 1, pressure: kind == .leftMouseDown ? 1 : 0) else {
                    finishRegression(error: "Could not construct mouse event"); return
                }
                NSApplication.shared.postEvent(event, atStart: false)
            }
        case .closeWindow: window.performClose(nil)
        case .reopenWindow:
            presentation.prepare(on: NSScreen.main)
            presentation.setPreviewHeight(height)
            if width < PanelLayout.overviewWidth { presentation.setPreviewWidth(width) }
            window.setContentSize(presentation.contentSize)
            window.makeKeyAndOrderFront(nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.verifyInteraction(step, index: index) }
    }

    private func verifyInteraction(_ step: Interaction, index: Int) {
        guard let window, let view = window.contentView, let regressionURL else { return }
        view.layoutSubtreeIfNeeded()
        let expectedSize = presentation.contentSize
        let passed = presentation.route == step.route && window.isVisible == step.visible
            && abs(view.bounds.width - expectedSize.width) < 0.5 && abs(view.bounds.height - expectedSize.height) < 0.5
            && window.frame.origin == initialWindowOrigin && window.windowNumber == initialWindowNumber
        interactionResults.append(["step": step.name, "passed": passed, "route": presentation.route.rawValue,
            "expectedRoute": step.route.rawValue, "visible": window.isVisible,
            "contentWidth": view.bounds.width, "contentHeight": view.bounds.height,
            "originX": window.frame.minX, "originY": window.frame.minY, "windowNumber": window.windowNumber])
        print("HARDWARE_PREVIEW_INTERACTION \(index + 1) \(passed ? "PASS" : "FAIL") \(step.name) route=\(presentation.route.rawValue)")
        fflush(stdout)
        guard passed else { finishRegression(error: step.name + " did not produce the expected route/geometry"); return }
        if let name = step.screenshot, !capturePNG(to: regressionURL.appendingPathComponent(name + ".png")) {
            finishRegression(error: step.name + " screenshot failed"); return
        }
        runInteraction(at: index + 1)
    }

    private func finishRegression(error: String?) {
        guard let regressionURL else { return }
        let report: [String: Any] = ["passed": error == nil, "error": error as Any? ?? NSNull(),
            "language": language.rawValue, "appearance": window?.effectiveAppearance.name.rawValue ?? "unknown",
            "inlineDetails": presentation.usesInlineDetails, "steps": interactionResults,
            "cpuSamples": monitor.resources.cpuHistory.count, "networkSamples": monitor.history.count,
            "sameWindowReused": window?.windowNumber == initialWindowNumber,
            "scope": "Actual process-local AppKit mouse events activate production SwiftUI buttons in an isolated preview window"]
        do {
            try FileManager.default.createDirectory(at: regressionURL, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: regressionURL.appendingPathComponent("interactions.json"), options: .atomic)
        } catch {
            fputs("Regression report failed: \(error.localizedDescription)\n", stderr)
            cleanup(); exit(1)
        }
        cleanup()
        if let error { fputs("Hardware preview regression failed: \(error)\n", stderr); exit(1) }
        NSApplication.shared.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { regressionURL == nil }
    func applicationWillTerminate(_ notification: Notification) { cleanup() }

    func cleanup() {
        guard !cleanedUp else { return }
        cleanedUp = true
        monitor.stop()
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: eventDirectory)
    }
}
#endif
