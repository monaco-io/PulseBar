import AppKit
import Combine
import SpeedCore
import UserNotifications

final class EventNotifications: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var requesting = false
    @Published private(set) var denied = false
    @Published private(set) var lastError: String?
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private var cooldown: NotificationCooldown

    override init() {
        cooldown = NotificationCooldown(lastSent: UserDefaults.standard.dictionary(forKey: "eventNotificationLastSent") as? [String: Date] ?? [:])
        super.init()
        center.delegate = self
    }

    func refresh() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async { self?.denied = settings.authorizationStatus == .denied }
        }
    }

    func setEnabled(_ enabled: Bool, preferences: AppPreferences) {
        lastError = nil
        guard enabled else {
            preferences.notificationsEnabled = false
            center.removeAllPendingNotificationRequests()
            return
        }
        requesting = true
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.requesting = false
                self.denied = !granted && error == nil
                self.lastError = error?.localizedDescription
                preferences.notificationsEnabled = granted && error == nil
            }
        }
    }

    func send(_ event: PerformanceEvent, preferences: AppPreferences) {
        guard preferences.notificationsEnabled, cooldown.allows(event, minutes: preferences.notificationCooldownMinutes) else { return }
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self, preferences.notificationsEnabled else { return }
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                    self.denied = settings.authorizationStatus == .denied
                    return
                }
                let l10n = preferences.localizer
                let content = UNMutableNotificationContent()
                content.title = l10n(event.kind.titleKey)
                var body = l10n(.eventDuration, l10n.duration(Int(event.duration)))
                let apps = event.kind == .highCPU ? event.topCPU : event.topMemory
                if let app = apps.first {
                    let value = event.kind == .highCPU ? SystemFormatter.percent(app.cpuPercent) : TrafficFormatter.total(app.memoryBytes)
                    body += "\n" + l10n(.namedValue, app.name, value)
                }
                content.body = body
                content.sound = .default
                content.userInfo = ["eventID": event.id.uuidString]
                let request = UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: nil)
                self.center.add(request) { [weak self] error in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.lastError = error?.localizedDescription
                        if error == nil {
                            self.cooldown.markSent(event)
                            self.defaults.set(self.cooldown.lastSent, forKey: "eventNotificationLastSent")
                        }
                    }
                }
            }
        }
    }

    var onOpenEvent: (() -> Void)?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in self?.onOpenEvent?() }
        completionHandler()
    }

    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") { NSWorkspace.shared.open(url) }
    }
}
