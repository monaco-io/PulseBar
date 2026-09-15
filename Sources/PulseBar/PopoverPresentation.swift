import AppKit
import Combine

enum InsightPane { case cpu, memory, events }

final class PopoverPresentation: ObservableObject {
    @Published var showsSettings = false
    @Published var insight: InsightPane?
    @Published private(set) var height: CGFloat = 640

    var contentSize: NSSize {
        NSSize(width: showsSettings ? 661 : (insight != nil ? 741 : 400), height: height)
    }

    func prepare(on screen: NSScreen?) {
        showsSettings = false
        insight = nil
        height = min(640, max(280, screen?.visibleFrame.height ?? 664) - 24)
    }

    func toggleInsight(_ pane: InsightPane) {
        showsSettings = false
        insight = insight == pane ? nil : pane
    }
}
