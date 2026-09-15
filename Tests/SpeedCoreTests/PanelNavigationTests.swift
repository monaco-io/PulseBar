import CoreGraphics
import Testing
@testable import SpeedCore

struct PanelNavigationTests {
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
        for route in [PanelRoute.settings, .cpuApps, .memoryApps, .events, .settings] {
            navigation.show(route)
            #expect(navigation.route.hasDetails)
            #expect(PanelLayout.width(for: navigation.route, availableWidth: 1280) == 721)
        }
        let returnedToOverview = navigation.back()
        #expect(returnedToOverview)
        #expect(PanelLayout.width(for: navigation.route, availableWidth: 1280) == 400)
        let shouldDismiss = !navigation.back()
        #expect(shouldDismiss)
    }

    @Test func narrowScreensKeepNavigationInsideTheWindow() {
        for available: CGFloat in [320, 400, 600, 720] {
            #expect(PanelLayout.usesInlineDetails(availableWidth: available))
            for route in PanelRoute.allCases {
                let expected: CGFloat = min(400, available)
                #expect(PanelLayout.width(for: route, availableWidth: available) == expected)
            }
        }
        #expect(!PanelLayout.usesInlineDetails(availableWidth: 721))
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
