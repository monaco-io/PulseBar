import AppKit
import SpeedCore

final class AppInstance {
    static let bundleIdentifier = "local.apple-widget.NetSpeed"
    static let reopenNotification = Notification.Name(bundleIdentifier + ".reopen")
    static let notificationObject = "user:\(getuid())"
    private var observer: NSObjectProtocol?
    private var pendingReopen = false
    var onReopen: (() -> Void)? {
        didSet {
            if pendingReopen, let onReopen {
                pendingReopen = false
                onReopen()
            }
        }
    }

    init() {
        // Listen before competing for the lock, so a simultaneous launch can
        // request activation even while the winner is still constructing its UI.
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Self.reopenNotification, object: Self.notificationObject, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if let onReopen = self.onReopen { onReopen() }
            else { self.pendingReopen = true }
        }
    }

    deinit {
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
    }

    static func acquire() throws -> SingleInstanceLock? {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        return try SingleInstanceLock.acquire(at: directory.appendingPathComponent("PulseBar/instance.lock"))
    }

    static func reopenExisting() {
        DistributedNotificationCenter.default().postNotificationName(reopenNotification,
            object: notificationObject, userInfo: nil, deliverImmediately: true)
    }
}
