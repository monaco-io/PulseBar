import AppKit
import Combine
import SpeedCore

final class PopoverPresentation: ObservableObject {
    @Published private(set) var navigation = PanelNavigation()
    @Published private(set) var height: CGFloat = 660
    @Published private(set) var availableWidth: CGFloat = 1280
    private var availableHeight: CGFloat = 684
    private var temperatureCount = 0
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

    func setTemperatureCount(_ count: Int) {
        guard temperatureCount != count else { return }
        temperatureCount = count
        updateHeight()
        onNavigate?()
    }

    private func updateHeight() {
        let rows = CGFloat((temperatureCount + 1) / 2)
        let extra = temperatureCount == 0 ? 0 : 24 + rows * 16
        height = min(660 + extra, max(280, availableHeight) - 24)
    }

    func navigate(_ route: PanelRoute) {
        guard route != navigation.route else { return }
        navigation.show(route)
        onNavigate?()
    }
}
