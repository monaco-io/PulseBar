import Combine
import Foundation
import ServiceManagement

public protocol LoginItemService: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// The system is the source of truth; a saved Boolean could disagree with Login Items.
public final class LoginItemController: ObservableObject {
    @Published public private(set) var status: SMAppService.Status
    @Published public private(set) var lastError: String?
    private let service: any LoginItemService

    public init(service: any LoginItemService = SMAppService.mainApp) {
        self.service = service
        status = service.status
    }

    public var isEnabled: Bool { status == .enabled }
    public var needsApproval: Bool { status == .requiresApproval }
    public var isRegistered: Bool { isEnabled || needsApproval }

    public func refresh() {
        let current = service.status
        if status != current { lastError = nil }
        status = current
    }

    public func setEnabled(_ enabled: Bool) {
        refresh()
        lastError = nil
        guard enabled != isRegistered else { return }
        do {
            if enabled { try service.register() }
            else { try service.unregister() }
        } catch {
            lastError = error.localizedDescription
        }
        // A failed request or pending approval must never masquerade as success.
        status = service.status
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
