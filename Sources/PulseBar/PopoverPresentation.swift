import AppKit
import Combine
import SpeedCore

final class PopoverPresentation: ObservableObject {
    @Published private(set) var navigation = PanelNavigation()
    @Published private(set) var height: CGFloat = 660
    @Published private(set) var availableWidth: CGFloat = 1280
    private var availableHeight: CGFloat = 844
    var onNavigate: (() -> Void)?

    var route: PanelRoute { navigation.route }
    var usesInlineDetails: Bool { PanelLayout.usesInlineDetails(availableWidth: availableWidth) }
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
        // Hardware sections scroll between the fixed header and navigation.
        // Sensor availability must not resize the panel while it is open.
        height = min(660, max(0, availableHeight - 24))
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
