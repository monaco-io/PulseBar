import CoreGraphics
import Testing
@testable import SpeedCore

struct PanelNavigationTests {
    @Test func shortContentFitsAndExpandedContentStopsAtEightyPercent() {
        #expect(PanelLayout.fittedHeight(contentHeight: 314.2, availableHeight: 1000) == 315)
        #expect(PanelLayout.fittedHeight(contentHeight: 1400, availableHeight: 1000) == 800)
        #expect(PanelLayout.fittedHeight(contentHeight: 280, availableHeight: 1000) == 280)
    }

    @Test func fittingRespectsShortScreensAndPixelRounding() {
        #expect(PanelLayout.fittedHeight(contentHeight: 600, availableHeight: 683) == 546)
        #expect(PanelLayout.fittedHeight(contentHeight: 600, availableHeight: 0) == 0)
        #expect(PanelLayout.fittedHeight(contentHeight: -10, availableHeight: 1000) == 0)
        #expect(PanelLayout.fittedHeight(contentHeight: 500, availableHeight: -1) == 0)
    }

    @Test func selectingTheActiveDestinationDoesNotCloseIt() {
        var navigation = PanelNavigation()
        for route in PanelRoute.allCases {
            navigation.show(route)
            navigation.show(route)
            #expect(navigation.route == route)
        }
    }

    @Test func everyDetailSwitchKeepsTheSameWidth() {
        var navigation = PanelNavigation()
        for route in [PanelRoute.cpuDetails, .memoryDetails, .networkDetails, .storageDetails, .gpuDetails,
                      .batteryDetails, .settings, .cpuApps, .memoryApps, .events, .settings] {
            navigation.show(route)
            #expect(navigation.route.hasDetails)
            #expect(PanelLayout.width(for: navigation.route, availableWidth: 1280) == 452)
        }
        let returnedToOverview = navigation.back()
        #expect(returnedToOverview)
        #expect(PanelLayout.width(for: navigation.route, availableWidth: 1280) == 452)
        let shouldDismiss = !navigation.back()
        #expect(shouldDismiss)
    }

    @Test func narrowScreensKeepNavigationInsideTheWindow() {
        for available: CGFloat in [0, 320, 400, 452, 720, 1280] {
            for route in PanelRoute.allCases {
                let expected: CGFloat = min(452, available)
                #expect(PanelLayout.width(for: route, availableWidth: available) == expected)
            }
        }
        #expect(PanelLayout.width(for: .cpuDetails, availableWidth: -1) == 0)
    }

    @Test func menuNavigationSelectsDetailsWithoutAnIntermediateOverview() {
        var navigation = PanelNavigation()
        navigation.show(.settings)
        navigation.show(.memoryApps)
        #expect(navigation.route == .memoryApps)
        #expect(navigation.route.isApps)
        navigation.show(.events)
        #expect(navigation.route == .events)
        #expect(!navigation.route.isApps)
    }
}
