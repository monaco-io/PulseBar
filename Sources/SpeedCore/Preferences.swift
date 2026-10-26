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

/// Menu-bar numbers can select either direction without changing a monitor's sampling.
public enum MenuBarNumberMetric: String, CaseIterable {
    case cpu, memory, diskRead, diskWrite, upload, download

    public var titleKey: TextKey {
        switch self {
        case .cpu: return .cpu
        case .memory: return .memory
        case .diskRead: return .diskRead
        case .diskWrite: return .diskWrite
        case .upload: return .upload
        case .download: return .download
        }
    }

    public var monitorMetric: MonitorMetric {
        switch self {
        case .cpu: return .cpu
        case .memory: return .memory
        case .diskRead, .diskWrite: return .disk
        case .upload, .download: return .network
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
    case outer, middle, inner

    public var titleKey: TextKey {
        switch self {
        case .outer: return .menuOuterRing
        case .middle: return .menuMiddleRing
        case .inner: return .menuInnerRing
        }
    }
}

public struct MenuBarSelection: Equatable {
    /// Numeric choices are retained when the whole numeric section is hidden.
    public private(set) var metrics: Set<MenuBarNumberMetric>
    public private(set) var showsRings: Bool
    public private(set) var showsNumbers: Bool
    public private(set) var outerRing: MenuBarRingMetric
    public private(set) var middleRing: MenuBarRingMetric
    public private(set) var innerRing: MenuBarRingMetric
    public var orderedMetrics: [MenuBarNumberMetric] { MenuBarNumberMetric.allCases.filter(metrics.contains) }
    public var visibleNumberMetrics: [MenuBarNumberMetric] { showsNumbers ? orderedMetrics : [] }
    public var ringMetrics: [MenuBarRingMetric] { showsRings ? [outerRing, middleRing, innerRing] : [] }

    public init(metrics: Set<MenuBarNumberMetric> = [.diskRead, .diskWrite, .upload, .download], showsRings: Bool = true,
                showsNumbers: Bool = true, outerRing: MenuBarRingMetric = .storage,
                middleRing: MenuBarRingMetric = .memory, innerRing: MenuBarRingMetric = .cpu) {
        self.metrics = metrics.isEmpty ? [.upload, .download] : metrics
        self.showsRings = showsRings || !showsNumbers
        self.showsNumbers = showsNumbers
        self.outerRing = outerRing
        self.middleRing = middleRing
        self.innerRing = innerRing
    }

    public func contains(_ metric: MenuBarNumberMetric) -> Bool { metrics.contains(metric) }
    public func showsNumber(_ metric: MenuBarNumberMetric) -> Bool { showsNumbers && contains(metric) }
    public func canToggle(_ metric: MenuBarNumberMetric) -> Bool { !contains(metric) || metrics.count > 1 }
    public var canHideRings: Bool { showsNumbers }
    public var canHideNumbers: Bool { showsRings }

    public func ringMetric(at position: MenuBarRingPosition) -> MenuBarRingMetric {
        switch position {
        case .outer: return outerRing
        case .middle: return middleRing
        case .inner: return innerRing
        }
    }

    public mutating func setRingMetric(_ metric: MenuBarRingMetric, at position: MenuBarRingPosition) {
        switch position {
        case .outer: outerRing = metric
        case .middle: middleRing = metric
        case .inner: innerRing = metric
        }
    }

    public mutating func setRingsVisible(_ visible: Bool) {
        if visible || canHideRings { showsRings = visible }
    }

    public mutating func setNumbersVisible(_ visible: Bool) {
        if visible || canHideNumbers { showsNumbers = visible }
    }

    public mutating func set(_ metric: MenuBarNumberMetric, visible: Bool) {
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
    @Published public var networkSpeedMode: SpeedDisplayMode {
        didSet { defaults.set(networkSpeedMode.rawValue, forKey: "networkSpeedDisplayMode") }
    }
    @Published public var diskSpeedMode: SpeedDisplayMode {
        didSet { defaults.set(diskSpeedMode.rawValue, forKey: "diskSpeedDisplayMode") }
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
        let displayVersion = defaults.integer(forKey: "menuBarDisplayVersion")
        if displayVersion >= 2 {
            let metrics = Self.numberMetrics(from: defaults.stringArray(forKey: "menuBarNumberMetrics"))
            var outer = defaults.string(forKey: "menuBarOuterRingMetric").flatMap(MenuBarRingMetric.init(rawValue:))
                ?? (displayVersion >= 3 ? .storage : .cpu)
            var inner = defaults.string(forKey: "menuBarInnerRingMetric").flatMap(MenuBarRingMetric.init(rawValue:))
                ?? (displayVersion >= 3 ? .cpu : .memory)
            let middle: MenuBarRingMetric
            if displayVersion >= 3 {
                middle = defaults.string(forKey: "menuBarMiddleRingMetric").flatMap(MenuBarRingMetric.init(rawValue:)) ?? .memory
            } else if inner == .memory && (outer == .cpu || outer == .storage) {
                // Both the default CPU/MEM pair and the storage/MEM pair restore the classic layout.
                outer = .storage; middle = .memory; inner = .cpu
            } else {
                // Keep explicitly customized outer/inner rings; add a distinct middle metric.
                middle = [.memory, .storage, .cpu].first { $0 != outer && $0 != inner } ?? .memory
            }
            selection = MenuBarSelection(metrics: metrics,
                showsRings: defaults.object(forKey: "menuBarShowsRings") as? Bool ?? true,
                showsNumbers: defaults.object(forKey: "menuBarShowsNumbers") as? Bool ?? true,
                outerRing: outer, middleRing: middle, innerRing: inner)
        } else if let stored = defaults.stringArray(forKey: "menuBarMetrics") {
            var legacy = Set(stored.compactMap(MonitorMetric.init(rawValue:)))
            if legacy.isEmpty { legacy = [.network] }
            let numbers = legacy.intersection([.disk, .network])
            let numberKeys = numbers.isEmpty ? ["disk", "network"] : numbers.map(\.rawValue)
            selection = MenuBarSelection(metrics: Self.numberMetrics(from: numberKeys),
                showsRings: !legacy.subtracting([.network]).isEmpty, showsNumbers: !numbers.isEmpty)
        } else { selection = MenuBarSelection() }
        language = AppLanguage(rawValue: defaults.string(forKey: "appLanguage") ?? "") ?? .system
        networkSpeedMode = defaults.string(forKey: "networkSpeedDisplayMode").flatMap(SpeedDisplayMode.init(rawValue:)) ?? .automatic
        diskSpeedMode = defaults.string(forKey: "diskSpeedDisplayMode").flatMap(SpeedDisplayMode.init(rawValue:)) ?? .automatic
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

    public func setVisible(_ metric: MenuBarNumberMetric, _ visible: Bool) {
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
        defaults.set(selection.middleRing.rawValue, forKey: "menuBarMiddleRingMetric")
        defaults.set(selection.innerRing.rawValue, forKey: "menuBarInnerRingMetric")
        defaults.set(3, forKey: "menuBarDisplayVersion")
    }

    private static func numberMetrics(from stored: [String]?) -> Set<MenuBarNumberMetric> {
        guard let stored else { return [.diskRead, .diskWrite, .upload, .download] }
        return Set(stored.flatMap { key -> [MenuBarNumberMetric] in
            switch key {
            case "disk": return [.diskRead, .diskWrite]
            case "network": return [.upload, .download]
            default: return MenuBarNumberMetric(rawValue: key).map { [$0] } ?? []
            }
        })
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
