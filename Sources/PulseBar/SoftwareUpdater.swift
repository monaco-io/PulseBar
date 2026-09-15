import AppKit
import Combine
import Sparkle
import SpeedCore
import SwiftUI

/// Sparkle owns update scheduling, signature verification and atomic installation.
final class SoftwareUpdater: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var startError: String?
    @Published private(set) var pendingVersion: String?
    var beforeUserInitiatedCheck: (() -> Void)?
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self
    )
    var canPresentUpdate: Bool { canCheckForUpdates || pendingVersion != nil }

    var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "—") (\(info["CFBundleVersion"] as? String ?? "—"))"
    }

    var releasesURL: URL {
        URL(string: Bundle.main.object(forInfoDictionaryKey: "PulseBarReleasesURL") as? String
            ?? "https://github.com/monaco-io/PulseBar/releases/latest")!
    }

    override init() {
        super.init()
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .assign(to: &$automaticallyChecksForUpdates)
    }

    func start() {
        do { try controller.updater.start() }
        catch { startError = error.localizedDescription }
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        guard canPresentUpdate else { return }
        beforeUserInitiatedCheck?()
        NSApplication.shared.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    // Menu-bar apps have no Dock icon. Show scheduled reminders in Settings,
    // and let a user-initiated check bring Sparkle's window to the front.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if !state.userInitiated { pendingVersion = update.displayVersionString }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        pendingVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() { pendingVersion = nil }

    func standardUserDriverWillShowModalAlert() { beforeUserInitiatedCheck?() }
}

struct SoftwareUpdateSettings: View {
    @ObservedObject var updater: SoftwareUpdater
    let localizer: Localizer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(localizer(.softwareUpdate)).fontWeight(.semibold)
                Spacer()
                Text(updater.version).foregroundStyle(.secondary).monospacedDigit()
            }
            Button(localizer(.checkForUpdates), action: updater.checkForUpdates)
                .disabled(!updater.canPresentUpdate)
            if let version = updater.pendingVersion {
                Text(localizer(.newVersionAvailable, version)).foregroundStyle(.blue)
            }
            Toggle(localizer(.automaticUpdateChecks), isOn: Binding(
                get: { updater.automaticallyChecksForUpdates },
                set: { updater.setAutomaticallyChecksForUpdates($0) }
            ))
            .toggleStyle(.switch).controlSize(.mini)
            .disabled(updater.startError != nil)
            Text(localizer(.updateHelp)).font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Link(localizer(.downloadAndReleaseNotes), destination: updater.releasesURL)
            if let error = updater.startError {
                Text(localizer(.updateStartFailed, error)).font(.system(size: 10)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
