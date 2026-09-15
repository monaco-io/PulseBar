import Foundation
import CoreGraphics

public enum PanelRoute: String, CaseIterable, Sendable {
    case overview, cpuApps, memoryApps, events, settings

    public var hasDetails: Bool { self != .overview }
    public var isApps: Bool { self == .cpuApps || self == .memoryApps }
}

/// Navigation is one atomic value: switching details never passes through a
/// collapsed overview, and selecting the active tab does not toggle it closed.
public struct PanelNavigation: Equatable, Sendable {
    public private(set) var route: PanelRoute = .overview

    public init() {}

    public mutating func show(_ route: PanelRoute) { self.route = route }

    @discardableResult public mutating func back() -> Bool {
        guard route.hasDetails else { return false }
        route = .overview
        return true
    }
}

public enum PanelLayout {
    public static let overviewWidth: CGFloat = 400
    public static let detailWidth: CGFloat = 320
    public static let expandedWidth: CGFloat = overviewWidth + 1 + detailWidth

    public static func usesInlineDetails(availableWidth: CGFloat) -> Bool {
        availableWidth < expandedWidth
    }

    public static func width(for route: PanelRoute, availableWidth: CGFloat) -> CGFloat {
        let desired = route.hasDetails && !usesInlineDetails(availableWidth: availableWidth)
            ? expandedWidth : overviewWidth
        return min(desired, max(0, availableWidth))
    }
}
