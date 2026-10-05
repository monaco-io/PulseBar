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
        let heightValue = value(for: "--preview-height") ?? "820"
        guard let height = Int(heightValue), [660, 820].contains(height) else {
            fputs("--preview-height must be 660 or 820\n", stderr)
            exit(2)
        }
        let scrollBottom = value(for: "--preview-scroll") == "bottom"
        let outputPath = value(for: "--preview-output")
        if let outputPath, !outputPath.hasPrefix("/") {
            fputs("--preview-output must be an absolute PNG path\n", stderr)
            exit(2)
        }

        let app = NSApplication.shared
        let session = HardwarePreviewSession(language: language, height: CGFloat(height),
                                             outputURL: outputPath.map { URL(fileURLWithPath: $0) }, scrollBottom: scrollBottom, exitAfterCapture: arguments.contains("--preview-exit"))
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

    init(language: AppLanguage, height: CGFloat, outputURL: URL?, scrollBottom: Bool, exitAfterCapture: Bool) {
        let suiteName = "PulseBar.HardwarePreview." + UUID().uuidString
        let eventDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseBar-HardwarePreview-" + UUID().uuidString, isDirectory: true)
        self.suiteName = suiteName
        self.eventDirectory = eventDirectory
        self.language = language
        self.height = height
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
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: presentation.contentSize),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "PulseBar Hardware Preview"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = hosting
        self.window = window
        presentation.onNavigate = { [weak self] in
            guard let self else { return }
            self.window?.setContentSize(self.presentation.contentSize)
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        print("HARDWARE_PREVIEW_READY language=\(language.rawValue) height=\(Int(height))")
        fflush(stdout)
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
        guard let outputURL, let view = window?.contentView else { return }
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            fputs("Hardware preview could not create a display bitmap\n", stderr)
            return
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fputs("Hardware preview could not encode PNG\n", stderr)
            return
        }
        do {
            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try png.write(to: outputURL, options: .atomic)
            if exitAfterCapture { window?.close() }
            print("HARDWARE_PREVIEW_PNG \(outputURL.path) \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
            fflush(stdout)
        } catch {
            fputs("Hardware preview PNG failed: \(error.localizedDescription)\n", stderr)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
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
