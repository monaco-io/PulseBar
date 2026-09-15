import AppKit
import Combine
import Sparkle
import SpeedCore
import SwiftUI

/// Sparkle owns update scheduling, signature verification and atomic installation.
final class SoftwareUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var startError: String?
    var beforeUserInitiatedCheck: (() -> Void)?
    private let controller = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
    )

    var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "—") (\(info["CFBundleVersion"] as? String ?? "—"))"
    }

    var releasesURL: URL {
        URL(string: Bundle.main.object(forInfoDictionaryKey: "PulseBarReleasesURL") as? String
            ?? "https://github.com/monaco-io/PulseBar/releases/latest")!
    }

    init() {
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
        guard canCheckForUpdates else { return }
        beforeUserInitiatedCheck?()
        NSApplication.shared.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
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
                .disabled(!updater.canCheckForUpdates)
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
