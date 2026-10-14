import AppKit
import ServiceManagement
import HelperIPC
import SpeedCore

private final class HelperAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var statusLabel: NSTextField!
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
        let enable = NSButton(title: localizer(.enableHelper), target: self, action: #selector(enableHelper))
        let disable = NSButton(title: localizer(.disableHelper), target: self, action: #selector(disableHelper))
        let settings = NSButton(title: localizer(.openLoginSettings), target: self, action: #selector(openSettings))
        let buttons = NSStackView(views: [enable, disable])
        buttons.orientation = .horizontal
        let stack = NSStackView(views: [title, explanation, statusLabel, buttons, settings])
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
        do {
            if service.status != .enabled { try service.register() }
            refreshStatus()
        } catch { statusLabel.stringValue = error.localizedDescription }
    }

    @objc private func disableHelper() {
        service.unregister { [weak self] error in
            DispatchQueue.main.async {
                if let error { self?.statusLabel.stringValue = error.localizedDescription }
                else { self?.refreshStatus() }
            }
        }
    }

    @objc private func openSettings() { SMAppService.openSystemSettingsLoginItems() }

    private func refreshStatus() {
        switch service.status {
        case .enabled: statusLabel.stringValue = localizer(.helperEnabled)
        case .requiresApproval: statusLabel.stringValue = localizer(.loginApprovalRequired)
        default: statusLabel.stringValue = localizer(.helperDisabled)
        }
    }
}

private let app = NSApplication.shared
private let delegate = HelperAppDelegate()
app.delegate = delegate
withExtendedLifetime(delegate) { app.run() }
