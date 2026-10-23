import AppKit
import SwiftUI

/// Standard actions use Apple's SwiftUI Button and GlassButtonStyle. The
/// system owns the shape, padding, material, focus and interaction feedback.
struct NativeGlassButton: View {
    let title: String
    let symbol: String
    var iconOnly = false
    var fillsBounds = false
    var action: () -> Void

    var body: some View {
        if fillsBounds {
            NativeHardwareButton(title: title, action: action)
        } else {
            Button(action: action) {
                if iconOnly {
                    // A shared SF Symbol canvas prevents ellipsis from shrinking the control.
                    Label(title, systemImage: symbol).labelStyle(.iconOnly)
                        .frame(width: 16, height: 16)
                } else if symbol.isEmpty {
                    Text(title)
                } else {
                    Label(title, systemImage: symbol)
                }
            }
            .modifier(SystemGlassButtonStyle(iconOnly: iconOnly))
            .accessibilityLabel(title)
            .help(title)
        }
    }
}

/// Both header actions use the same official Button style. The More button
/// presents AppKit's NSMenu, avoiding Menu's distinct compact popup bezel.
struct NativeGlassMenu: View {
    struct Item {
        let title: String
        var symbol: String?
        var enabled = true
        var keyEquivalent = ""
        let action: () -> Void
    }

    let title: String
    let items: [Item?]
    @StateObject private var presenter = NativeMenuPresenter()

    var body: some View {
        NativeGlassButton(title: title, symbol: "ellipsis", iconOnly: true) {
            presenter.show(items)
        }
        .background(NativeMenuAnchor(presenter: presenter).allowsHitTesting(false))
        .accessibilityAction(.showMenu) { presenter.show(items) }
    }
}

private final class NativeMenuPresenter: NSObject, ObservableObject {
    weak var anchor: NSView?
    private var actions: [Int: () -> Void] = [:]

    func show(_ items: [NativeGlassMenu.Item?]) {
        guard let anchor, anchor.window != nil else { return }
        actions.removeAll()
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (index, entry) in items.enumerated() {
            guard let entry else { menu.addItem(.separator()); continue }
            let item = NSMenuItem(title: entry.title, action: #selector(activate(_:)), keyEquivalent: entry.keyEquivalent)
            item.target = self
            item.tag = index
            item.isEnabled = entry.enabled
            item.image = entry.symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
            actions[index] = entry.action
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: anchor.bounds.minX,
            y: anchor.isFlipped ? anchor.bounds.maxY : anchor.bounds.minY), in: anchor)
    }

    @objc private func activate(_ sender: NSMenuItem) { actions[sender.tag]?() }
}

private struct NativeMenuAnchor: NSViewRepresentable {
    let presenter: NativeMenuPresenter
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        presenter.anchor = view
        return view
    }
    func updateNSView(_ view: NSView, context: Context) { presenter.anchor = view }
}

private struct SystemGlassButtonStyle: ViewModifier {
    var iconOnly = false
    @ViewBuilder func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            // https://developer.apple.com/documentation/swiftui/glassbuttonstyle
            if iconOnly {
                content.buttonStyle(.glass).buttonBorderShape(.circle).controlSize(.regular)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            content.buttonStyle(.bordered)
        }
        #else
        content.buttonStyle(.bordered)
        #endif
    }
}

/// A borderless native hit area sits on the single shared tile surface. CPU
/// and GPU must never draw independent button bezels inside that surface.
private struct NativeHardwareButton: NSViewRepresentable {
    let title: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.target = context.coordinator
        button.action = #selector(Coordinator.activate)
        button.bezelStyle = .rounded
        button.isBordered = false
        button.controlSize = .regular
        button.setButtonType(.momentaryPushIn)
        button.imagePosition = .imageOnly
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
        button.title = ""
        button.showsBorderOnlyWhileMouseInside = false
        button.isEnabled = isEnabled
        button.toolTip = title
        button.setAccessibilityLabel(title)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSButton, context: Context) -> CGSize? {
        let size = nsView.intrinsicContentSize
        return CGSize(width: proposal.width ?? max(0, size.width), height: proposal.height ?? max(0, size.height))
    }

    final class Coordinator: NSObject {
        var action: (() -> Void)?
        @objc func activate() { action?() }
    }
}
