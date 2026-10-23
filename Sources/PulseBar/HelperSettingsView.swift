#if APP_STORE
import AppKit
import HelperIPC
import SpeedCore
import SwiftUI

struct HelperSettingsView: View {
    @ObservedObject var monitor: SystemMonitor
    let localizer: Localizer
    @State private var installedHelper: URL?
    @State private var openFailed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(localizer(monitor.helperConnected ? .helperConnected : .helperUnavailable),
                  systemImage: monitor.helperConnected ? "checkmark.circle" : "info.circle")
                .foregroundStyle(monitor.helperConnected ? .primary : .secondary)
            Text(localizer(.helperHelp)).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            NativeGlassButton(title: localizer(installedHelper == nil ? .getHelper : .openHelper),
                              symbol: installedHelper == nil ? "square.and.arrow.down" : "arrow.up.forward.app") {
                // The Store app hands the direct package URL to the browser.
                // Downloading/executing code in the sandbox is intentionally avoided.
                openFailed = !NSWorkspace.shared.open(installedHelper ?? HelperIdentity.downloadURL)
            }.fixedSize()
            if openFailed {
                Text(localizer(.helperOpenFailed)).font(.caption).foregroundStyle(.orange)
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
