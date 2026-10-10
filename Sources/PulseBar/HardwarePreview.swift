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

        let languageValue = value(for: "--preview-language")
            ?? Bundle.main.object(forInfoDictionaryKey: "PulseBarPreviewLanguage") as? String ?? "en"
        guard let language = AppLanguage(rawValue: languageValue), language != .system else {
            fputs("--preview-language must be en or zh-Hans\n", stderr)
            exit(2)
        }
        let heightValue = value(for: "--preview-height") ?? "600"
        guard let height = Int(heightValue), [520, 600, 660, 720, 820, 1040].contains(height) else {
            fputs("--preview-height must be 520, 600, 660, 720, 820 or 1040\n", stderr)
            exit(2)
        }
        let widthValue = value(for: "--preview-width") ?? String(Int(PanelLayout.overviewWidth))
        guard let width = Int(widthValue), [320, 400, 452].contains(width) else {
            fputs("--preview-width must be 320, 400 or 452\n", stderr)
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
        if arguments.contains("--preview-interactions") {
            fputs("The coordinate-based interaction harness is retired. Open --preview-hardware and verify the native controls through accessibility.\n", stderr)
            exit(2)
        }
        let outputPath = value(for: "--preview-output")
        if let outputPath, !outputPath.hasPrefix("/") {
            fputs("--preview-output must be an absolute PNG path\n", stderr)
            exit(2)
        }

        let app = NSApplication.shared
        let session = HardwarePreviewSession(language: language, height: CGFloat(height), width: CGFloat(width),
            appearance: appearance,
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
    private var detailWindows: DetailWindowCoordinator?
    private var cleanedUp = false

    init(language: AppLanguage, height: CGFloat, width: CGFloat, appearance: NSAppearance?,
         outputURL: URL?, scrollBottom: Bool, exitAfterCapture: Bool) {
        let suiteName = "PulseBar.HardwarePreview." + UUID().uuidString
        let eventDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseBar-HardwarePreview-" + UUID().uuidString, isDirectory: true)
        self.suiteName = suiteName
        self.eventDirectory = eventDirectory
        self.language = language
        self.height = height
        self.width = width
        self.appearance = appearance
        self.outputURL = outputURL
        self.scrollBottom = scrollBottom
        self.exitAfterCapture = exitAfterCapture
        let defaults = UserDefaults(suiteName: suiteName)!
        self.defaults = defaults
        defaults.removePersistentDomain(forName: suiteName)
        preferences = AppPreferences(defaults: defaults)
        preferences.language = language
        preferences.setRefreshSeconds(1)
        preferences.setHistorySeconds(60)
        preferences.notificationsEnabled = false
        // An explicitly supplied local event fixture lets UI acceptance exercise
        // expansion without inducing CPU load or modifying production history.
        if let path = Bundle.main.object(forInfoDictionaryKey: "PulseBarPreviewEventsFile") as? String {
            try? FileManager.default.createDirectory(at: eventDirectory, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: URL(fileURLWithPath: path),
                                             to: eventDirectory.appendingPathComponent("events.json"))
        }
        monitor = SystemMonitor(eventStore: PerformanceEventStore(
            url: eventDirectory.appendingPathComponent("events.json")))
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("HARDWARE_PREVIEW_ISOLATION suite=\(suiteName) eventDirectory=\(eventDirectory.path)")
        fflush(stdout)
        monitor.start(refreshSeconds: preferences.refreshSeconds)
        // RunLoop continues while the real reader and sampler collect data.
        // No production status item, notification callback, or updater is started.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.showWindow() }
    }

    private func showWindow() {
        presentation.prepare(on: NSScreen.main)
        presentation.setPreviewHeight(height)
        // The preview uses the same fixed-width navigation as the menu-bar panel.
        if width < PanelLayout.overviewWidth { presentation.setPreviewWidth(width) }
        let notifications = EventNotifications()
        let updater = SoftwareUpdater()
        eventNotifications = notifications
        softwareUpdater = updater
        let details = DetailWindowCoordinator(monitor: monitor, preferences: preferences, loginItem: loginItem,
                                               notifications: notifications, updater: updater)
        detailWindows = details
        let controller = NativeGlassHostingController(rootView: PopoverView(monitor: monitor, preferences: preferences,
            loginItem: loginItem, presentation: presentation,
            eventNotifications: notifications, softwareUpdater: updater,
            onOpenDetails: { [weak details] route in details?.show(route) },
            onHoverModule: { [weak details] route, inside in details?.hover(route, inside: inside) },
            onPreferredHeight: { [weak self] height in self?.presentation.fitContentHeight(height) }).ignoresSafeArea())
        let window = HardwarePreviewWindow(contentRect: NSRect(origin: .zero, size: presentation.contentSize),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.title = "PulseBar Hardware Preview"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.appearance = appearance
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.animationBehavior = .utilityWindow
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.contentViewController = controller
        window.setContentSize(presentation.contentSize)
        self.window = window
        details.sourceWindow = window
        presentation.onNavigate = { [weak self] in
            guard let self else { return }
            self.window?.setContentSize(self.presentation.contentSize)
        }
        presentation.onResize = { [weak self] in
            guard let self, let window = self.window else { return }
            var frame = window.frame
            frame.origin.y = frame.maxY - self.presentation.height
            frame.size = self.presentation.contentSize
            window.setFrame(frame, display: true, animate: window.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        print("HARDWARE_PREVIEW_READY language=\(language.rawValue) size=\(Int(width))x\(Int(height))")
        print("HARDWARE_PREVIEW_MATERIAL \((controller.view as? NativeGlassContainer)?.materialName ?? "unknown")")
        if let logPath = Bundle.main.object(forInfoDictionaryKey: "PulseBarPreviewDiagnostics") as? String {
            func nativeControls(_ view: NSView) -> [String] {
                let own = (view as? NSButton).map {
                    "control=\(type(of: $0)) bezel=\($0.bezelStyle.rawValue) bordered=\($0.isBordered) size=\($0.intrinsicContentSize)"
                }
                return (own.map { [$0] } ?? []) + view.subviews.flatMap(nativeControls)
            }
            let report = "material=\((controller.view as? NativeGlassContainer)?.materialName ?? "unknown") frame=\(window.frame) content=\(controller.view.frame) screenVisible=\(window.screen?.visibleFrame ?? .zero)\n"
                + nativeControls(controller.view).joined(separator: "\n") + "\n"
            try? report.write(toFile: logPath, atomically: true, encoding: .utf8)
        }
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { cleanup() }

    func cleanup() {
        guard !cleanedUp else { return }
        cleanedUp = true
        detailWindows?.close()
        monitor.stop()
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: eventDirectory)
    }
}

// A preview is a regular app window; unlike the production accessory panel it
// must become main so Stage Manager displays it at full size.
private final class HardwarePreviewWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
#endif
