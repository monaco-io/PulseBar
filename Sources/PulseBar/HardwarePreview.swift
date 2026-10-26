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
            ?? Bundle.main.object(forInfoDictionaryKey: "PulseBarPreviewOutput") as? String
        if let outputPath, !outputPath.hasPrefix("/") {
            fputs("--preview-output must be an absolute PNG path\n", stderr)
            exit(2)
        }

        let app = NSApplication.shared
        let session = HardwarePreviewSession(language: language, height: CGFloat(height), width: CGFloat(width),
            appearance: appearance,
            outputURL: outputPath.map { URL(fileURLWithPath: $0) }, scrollBottom: scrollBottom,
            exitAfterCapture: arguments.contains("--preview-exit")
                || Bundle.main.object(forInfoDictionaryKey: "PulseBarPreviewExitAfterCapture") as? Bool == true)
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
    private let storeCanvas = Bundle.main.object(forInfoDictionaryKey: "PulseBarAppStoreCanvas") as? Bool == true
    private let storePage = Bundle.main.object(forInfoDictionaryKey: "PulseBarPreviewPage") as? String ?? "overview"
    private var storePanelView: NSView?

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
        if storeCanvas { presentation.setPreviewAvailableHeight(850) }
        presentation.setPreviewHeight(height)
        if storeCanvas && ["customize", "numbers"].contains(storePage) { presentation.navigate(.settings) }
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
        window.isOpaque = storeCanvas
        window.backgroundColor = storeCanvas ? .white : .clear
        window.hasShadow = true
        window.animationBehavior = .utilityWindow
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.contentViewController = storeCanvas ? makeStoreCanvas(containing: controller) : controller
        window.setContentSize(storeCanvas ? NSSize(width: 1280, height: 800) : presentation.contentSize)
        self.window = window
        details.sourceWindow = window
        presentation.onNavigate = { [weak self] in
            guard let self else { return }
            if !self.storeCanvas { self.window?.setContentSize(self.presentation.contentSize) }
        }
        presentation.onResize = { [weak self] in
            guard let self, let window = self.window else { return }
            if self.storeCanvas {
                self.storePanelView?.frame = NSRect(x: 748, y: (800 - self.presentation.height) / 2,
                    width: self.presentation.contentSize.width, height: self.presentation.height)
                return
            }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                guard let self else { return }
                if self.scrollBottom { self.scrollToBottom() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.savePNG() }
            }
        }
    }

    // A fixed-size display canvas for App Store captures. The panel remains the
    // production SwiftUI view with live, sandboxed readings and native controls.
    // Capture this window through the normal UI automation screenshot tool.
    private func makeStoreCanvas(containing panel: NSViewController) -> NSViewController {
        if storePage != "overview" { return makeFeatureCanvas(containing: panel) }
        let canvas = NSViewController()
        canvas.view = NSView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800))
        canvas.view.wantsLayer = true
        let gradient = CAGradientLayer()
        gradient.frame = canvas.view.bounds
        gradient.colors = [NSColor(calibratedRed: 0.93, green: 0.96, blue: 1, alpha: 1).cgColor,
                           NSColor(calibratedRed: 0.97, green: 0.94, blue: 1, alpha: 1).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        canvas.view.layer?.addSublayer(gradient)
        let chinese = language == .simplifiedChinese
        func label(_ text: String, size: CGFloat, weight: NSFont.Weight, y: CGFloat, height: CGFloat,
                   color: NSColor = NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.28, alpha: 1)) {
            let field = NSTextField(wrappingLabelWithString: text)
            field.font = .systemFont(ofSize: size, weight: weight)
            field.textColor = color
            field.frame = NSRect(x: 80, y: y, width: 575, height: height)
            canvas.view.addSubview(field)
        }
        label("PulseBar", size: 27, weight: .semibold, y: 675, height: 45)
        label(chinese ? "Mac 性能，\n一目了然。" : "Your Mac.\nAt a glance.",
              size: 63, weight: .bold, y: 402, height: 190)
        label(chinese ? "CPU、内存、磁盘与网络。\n从菜单栏掌握运行状态。"
                      : "CPU, memory, disk and network.\nLive insights from your menu bar.",
              size: 24, weight: .regular, y: 280, height: 92)
        label(chinese ? "本地监控  ·  历史曲线  ·  性能事件"
                      : "Local monitoring  ·  History  ·  Performance events",
              size: 18, weight: .medium, y: 184, height: 55)
        label(chinese ? "应用占用排行与硬件温度需另行安装可选的 PulseBar Helper。"
                      : "App rankings and hardware temperatures require the optional, separately installed PulseBar Helper.",
              size: 15, weight: .regular, y: 66, height: 70,
              color: NSColor(calibratedRed: 0.35, green: 0.40, blue: 0.49, alpha: 1))
        canvas.addChild(panel)
        panel.view.frame = NSRect(x: 748, y: (800 - presentation.height) / 2,
                                  width: presentation.contentSize.width, height: presentation.height)
        canvas.view.addSubview(panel.view)
        storePanelView = panel.view
        return canvas
    }

    private func makeFeatureCanvas(containing panel: NSViewController) -> NSViewController {
        let canvas = NSViewController()
        canvas.view = NSView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800))
        canvas.view.wantsLayer = true
        let gradient = CAGradientLayer()
        gradient.frame = canvas.view.bounds
        gradient.colors = [NSColor(calibratedRed: 0.93, green: 0.96, blue: 1, alpha: 1).cgColor,
                           NSColor(calibratedRed: 0.97, green: 0.94, blue: 1, alpha: 1).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        canvas.view.layer?.addSublayer(gradient)
        let chinese = language == .simplifiedChinese
        func label(_ text: String, size: CGFloat, weight: NSFont.Weight, y: CGFloat, height: CGFloat,
                   color: NSColor = NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.28, alpha: 1)) {
            let field = NSTextField(wrappingLabelWithString: text)
            field.font = .systemFont(ofSize: size, weight: weight)
            field.textColor = color
            field.frame = NSRect(x: 80, y: y, width: 575, height: height)
            canvas.view.addSubview(field)
        }
        func strip(_ selection: MenuBarSelection, y: CGFloat) {
            let host = NSHostingView(rootView: MenuBarShowcase(monitor: monitor, preferences: preferences, selection: selection))
            host.frame = NSRect(x: 80, y: y, width: 575, height: 76)
            canvas.view.addSubview(host)
        }
        label("PulseBar", size: 27, weight: .semibold, y: 675, height: 45)
        switch storePage {
        case "customize":
            label(chinese ? "每一圈，\n自己定义。" : "Every ring.\nYour choice.", size: 61, weight: .bold, y: 425, height: 178)
            label(chinese ? "CPU、内存、磁盘、GPU 或电池。\n圆环与数值显隐，分别控制。"
                          : "CPU, memory, storage, GPU or battery.\nShow rings and numbers independently.",
                  size: 23, weight: .regular, y: 306, height: 100)
            strip(MenuBarSelection(), y: 199)
            label(chinese ? "外圈磁盘 · 中圈内存 · 内圈 CPU\n更改设置立即生效，重启仍然保留。"
                          : "Default: storage outside, memory, CPU inside.\nChanges apply immediately and stay saved.",
                  size: 18, weight: .medium, y: 106, height: 65)
        case "numbers":
            label(chinese ? "上传或下载，\n只留你想看的。" : "One direction.\nOr both.", size: 57, weight: .bold, y: 425, height: 178)
            label(chinese ? "上传、下载、读取、写入可独立选择。\n单项读数清晰，双行显示紧凑。"
                          : "Choose upload, download, read and write.\nFull-size single rows. Compact pairs.",
                  size: 23, weight: .regular, y: 316, height: 90)
            label(chinese ? "双向速率，分别显示单位" : "Both directions, independent units", size: 15, weight: .semibold, y: 286, height: 25)
            strip(MenuBarSelection(), y: 204)
            label(chinese ? "只显示读取与上传" : "Show only read and upload", size: 15, weight: .semibold, y: 164, height: 25)
            strip(MenuBarSelection(metrics: [.diskRead, .upload]), y: 82)
        default:
            label(chinese ? "性能状态，\n就在菜单栏。" : "Your Mac.\nIn the menu bar.", size: 57, weight: .bold, y: 425, height: 178)
            label(chinese ? "三个同心圆环，搭配实时数字。\n不用打开窗口，也能了解运行状态。"
                          : "Three rings and live numbers.\nKeep an eye on performance while you work.",
                  size: 23, weight: .regular, y: 306, height: 100)
            strip(MenuBarSelection(), y: 199)
            label(chinese ? "CPU / 磁盘：绿、黄、红分级。\n内存颜色跟随 macOS 内存压力。"
                          : "CPU and storage: green, yellow, red.\nMemory follows macOS memory pressure.",
                  size: 18, weight: .medium, y: 106, height: 65)
        }
        label(chinese ? "放大展示真实菜单栏组件。指标与传感器可用性因设备而异。"
                      : "Enlarged native menu bar components. Metric availability varies by Mac.",
              size: 14, weight: .regular, y: 27, height: 36,
              color: NSColor(calibratedRed: 0.35, green: 0.40, blue: 0.49, alpha: 1))
        canvas.addChild(panel)
        panel.view.frame = NSRect(x: 748, y: (800 - presentation.height) / 2,
                                  width: presentation.contentSize.width, height: presentation.height)
        canvas.view.addSubview(panel.view)
        storePanelView = panel.view
        return canvas
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
        window?.displayIfNeeded()
        CATransaction.flush()
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
    override func cancelOperation(_ sender: Any?) { close() }
}

