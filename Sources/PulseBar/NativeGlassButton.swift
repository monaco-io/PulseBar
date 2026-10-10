import AppKit
import SwiftUI

/// NSButton draws and animates its own bezel, highlight, focus, and toggle state.
/// No glass wrapper, custom tracking, tint overlay, or Core Animation is involved.
struct NativeGlassButton: NSViewRepresentable {
    let title: String
    let symbol: String
    var isSelected = false
    var isToggle = false
    var iconOnly = false
    var action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.target = context.coordinator
        button.action = #selector(Coordinator.activate)
        button.bezelStyle = NativeControlStyle.glass
        button.controlSize = .regular
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        button.setButtonType(isToggle ? .pushOnPushOff : .momentaryPushIn)
        button.title = iconOnly ? "" : title
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.imagePosition = iconOnly ? .imageOnly : .imageLeading
        button.state = isSelected ? .on : .off
        button.isEnabled = isEnabled
        button.toolTip = title
        button.setAccessibilityLabel(title)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSButton, context: Context) -> CGSize? {
        // Older SDKs report only the symbol bounds for the newer glass bezel.
        // Reserve its hit area; AppKit still draws and animates the entire control.
        let size = nsView.intrinsicContentSize
        return CGSize(width: max(32, size.width), height: max(32, size.height))
    }

    final class Coordinator: NSObject {
        var action: (() -> Void)?
        @objc func activate() { action?() }
    }
}

struct NativeGlassMenu: NSViewRepresentable {
    struct Item {
        let title: String
        var symbol: String?
        var enabled = true
        var keyEquivalent = ""
        let action: () -> Void
    }

    let title: String
    let items: [Item?]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        button.bezelStyle = NativeControlStyle.glass
        button.controlSize = .regular
        button.imagePosition = .imageOnly
        (button.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        button.setAccessibilityLabel(title)
        button.toolTip = title
        let coordinator = context.coordinator
        coordinator.actions = Dictionary(uniqueKeysWithValues: items.enumerated().compactMap { index, item in
            item.map { (index, $0.action) }
        })
        let signature = items.map { $0.map { "\($0.title)|\($0.symbol ?? "")|\($0.enabled)|\($0.keyEquivalent)" } ?? "-" }
        guard signature != coordinator.signature else { return }
        coordinator.signature = signature
        let menu = NSMenu()
        menu.autoenablesItems = false
        let trigger = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        trigger.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: title)
        menu.addItem(trigger)
        for (index, entry) in items.enumerated() {
            guard let entry else { menu.addItem(.separator()); continue }
            let item = NSMenuItem(title: entry.title, action: #selector(Coordinator.activate(_:)),
                                  keyEquivalent: entry.keyEquivalent)
            item.target = coordinator
            item.tag = index
            item.isEnabled = entry.enabled
            item.image = entry.symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
            menu.addItem(item)
        }
        button.menu = menu
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? {
        let size = nsView.intrinsicContentSize
        return CGSize(width: max(32, size.width), height: max(32, size.height))
    }

    final class Coordinator: NSObject {
        var actions: [Int: () -> Void] = [:]
        var signature: [String] = []
        @objc func activate(_ sender: NSMenuItem) { actions[sender.tag]?() }
    }
}

private enum NativeControlStyle {
    static var glass: NSButton.BezelStyle {
        guard #available(macOS 26.0, *) else { return .rounded }
        #if compiler(>=6.2)
        return .glass
        #else
        // Public NSBezelStyleGlass ABI for the project's macOS 15 SDK.
        // Apple documents this style as available in macOS 26:
        // https://developer.apple.com/documentation/appkit/nsbutton/bezelstyle-swift.enum/glass
        // ABI value corroborated by the maintained AppKit platform binding:
        // https://github.com/dotnet/macios/blob/main/src/AppKit/Enums.cs
        return NSButton.BezelStyle(rawValue: 16)!
        #endif
    }
}
