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

/// Rings describe percentages, never an arbitrarily scaled transfer rate.
public enum MenuBarRingMetric: String, CaseIterable {
    case cpu, memory, storage, gpu, battery

    public var titleKey: TextKey {
        switch self {
        case .cpu: return .cpu
        case .memory: return .memory
        case .storage: return .storage
        case .gpu: return .gpu
        case .battery: return .batteryCharge
        }
    }
}

public enum MenuBarRingPosition: String, CaseIterable {
    case outer, inner

    public var titleKey: TextKey { self == .outer ? .menuOuterRing : .menuInnerRing }
}

public struct MenuBarSelection: Equatable {
    /// Numeric choices are retained when the whole numeric section is hidden.
    public private(set) var metrics: Set<MonitorMetric>
    public private(set) var showsRings: Bool
    public private(set) var showsNumbers: Bool
    public private(set) var outerRing: MenuBarRingMetric
    public private(set) var innerRing: MenuBarRingMetric
    public var orderedMetrics: [MonitorMetric] { MonitorMetric.allCases.filter(metrics.contains) }
    public var visibleNumberMetrics: [MonitorMetric] { showsNumbers ? orderedMetrics : [] }
    public var ringMetrics: [MenuBarRingMetric] { showsRings ? [outerRing, innerRing] : [] }

    public init(metrics: Set<MonitorMetric> = [.disk, .network], showsRings: Bool = true,
                showsNumbers: Bool = true, outerRing: MenuBarRingMetric = .cpu,
                innerRing: MenuBarRingMetric = .memory) {
        self.metrics = metrics.isEmpty ? [.network] : metrics
        self.showsRings = showsRings || !showsNumbers
        self.showsNumbers = showsNumbers
        self.outerRing = outerRing
        self.innerRing = innerRing
    }

    public func contains(_ metric: MonitorMetric) -> Bool { metrics.contains(metric) }
    public func showsNumber(_ metric: MonitorMetric) -> Bool { showsNumbers && contains(metric) }
    public func canToggle(_ metric: MonitorMetric) -> Bool { !contains(metric) || metrics.count > 1 }
    public var canHideRings: Bool { showsNumbers }
    public var canHideNumbers: Bool { showsRings }

    public func ringMetric(at position: MenuBarRingPosition) -> MenuBarRingMetric {
        position == .outer ? outerRing : innerRing
    }

    public mutating func setRingMetric(_ metric: MenuBarRingMetric, at position: MenuBarRingPosition) {
        if position == .outer { outerRing = metric } else { innerRing = metric }
    }

    public mutating func setRingsVisible(_ visible: Bool) {
        if visible || canHideRings { showsRings = visible }
    }

    public mutating func setNumbersVisible(_ visible: Bool) {
        if visible || canHideNumbers { showsNumbers = visible }
    }

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
        if defaults.integer(forKey: "menuBarDisplayVersion") >= 2 {
            let metrics = defaults.stringArray(forKey: "menuBarNumberMetrics")
                .map { Set($0.compactMap(MonitorMetric.init(rawValue:))) } ?? [.disk, .network]
            selection = MenuBarSelection(metrics: metrics,
                showsRings: defaults.object(forKey: "menuBarShowsRings") as? Bool ?? true,
                showsNumbers: defaults.object(forKey: "menuBarShowsNumbers") as? Bool ?? true,
                outerRing: defaults.string(forKey: "menuBarOuterRingMetric").flatMap(MenuBarRingMetric.init(rawValue:)) ?? .cpu,
                innerRing: defaults.string(forKey: "menuBarInnerRingMetric").flatMap(MenuBarRingMetric.init(rawValue:)) ?? .memory)
        } else if let stored = defaults.stringArray(forKey: "menuBarMetrics") {
            var legacy = Set(stored.compactMap(MonitorMetric.init(rawValue:)))
            if legacy.isEmpty { legacy = [.network] }
            let numbers = legacy.intersection([.disk, .network])
            selection = MenuBarSelection(metrics: numbers.isEmpty ? [.disk, .network] : numbers,
                showsRings: !legacy.subtracting([.network]).isEmpty, showsNumbers: !numbers.isEmpty)
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
        persistSelection()
    }

    public func setVisible(_ metric: MonitorMetric, _ visible: Bool) {
        var updated = selection
        updated.set(metric, visible: visible)
        guard updated != selection else { return }
        selection = updated
        persistSelection()
    }

    public func setRingsVisible(_ visible: Bool) {
        var updated = selection
        updated.setRingsVisible(visible)
        updateSelection(updated)
    }

    public func setNumbersVisible(_ visible: Bool) {
        var updated = selection
        updated.setNumbersVisible(visible)
        updateSelection(updated)
    }

    public func setRingMetric(_ metric: MenuBarRingMetric, at position: MenuBarRingPosition) {
        var updated = selection
        updated.setRingMetric(metric, at: position)
        updateSelection(updated)
    }

    private func updateSelection(_ updated: MenuBarSelection) {
        guard updated != selection else { return }
        selection = updated
        persistSelection()
    }

    private func persistSelection() {
        defaults.set(selection.orderedMetrics.map(\.rawValue), forKey: "menuBarNumberMetrics")
        defaults.set(selection.showsRings, forKey: "menuBarShowsRings")
        defaults.set(selection.showsNumbers, forKey: "menuBarShowsNumbers")
        defaults.set(selection.outerRing.rawValue, forKey: "menuBarOuterRingMetric")
        defaults.set(selection.innerRing.rawValue, forKey: "menuBarInnerRingMetric")
        defaults.set(2, forKey: "menuBarDisplayVersion")
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
