import Foundation
import ServiceManagement
import Testing
@testable import SpeedCore

private final class FakeLoginItemService: LoginItemService {
    var status: SMAppService.Status = .notRegistered
    var registeredStatus: SMAppService.Status = .enabled
    var registerError: Error?
    var unregisterError: Error?
    var registrations = 0
    var removals = 0

    func register() throws {
        registrations += 1
        if let registerError { throw registerError }
        status = registeredStatus
    }

    func unregister() throws {
        removals += 1
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }
}

struct LoginItemTests {
    @Test func readsExistingSystemPreferenceWithoutChangingIt() {
        let service = FakeLoginItemService()
        service.status = .enabled
        let controller = LoginItemController(service: service)
        #expect(controller.isEnabled)
        #expect(service.registrations == 0)
        #expect(service.removals == 0)
    }

    @Test func enablingAndDisablingUseActualSystemState() {
        let service = FakeLoginItemService()
        let controller = LoginItemController(service: service)
        #expect(!controller.isRegistered)
        controller.setEnabled(true)
        controller.setEnabled(true)
        #expect(controller.isEnabled)
        #expect(service.registrations == 1)
        controller.setEnabled(false)
        controller.setEnabled(false)
        #expect(!controller.isRegistered)
        #expect(service.removals == 1)
    }

    @Test func pendingApprovalIsRegisteredButNotActiveAndCanBeCancelled() {
        let service = FakeLoginItemService()
        service.registeredStatus = .requiresApproval
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        #expect(controller.needsApproval)
        #expect(controller.isRegistered)
        #expect(!controller.isEnabled)
        controller.setEnabled(true)
        #expect(service.registrations == 1)
        controller.setEnabled(false)
        #expect(!controller.isRegistered)
        #expect(!controller.needsApproval)
    }

    @Test func failedRequestsKeepTheRealStateAndExposeAnError() {
        let failure = NSError(domain: "LoginItemTests", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Request denied"])
        let service = FakeLoginItemService()
        let controller = LoginItemController(service: service)
        service.registerError = failure
        controller.setEnabled(true)
        #expect(!controller.isEnabled)
        #expect(controller.lastError == "Request denied")
        service.registerError = nil
        controller.setEnabled(true)
        #expect(controller.isEnabled)
        #expect(controller.lastError == nil)
        service.unregisterError = failure
        controller.setEnabled(false)
        #expect(controller.isEnabled)
        #expect(controller.lastError == "Request denied")
    }

    @Test func externalSystemSettingsChangesRefreshWithoutRegisteringAgain() {
        let service = FakeLoginItemService()
        service.status = .enabled
        let controller = LoginItemController(service: service)
        service.status = .requiresApproval
        controller.refresh()
        #expect(controller.needsApproval)
        #expect(!controller.isEnabled)
        service.status = .notRegistered
        controller.refresh()
        #expect(!controller.isRegistered)
        #expect(service.registrations == 0)
        #expect(service.removals == 0)
    }
}
