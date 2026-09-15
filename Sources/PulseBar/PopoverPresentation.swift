import AppKit
import Combine
import SpeedCore

final class PopoverPresentation: ObservableObject {
    @Published private(set) var navigation = PanelNavigation()
    @Published private(set) var height: CGFloat = 660
    @Published private(set) var availableWidth: CGFloat = 1280
    var onNavigate: (() -> Void)?

    var route: PanelRoute { navigation.route }
    var usesInlineDetails: Bool { PanelLayout.usesInlineDetails(availableWidth: availableWidth) }
    var overviewWidth: CGFloat { min(PanelLayout.overviewWidth, availableWidth) }

    var contentSize: NSSize {
        NSSize(width: PanelLayout.width(for: route, availableWidth: availableWidth), height: height)
    }

    func prepare(on screen: NSScreen?) {
        availableWidth = screen?.visibleFrame.width ?? 1280
        height = min(660, max(280, screen?.visibleFrame.height ?? 684) - 24)
        navigate(.overview)
    }

    func navigate(_ route: PanelRoute) {
        guard route != navigation.route else { return }
        navigation.show(route)
        onNavigate?()
    }
}
