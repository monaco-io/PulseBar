import Foundation
import CoreGraphics

public enum PanelRoute: String, CaseIterable, Sendable {
    case overview, cpuApps, memoryApps, events, settings
    case cpuDetails, memoryDetails, networkDetails, storageDetails, gpuDetails, batteryDetails

    public var hasDetails: Bool { self != .overview }
    public var isApps: Bool { self == .cpuApps || self == .memoryApps }
    public var isHardware: Bool {
        switch self {
        case .cpuDetails, .memoryDetails, .networkDetails, .storageDetails, .gpuDetails, .batteryDetails: return true
        default: return false
        }
    }
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
    public static let overviewWidth: CGFloat = 452
    public static let maximumHeightFraction: CGFloat = 0.8

    public static func fittedHeight(contentHeight: CGFloat, availableHeight: CGFloat) -> CGFloat {
        min(max(0, ceil(contentHeight)), max(0, floor(availableHeight * maximumHeightFraction)))
    }

    public static func width(for route: PanelRoute, availableWidth: CGFloat) -> CGFloat {
        // Every route shares the same anchored panel, including hardware detail.
        min(overviewWidth, max(0, availableWidth))
    }
}
