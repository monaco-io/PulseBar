import AppKit
import SwiftUI

/// Keep the SwiftUI content inside AppKit's glass contentView. Placing glass
/// behind a sibling hosting view does not provide the same compositing behavior.
final class NativeGlassHostingController<Content: View>: NSViewController {
    private let hosting: NSHostingView<Content>

    init(rootView: Content) {
        hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = []
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(rootView:)") }

    override func loadView() {
        view = NativeGlassContainer(content: hosting)
    }
}

final class NativeGlassContainer: NSView {
    private let content: NSView
    private var surface: NSView?
    private let cornerRadius: CGFloat
    private var shadowBounds: NSRect?
    private(set) var materialName = ""

    init(content: NSView, cornerRadius: CGFloat = 20) {
        self.content = content
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        // The window's composited surface must follow the same outline as its
        // glass; rounding only the child leaves a rectangular window shadow.
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        rebuildSurface()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(content:)") }

    override func layout() {
        super.layout()
        guard let window, shadowBounds != bounds else { return }
        shadowBounds = bounds
        // Transparent windows cache their shadow shape. Refresh it when the
        // content grows or shrinks so old square edges cannot remain visible.
        window.invalidateShadow()
    }

    private func rebuildSurface() {
        content.removeFromSuperview()
        surface?.removeFromSuperview()
        let next: NSView
        // The system material itself responds to Reduce Transparency and
        // contrast settings. Do not replace it with a hand-drawn surface.
        if let glass = makeGlass() {
            next = glass
            materialName = "NSGlassEffectView"
        } else {
            let material = NSVisualEffectView()
            material.material = .popover
            material.blendingMode = .behindWindow
            material.state = .active
            material.addSubview(content)
            next = material
            materialName = "NSVisualEffectView.popover"
        }
        next.identifier = NSUserInterfaceItemIdentifier("PulseBar.panelMaterial")
        if materialName != "NSGlassEffectView" {
            next.wantsLayer = true
            next.layer?.cornerRadius = cornerRadius
            next.layer?.masksToBounds = true
        }
        addSubview(next)
        next.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            next.leadingAnchor.constraint(equalTo: leadingAnchor),
            next.trailingAnchor.constraint(equalTo: trailingAnchor),
            next.topAnchor.constraint(equalTo: topAnchor),
            next.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: next.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: next.trailingAnchor),
            content.topAnchor.constraint(equalTo: next.topAnchor),
            content.bottomAnchor.constraint(equalTo: next.bottomAnchor)
        ])
        surface = next
    }

    private func makeGlass() -> NSView? {
        guard #available(macOS 26.0, *) else { return nil }
        #if compiler(>=6.2)
        let glass = NSGlassEffectView()
        glass.cornerRadius = cornerRadius
        glass.contentView = content
        return glass
        #else
        // The minimum supported toolchain is Swift 6.0 / macOS 15 SDK. Resolve
        // only this public AppKit class and its documented properties at runtime
        // so those builds also use native Liquid Glass on macOS 26 and later.
        guard let glassType = NSClassFromString("NSGlassEffectView") as? NSView.Type else { return nil }
        let glass = glassType.init(frame: .zero)
        guard glass.responds(to: NSSelectorFromString("setContentView:")),
              glass.responds(to: NSSelectorFromString("setCornerRadius:")) else { return nil }
        glass.setValue(cornerRadius, forKey: "cornerRadius")
        glass.setValue(content, forKey: "contentView")
        return glass
        #endif
    }
}
