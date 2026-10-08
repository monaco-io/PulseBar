import Foundation
import CoreGraphics

/// Placement in AppKit screen coordinates. Sidebars extend to the right of the
/// overview, moving left only when a screen edge requires it.
public enum PanelPlacement {
    public static func frame(size: CGSize, anchor: CGRect, visibleFrame: CGRect) -> CGRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        let overviewWidth = PanelLayout.overviewWidth
        let right = min(visibleFrame.maxX, max(visibleFrame.minX + overviewWidth, anchor.maxX))
        return CGRect(
            x: max(visibleFrame.minX, min(right - overviewWidth, visibleFrame.maxX - width)),
            y: max(visibleFrame.minY, min(anchor.minY, visibleFrame.maxY) - height),
            width: width, height: height)
    }
}
