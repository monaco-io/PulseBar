/// Separates the user's open/close intent from AppKit's animated visibility.
/// An outside-click callback belongs only to the presentation that installed it.
public struct StatusItemInteraction {
    public private(set) var isPresented = false
    public private(set) var generation: UInt64 = 0

    public init() {}

    @discardableResult
    public mutating func present() -> UInt64 {
        generation &+= 1
        isPresented = true
        return generation
    }

    public mutating func dismiss() { isPresented = false }

    public func acceptsDismissal(from generation: UInt64, isInsideStatusItem: Bool,
                                 isTrackingMenu: Bool) -> Bool {
        isPresented && generation == self.generation && !isInsideStatusItem && !isTrackingMenu
    }
}
