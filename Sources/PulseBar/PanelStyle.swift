import AppKit
import SwiftUI

struct PanelMaterial: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency { Color(nsColor: .windowBackgroundColor) }
        else { NativePanelMaterial() }
    }
}

private struct NativePanelMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct PanelButtonStyle: ButtonStyle {
    var selected = false
    var tint: Color = .accentColor
    var padding: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        PanelButtonBody(configuration: configuration, selected: selected, tint: tint, padding: padding)
    }
}

struct PanelReveal: ViewModifier {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(x: appeared || reduceMotion ? 0 : 6)
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) { appeared = true }
            }
    }
}

private struct PanelButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let selected: Bool
    let tint: Color
    let padding: CGFloat
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .padding(padding)
            .foregroundStyle(selected ? tint : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? tint.opacity(configuration.isPressed ? 0.22 : 0.13)
                          : Color.primary.opacity(configuration.isPressed ? 0.10 : hovered ? 0.055 : 0))
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(enabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: selected)
            .onHover { hovered = $0 }
    }
}
