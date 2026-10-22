import AppKit
import ServiceManagement
import HelperIPC
import SpeedCore

private final class HelperAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var statusLabel: NSTextField!
    private var enableButton: NSButton!
    private var disableButton: NSButton!
    private var changingService = false
    private let service = SMAppService.agent(plistName: HelperIdentity.agentPlist)
    private let localizer = Localizer(language: .system)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 340),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = localizer(.helperTitle)
        window.isReleasedWhenClosed = false
        let title = NSTextField(labelWithString: localizer(.helperTitle))
        title.font = .boldSystemFont(ofSize: 22)
        let explanation = NSTextField(wrappingLabelWithString: localizer(.helperConsent))
        explanation.maximumNumberOfLines = 0
        statusLabel = NSTextField(wrappingLabelWithString: "")
        enableButton = NSButton(title: localizer(.enableHelper), target: self, action: #selector(enableHelper))
        disableButton = NSButton(title: localizer(.disableHelper), target: self, action: #selector(disableHelper))
        let openPulseBar = NSButton(title: localizer(.openPulseBar), target: self, action: #selector(openPulseBar))
        let settings = NSButton(title: localizer(.openLoginSettings), target: self, action: #selector(openSettings))
        let buttons = NSStackView(views: [enableButton, disableButton])
        buttons.orientation = .horizontal
        let shortcuts = NSStackView(views: [openPulseBar, settings])
        shortcuts.orientation = .horizontal
        let stack = NSStackView(views: [title, explanation, statusLabel, buttons, shortcuts])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 28)
        ])
        refreshStatus()
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) { if statusLabel != nil { refreshStatus() } }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @objc private func enableHelper() {
        guard !changingService else { return }
        if service.status == .requiresApproval { openSettings(); return }
        guard service.status != .enabled else { refreshStatus(); return }
        beginServiceChange(.helperEnabling)
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let error: Error?
            do { try service.register(); error = nil }
            catch let failure { error = failure }
            DispatchQueue.main.async { [self] in finishServiceChange(error) }
        }
    }

    @objc private func disableHelper() {
        guard !changingService else { return }
        beginServiceChange(.helperDisabling)
        service.unregister { [weak self] error in
            DispatchQueue.main.async {
                self?.finishServiceChange(error)
            }
        }
    }

    @objc private func openPulseBar() {
        let workspace = NSWorkspace.shared
        let running = workspace.runningApplications.first { $0.bundleIdentifier == HelperIdentity.appID }
        guard let url = running?.bundleURL ?? workspace.urlForApplication(withBundleIdentifier: HelperIdentity.appID) else {
            statusLabel.stringValue = localizer(.pulseBarNotInstalled)
            return
        }
        workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            guard let error else { return }
            DispatchQueue.main.async { self?.statusLabel.stringValue = error.localizedDescription }
        }
    }

    @objc private func openSettings() { SMAppService.openSystemSettingsLoginItems() }

    private func beginServiceChange(_ message: TextKey) {
        changingService = true
        enableButton.isEnabled = false
        disableButton.isEnabled = false
        statusLabel.stringValue = localizer(message)
    }

    private func finishServiceChange(_ error: Error?) {
        changingService = false
        refreshStatus()
        if let error { statusLabel.stringValue = error.localizedDescription }
    }

    private func refreshStatus() {
        guard !changingService else { return }
        let status = service.status
        enableButton.title = localizer(status == .requiresApproval ? .openLoginSettings : .enableHelper)
        enableButton.isEnabled = status != .enabled
        disableButton.isEnabled = status == .enabled || status == .requiresApproval
        switch status {
        case .enabled: statusLabel.stringValue = localizer(.helperEnabled)
        case .requiresApproval: statusLabel.stringValue = localizer(.helperApprovalRequired)
        default: statusLabel.stringValue = localizer(.helperDisabled)
        }
    }
}

private let app = NSApplication.shared
private let delegate = HelperAppDelegate()
app.delegate = delegate
withExtendedLifetime(delegate) { app.run() }
