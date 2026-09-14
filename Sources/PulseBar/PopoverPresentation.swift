import AppKit
import Combine

final class PopoverPresentation: ObservableObject {
    @Published var showsSettings = false
    @Published private(set) var height: CGFloat = 560

    var contentSize: NSSize {
        NSSize(width: showsSettings ? 661 : 400, height: height)
    }

    func prepare(on screen: NSScreen?) {
        showsSettings = false
        height = min(560, max(280, screen?.visibleFrame.height ?? 584) - 24)
    }
}