/// Uses the production number layout and gauges with live readings. These are
/// enlarged components for product screenshots, not invented monitoring data.
private struct MenuBarShowcase: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var preferences: AppPreferences
    let selection: MenuBarSelection

    var body: some View {
        let cpu = SystemFormatter.percent(monitor.resources.cpu?.usedPercent).replacingOccurrences(of: "%", with: "")
        let memory = SystemFormatter.percent(monitor.resources.memory?.usedPercent).replacingOccurrences(of: "%", with: "")
        let rate = monitor.rate
        let image = MenuBarLabel.layout(cpu: cpu, memory: memory,
            diskRead: monitor.resources.diskRate.map { TrafficFormatter.speed($0.read, mode: preferences.diskSpeedMode) },
            diskWrite: monitor.resources.diskRate.map { TrafficFormatter.speed($0.write, mode: preferences.diskSpeedMode) },
            download: TrafficFormatter.speed(rate.download, mode: preferences.networkSpeedMode),
            upload: TrafficFormatter.speed(rate.upload, mode: preferences.networkSpeedMode), selection: selection).image
        ZStack(alignment: .leading) {
            Image(nsImage: image).renderingMode(.template).foregroundStyle(.primary)
            MenuBarRings(readings: MenuBarRingReadings(monitor: monitor), selection: selection)
        }
        .frame(width: image.size.width, height: 22)
        .scaleEffect(1.9, anchor: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.65), lineWidth: 1))
    }
}
#endif
