#if APP_STORE
import AppKit
import HelperIPC
import SpeedCore
import SwiftUI

struct HelperSettingsView: View {
    @ObservedObject var monitor: SystemMonitor
    let localizer: Localizer
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(localizer(monitor.helperConnected ? .helperConnected : .helperUnavailable),
                  systemImage: monitor.helperConnected ? "checkmark.circle" : "info.circle")
                .foregroundStyle(monitor.helperConnected ? .primary : .secondary)
            Text(localizer(.helperHelp)).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Link(localizer(.getHelper), destination: HelperIdentity.downloadURL)
            if let helper = NSWorkspace.shared.urlForApplication(withBundleIdentifier: HelperIdentity.helperID) {
                NativeGlassButton(title: localizer(.openHelper), symbol: "arrow.up.forward.app") {
                    NSWorkspace.shared.open(helper)
                }.fixedSize()
            }
        }
    }
}
#endif
