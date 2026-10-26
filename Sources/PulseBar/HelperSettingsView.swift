#if APP_STORE
import AppKit
import HelperIPC
import SpeedCore
import SwiftUI

struct HelperSettingsView: View {
    @ObservedObject var monitor: SystemMonitor
    let localizer: Localizer
    @State private var installedHelper: URL?
    @State private var openFailure: TextKey?
    private var statusKey: TextKey {
        guard !monitor.helperConnected else { return .helperConnected }
        switch monitor.processError as? HelperError {
        case .timeout?: return .helperTimeout
        case .invalidResponse?, .incompatibleVersion?: return .helperIncompatible
        default: return .helperUnavailable
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(localizer(statusKey),
                  systemImage: monitor.helperConnected ? "checkmark.circle" : "info.circle")
                .foregroundStyle(monitor.helperConnected ? .primary : .secondary)
            Text(localizer(.helperHelp)).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            NativeGlassButton(title: localizer(installedHelper == nil ? .getHelper : .openHelper),
                              symbol: installedHelper == nil ? "square.and.arrow.down" : "arrow.up.forward.app") {
                openFailure = nil
                if let installedHelper {
                    // Launch the application explicitly. Treating a helper in
                    // ~/Applications as a document is denied by App Sandbox.
                    NSWorkspace.shared.openApplication(at: installedHelper, configuration: .init()) { application, error in
                        DispatchQueue.main.async {
                            openFailure = application == nil || error != nil ? .helperOpenFailed : nil
                        }
                    }
                } else {
                    // The browser handles the download; Installer handles the PKG.
                    if !NSWorkspace.shared.open(HelperIdentity.downloadURL) {
                        openFailure = .helperDownloadFailed
                    }
                }
            }.fixedSize()
            if let openFailure {
                Text(localizer(openFailure)).font(.caption).foregroundStyle(.orange)
            }
        }
        .onAppear(perform: refreshInstalledHelper)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { _ in
            refreshInstalledHelper()
        }
    }

    private func refreshInstalledHelper() {
        installedHelper = NSWorkspace.shared.urlForApplication(withBundleIdentifier: HelperIdentity.helperID)
    }
}
#endif
