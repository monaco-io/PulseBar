import Foundation
import CoreGraphics
import Testing
@testable import SpeedCore

struct PanelPlacementTests {
    @Test func independentDetailsPreferTheRightThenLeft() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let source = CGRect(x: 100, y: 200, width: 452, height: 600)
        let size = CGSize(width: 452, height: 710)
        let right = PanelPlacement.detailFrame(size: size, beside: source, visibleFrame: screen)
        #expect(right.minX == source.maxX + 12)
        #expect(right.maxY == source.maxY)
        let edgeSource = CGRect(x: 940, y: 200, width: 452, height: 600)
        let left = PanelPlacement.detailFrame(size: size, beside: edgeSource, visibleFrame: screen)
        #expect(left.maxX == edgeSource.minX - 12)
        #expect(screen.contains(left))
    }

    @Test func independentDetailsStayInsideSmallAndNegativeDisplays() {
        for screen in [CGRect(x: 0, y: 0, width: 600, height: 500), CGRect(x: -1600, y: -100, width: 1440, height: 900)] {
            let source = CGRect(x: screen.maxX - 452, y: screen.maxY - 600, width: 452, height: 600)
            let detail = PanelPlacement.detailFrame(size: CGSize(width: 452, height: 760), beside: source, visibleFrame: screen)
            #expect(screen.contains(detail))
        }
    }

    @Test func overviewAndDetailsKeepTheSameMenuBarAnchor() {
        let screen = CGRect(x: 63, y: 0, width: 2177, height: 1230)
        let anchor = CGRect(x: 1290, y: 1234, width: 264, height: 22)
        let overview = PanelPlacement.frame(size: CGSize(width: PanelLayout.width(for: .overview, availableWidth: screen.width), height: 720), anchor: anchor, visibleFrame: screen)
        let details = PanelPlacement.frame(size: CGSize(width: PanelLayout.width(for: .memoryDetails, availableWidth: screen.width), height: 720), anchor: anchor, visibleFrame: screen)
        #expect(overview.maxX == anchor.maxX)
        #expect(details.minX == overview.minX)
        #expect(details.maxY == overview.maxY)
    }

    @Test func everyRouteKeepsOverviewOriginAndTop() {
        let screen = CGRect(x: 63, y: 0, width: 2177, height: 1230)
        let anchor = CGRect(x: 1290, y: 1234, width: 264, height: 22)
        let overview = PanelPlacement.frame(size: CGSize(width: PanelLayout.overviewWidth, height: 720), anchor: anchor, visibleFrame: screen)
        for route in PanelRoute.allCases {
            let width = PanelLayout.width(for: route, availableWidth: screen.width)
            let frame = PanelPlacement.frame(size: CGSize(width: width, height: 720), anchor: anchor, visibleFrame: screen)
            #expect(frame.origin == overview.origin)
            #expect(screen.contains(frame))
        }
    }

    @Test func displayEdgesAndNegativeOriginsStayVisible() {
        for screen in [CGRect(x: 0, y: 0, width: 1280, height: 770), CGRect(x: -1920, y: -200, width: 1920, height: 1050)] {
            for x in [screen.minX, screen.maxX - 100] {
                for width in [320.0, 452.0] {
                    let frame = PanelPlacement.frame(size: CGSize(width: width, height: 640), anchor: CGRect(x: x, y: screen.maxY, width: 100, height: 22), visibleFrame: screen)
                    #expect(screen.contains(frame))
                    #expect(frame.maxY == screen.maxY)
                }
            }
        }
    }
}
