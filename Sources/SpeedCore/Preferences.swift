import Combine
import Foundation

public enum MonitorMetric: String, CaseIterable {
    case cpu, memory, disk, network

    public var titleKey: TextKey {
        switch self {
        case .cpu: return .cpu
        case .memory: return .memory
        case .disk: return .diskIO
        case .network: return .network
        }
    }
}

public struct MenuBarSelection: Equatable {
    public private(set) var metrics: Set<MonitorMetric>
    public var orderedMetrics: [MonitorMetric] { MonitorMetric.allCases.filter(metrics.contains) }

    public init(metrics: Set<MonitorMetric> = Set(MonitorMetric.allCases)) {
        self.metrics = metrics.isEmpty ? [.network] : metrics
    }

    public func contains(_ metric: MonitorMetric) -> Bool { metrics.contains(metric) }
    public func canToggle(_ metric: MonitorMetric) -> Bool { !contains(metric) || metrics.count > 1 }

    public mutating func set(_ metric: MonitorMetric, visible: Bool) {
        if visible { metrics.insert(metric) }
        else if metrics.count > 1 { metrics.remove(metric) }
    }
}

public enum RefreshInterval {
    public static let range = 1...60
    public static func normalized(_ seconds: Int) -> Int { min(range.upperBound, max(range.lowerBound, seconds)) }
}

/// A cadence change can straddle one sample from the old timer. Accept that
/// transition, then apply the new stall threshold to subsequent intervals.
struct SamplingWindow {
    private var currentGap: TimeInterval = 5
    private var nextGap: TimeInterval = 5

    mutating func configure(seconds: Int) {
        nextGap = max(5, Double(RefreshInterval.normalized(seconds)) * 1.5)
        currentGap = max(currentGap, nextGap)
    }

    mutating func accepts(_ elapsed: TimeInterval) -> Bool {
        defer { currentGap = nextGap }
        return elapsed <= currentGap
    }
}

public final class AppPreferences: ObservableObject {
    @Published public private(set) var selection: MenuBarSelection
    @Published public var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "appLanguage") }
    }
    @Published public private(set) var refreshSeconds: Int
    @Published public private(set) var historySeconds: Int
    @Published public var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published public var notificationCooldownMinutes: Int {
        didSet { defaults.set(notificationCooldownMinutes, forKey: "notificationCooldownMinutes") }
    }
    private let defaults: UserDefaults
    public var localizer: Localizer { Localizer(language: language) }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.stringArray(forKey: "menuBarMetrics") {
            selection = MenuBarSelection(metrics: Set(stored.compactMap(MonitorMetric.init(rawValue:))))
        } else { selection = MenuBarSelection() }
        language = AppLanguage(rawValue: defaults.string(forKey: "appLanguage") ?? "") ?? .system
        refreshSeconds = defaults.object(forKey: "refreshSeconds") == nil
            ? 2 : RefreshInterval.normalized(defaults.integer(forKey: "refreshSeconds"))
        historySeconds = defaults.object(forKey: "historySeconds") == nil
            ? HistoryWindow.defaultSeconds : HistoryWindow.normalized(defaults.integer(forKey: "historySeconds"))
        notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        let cooldown = defaults.object(forKey: "notificationCooldownMinutes") == nil
            ? 10 : defaults.integer(forKey: "notificationCooldownMinutes")
        notificationCooldownMinutes = min(60, max(1, cooldown))
    }

    public func setVisible(_ metric: MonitorMetric, _ visible: Bool) {
        var updated = selection
        updated.set(metric, visible: visible)
        guard updated != selection else { return }
        selection = updated
        defaults.set(updated.orderedMetrics.map(\.rawValue), forKey: "menuBarMetrics")
    }

    public func setRefreshSeconds(_ seconds: Int) {
        let value = RefreshInterval.normalized(seconds)
        guard value != refreshSeconds else { return }
        refreshSeconds = value
        defaults.set(value, forKey: "refreshSeconds")
    }

    public func setHistorySeconds(_ seconds: Int) {
        let value = HistoryWindow.normalized(seconds)
        guard value != historySeconds else { return }
        historySeconds = value
        defaults.set(value, forKey: "historySeconds")
    }
}
