import Foundation
import CoreGraphics
import Testing
@testable import SpeedCore

struct PanelPlacementTests {
    @Test func overviewAlignsWithAnchorAndDetailsExtendFromItsOrigin() {
        let screen = CGRect(x: 63, y: 0, width: 2177, height: 1230)
        let anchor = CGRect(x: 1290, y: 1234, width: 264, height: 22)
        let overview = PanelPlacement.frame(size: CGSize(width: 620, height: 660), anchor: anchor, visibleFrame: screen)
        let details = PanelPlacement.frame(size: CGSize(width: 941, height: 660), anchor: anchor, visibleFrame: screen)
        #expect(overview.maxX == anchor.maxX)
        #expect(details.minX == overview.minX)
        #expect(details.maxY == overview.maxY)
    }

    @Test func sidebarsKeepOverviewOriginAndTop() {
        let screen = CGRect(x: 63, y: 0, width: 2177, height: 1230)
        let anchor = CGRect(x: 1290, y: 1234, width: 264, height: 22)
        let overview = PanelPlacement.frame(size: CGSize(width: 620, height: 660), anchor: anchor, visibleFrame: screen)
        for width in [941.0, 941.0, 620.0, 941.0, 620.0] {
            let frame = PanelPlacement.frame(size: CGSize(width: width, height: 660), anchor: anchor, visibleFrame: screen)
            #expect(frame.origin == overview.origin)
            #expect(screen.contains(frame))
        }
    }

    @Test func displayEdgesAndNegativeOriginsStayVisible() {
        for screen in [CGRect(x: 0, y: 0, width: 1280, height: 770), CGRect(x: -1920, y: -200, width: 1920, height: 1050)] {
            for x in [screen.minX, screen.maxX - 100] {
                for width in [620.0, 941.0] {
                    let frame = PanelPlacement.frame(size: CGSize(width: width, height: 640), anchor: CGRect(x: x, y: screen.maxY, width: 100, height: 22), visibleFrame: screen)
                    #expect(screen.contains(frame))
                    #expect(frame.maxY == screen.maxY)
                }
            }
        }
    }
}
