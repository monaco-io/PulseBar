import Testing
@testable import SpeedCore

struct StatusItemInteractionTests {
    @Test func delayedOutsideClickCannotCloseAReopenedPanel() {
        var state = StatusItemInteraction()
        let oldSession = state.present()
        state.dismiss()
        let currentSession = state.present()
        #expect(!state.acceptsDismissal(from: oldSession, isInsideStatusItem: false, isTrackingMenu: false))
        #expect(state.isPresented)
        #expect(state.acceptsDismissal(from: currentSession, isInsideStatusItem: false, isTrackingMenu: false))
    }

    @Test func statusPressAndNativeMenusAreNotOutsideClicks() {
        var state = StatusItemInteraction()
        let session = state.present()
        #expect(!state.acceptsDismissal(from: session, isInsideStatusItem: true, isTrackingMenu: false))
        #expect(!state.acceptsDismissal(from: session, isInsideStatusItem: false, isTrackingMenu: true))
        state.dismiss()
        #expect(!state.acceptsDismissal(from: session, isInsideStatusItem: false, isTrackingMenu: false))
    }

    @Test func repeatedCloseAndReopenDoNotDependOnWindowAnimation() {
        var state = StatusItemInteraction()
        for _ in 0..<20 {
            let session = state.present()
            #expect(state.isPresented)
            state.dismiss()
            state.dismiss()
            #expect(!state.isPresented)
            #expect(!state.acceptsDismissal(from: session, isInsideStatusItem: false, isTrackingMenu: false))
        }
    }
}
