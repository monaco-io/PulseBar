import AppKit
import Combine
import SpeedCore

final class PopoverPresentation: ObservableObject {
    @Published private(set) var navigation = PanelNavigation()
    @Published private(set) var height: CGFloat = 600
    @Published var isPinned = false
    @Published private(set) var availableWidth: CGFloat = 1280
    private var availableHeight: CGFloat = 844
    private var preferredContentHeight: CGFloat = 600
    var onNavigate: (() -> Void)?
    var onResize: (() -> Void)?

    var route: PanelRoute { navigation.route }
    var overviewWidth: CGFloat { min(PanelLayout.overviewWidth, availableWidth) }

    var contentSize: NSSize {
        NSSize(width: PanelLayout.width(for: route, availableWidth: availableWidth), height: height)
    }

    func prepare(on screen: NSScreen?) {
        availableWidth = screen?.visibleFrame.width ?? 1280
        availableHeight = screen?.visibleFrame.height ?? 684
        updateHeight()
        navigate(.overview)
    }

    private func updateHeight() {
        height = PanelLayout.fittedHeight(contentHeight: preferredContentHeight, availableHeight: availableHeight)
    }

    func prepareDetail(_ route: PanelRoute, on screen: NSScreen?) {
        availableWidth = screen?.visibleFrame.width ?? 1280
        availableHeight = screen?.visibleFrame.height ?? 684
        // SwiftUI measures the complete content, including expanded events.
        // This initial size is only used until that measurement is available.
        height = PanelLayout.fittedHeight(contentHeight: height, availableHeight: availableHeight)
        navigate(route)
    }

    func fitContentHeight(_ contentHeight: CGFloat, on screen: NSScreen? = nil) {
        preferredContentHeight = contentHeight
        if let screen { availableHeight = screen.visibleFrame.height }
        let fitted = PanelLayout.fittedHeight(contentHeight: contentHeight, availableHeight: availableHeight)
        guard fitted > 0, abs(height - fitted) >= 1 else { return }
        height = fitted
        onResize?()
    }

    #if DEBUG
    func setPreviewHeight(_ value: CGFloat) { height = value }
    func setPreviewWidth(_ value: CGFloat) { availableWidth = value }
    #endif

    func navigate(_ route: PanelRoute) {
        guard route != navigation.route else { return }
        navigation.show(route)
        onNavigate?()
    }
}
