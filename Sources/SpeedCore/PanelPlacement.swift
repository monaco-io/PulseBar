import Foundation
import CoreGraphics

/// Keep the overview anchored and position independent details inside the display.
public enum PanelPlacement {
    public static func frame(size: CGSize, anchor: CGRect, visibleFrame: CGRect) -> CGRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        let right = min(visibleFrame.maxX, max(visibleFrame.minX + width, anchor.maxX))
        return CGRect(
            x: max(visibleFrame.minX, right - width),
            y: max(visibleFrame.minY, min(anchor.minY, visibleFrame.maxY) - height),
            width: width, height: height)
    }

    public static func detailFrame(size: CGSize, beside source: CGRect, visibleFrame: CGRect) -> CGRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        let gap: CGFloat = 12
        let right = source.maxX + gap
        let left = source.minX - gap - width
        let preferredX = right + width <= visibleFrame.maxX ? right : left
        return CGRect(x: max(visibleFrame.minX, min(preferredX, visibleFrame.maxX - width)),
                      y: max(visibleFrame.minY, min(source.maxY, visibleFrame.maxY) - height),
                      width: width, height: height)
    }
}
