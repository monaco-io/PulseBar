import AppKit
import QuartzCore

enum NativePanelMotion {
    /// AppKit schedules the animation without holding the action handler in
    /// setFrame(..., animate: true). New input can retarget the same window.
    static func resize(_ window: NSWindow, to frame: NSRect, animated: Bool = true) {
        guard window.frame != frame else { return }
        guard animated, window.isVisible, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            window.setFrame(frame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame, display: true)
        }
    }
}
