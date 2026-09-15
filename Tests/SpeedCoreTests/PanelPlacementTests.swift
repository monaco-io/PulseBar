import Foundation
import CoreGraphics
import Testing
@testable import SpeedCore

struct PanelPlacementTests {
    @Test func sidebarsKeepOverviewOriginAndTop() {
        let screen = CGRect(x: 63, y: 0, width: 2177, height: 1230)
        let anchor = CGRect(x: 1290, y: 1234, width: 264, height: 22)
        let overview = PanelPlacement.frame(size: CGSize(width: 400, height: 640), anchor: anchor, visibleFrame: screen)
        for width in [661.0, 741.0, 400.0, 661.0, 400.0] {
            let frame = PanelPlacement.frame(size: CGSize(width: width, height: 640), anchor: anchor, visibleFrame: screen)
            #expect(frame.origin == overview.origin)
            #expect(screen.contains(frame))
        }
    }

    @Test func displayEdgesAndNegativeOriginsStayVisible() {
        for screen in [CGRect(x: 0, y: 0, width: 1280, height: 770), CGRect(x: -1920, y: -200, width: 1920, height: 1050)] {
            for x in [screen.minX, screen.maxX - 100] {
                for width in [400.0, 661.0, 741.0] {
                    let frame = PanelPlacement.frame(size: CGSize(width: width, height: 640), anchor: CGRect(x: x, y: screen.maxY, width: 100, height: 22), visibleFrame: screen)
                    #expect(screen.contains(frame))
                    #expect(frame.maxY == screen.maxY)
                }
            }
        }
    }
}
