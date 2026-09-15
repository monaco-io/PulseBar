import Foundation
import CoreGraphics

/// Placement in AppKit screen coordinates. Sidebars extend to the right of the
/// original 400-point overview, moving left only when a screen edge requires it.
public enum PanelPlacement {
    public static func frame(size: CGSize, anchor: CGRect, visibleFrame: CGRect) -> CGRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        let right = min(visibleFrame.maxX, max(visibleFrame.minX + 400, anchor.maxX))
        return CGRect(
            x: max(visibleFrame.minX, min(right - 400, visibleFrame.maxX - width)),
            y: max(visibleFrame.minY, min(anchor.minY, visibleFrame.maxY) - height),
            width: width, height: height)
    }
}
