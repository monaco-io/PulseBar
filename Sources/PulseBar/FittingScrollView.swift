import AppKit
import SwiftUI

/// Keep one content tree so expanding events or editing a field never resets
/// its state. AppKit hides scrollers whenever the document fits the viewport.
struct FittingScrollView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .background(AutomaticScrollers())
                .measurePanelHeight(.content)
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

enum PanelMeasuredPart: Hashable { case header, history, content }

struct PanelHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [PanelMeasuredPart: CGFloat] = [:]
    static func reduce(value: inout [PanelMeasuredPart: CGFloat], nextValue: () -> [PanelMeasuredPart: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

extension View {
    func measurePanelHeight(_ part: PanelMeasuredPart) -> some View {
        background(GeometryReader { geometry in
            Color.clear.preference(key: PanelHeightPreferenceKey.self, value: [part: geometry.size.height])
        })
    }
}

private struct AutomaticScrollers: NSViewRepresentable {
    func makeNSView(context: Context) -> ScrollerConfigurationView { ScrollerConfigurationView() }
    func updateNSView(_ view: ScrollerConfigurationView, context: Context) { view.configureWhenAttached() }
}

private final class ScrollerConfigurationView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWhenAttached()
    }

    func configureWhenAttached() {
        DispatchQueue.main.async { [weak self] in
            guard let scroll = self?.enclosingScrollView else { return }
            scroll.autohidesScrollers = true
            scroll.horizontalScrollElasticity = .none
            scroll.verticalScrollElasticity = .none
        }
    }
}
