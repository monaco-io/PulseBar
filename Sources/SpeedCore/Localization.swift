import Foundation

public enum AppLanguage: String, CaseIterable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        for language in preferredLanguages {
            let tag = language.lowercased().replacingOccurrences(of: "_", with: "-")
            if tag == "zh" || tag.hasPrefix("zh-") { return .simplifiedChinese }
            if tag == "en" || tag.hasPrefix("en-") { return .english }
        }
        return .english
    }

    public func label(using localizer: Localizer) -> String {
        switch self {
        case .system: return localizer(.followSystem)
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }
}

public enum TextKey: String, CaseIterable {
    case softwareUpdate, checkForUpdates, automaticUpdateChecks, updateHelp, downloadAndReleaseNotes, updateStartFailed
    case appTitle, cpu, memory, diskIO, network, read, write, download, upload
    case updatingEvery, partialError, waiting, retrying, userSystem, memoryRatio
    case cpuHelp, memoryHelp, memoryBreakdown, diskHelp, networkHelp
    case usageLabel, usageChart, speedLabel, diskChart, networkChart
    case sessionIO, sessionTraffic, interfaces, noInterfaces, secondsAgo, now, chartLimit
    case historyHint, historyWindow, historyHelp, durationSeconds, durationMinutes, durationHours
    case reset, resetHelp, quit, language, followSystem
    case settings, settingsExpanded, settingsCollapsed, menuBarItems
    case launchAtLogin, launchAtLoginHelp, loginApprovalRequired, openLoginSettings, loginItemFailed
    case visibilityHint, showInMenuBar, atLeastOne, refresh, secondsUnit, hoursUnit, refreshHelp
    case menuAccessibility, menuHint, namedValue, diskRead, diskWrite, listSeparator
    case readFailed, networkReadFailed, memoryPageSize, diskCounters, diskIdentity, noDisks
    case appRanking, topCPU, topMemory, processCount, rankingHelp, rankingUnavailable, rankingCoverage
    case activityMonitor, activityMonitorFailed, closeDetail
    case memoryPressure, pressureNormal, pressureWarning, pressureCritical, pressureHelp, swap, swapChange, swapHelp
    case averagePeak, average, peak, inspecting, liveHistory, noSample, statisticsHelp, swapTrend
    case events, eventsEmpty, eventsHelp, eventHighCPU, eventMemoryWarning, eventMemoryCritical
    case eventDuration, eventSnapshot, eventSnapshotHelp, eventStoreFailed, eventRules, clearEvents
    case notifications, notificationHelp, notificationCooldown, minutesUnit, notificationDenied, notificationFailed
    case openNotificationSettings, notificationPending, rankingTime
}

public struct Localizer {
    public let language: AppLanguage
    public var locale: Locale { Locale(identifier: language.rawValue) }
    private let bundle: Bundle

    public init(language: AppLanguage, preferredLanguages: [String] = Locale.preferredLanguages) {
        let resolved = language.resolved(preferredLanguages: preferredLanguages)
        self.language = resolved
        let root = Self.resourceBundle
        let resourceName = root.localizations.first {
            $0.caseInsensitiveCompare(resolved.rawValue) == .orderedSame
        } ?? resolved.rawValue
        bundle = root.url(forResource: resourceName, withExtension: "lproj")
            .flatMap { Bundle(url: $0) } ?? root
    }

    // Prefer resources packaged inside the App, so a distributed build never
    // depends on the development checkout's absolute SwiftPM resource path.
    static var resourceBundle: Bundle {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("PulseBar_SpeedCore.bundle"),
           let bundled = Bundle(url: url) { return bundled }
        return .module
    }

    public func callAsFunction(_ key: TextKey, _ arguments: CVarArg...) -> String {
        let template = bundle.localizedString(forKey: key.rawValue, value: nil, table: nil)
        return arguments.isEmpty ? template : String(format: template, locale: locale, arguments: arguments)
    }

    public func duration(_ seconds: Int) -> String {
        if seconds >= 3600 && seconds % 3600 == 0 { return self(.durationHours, seconds / 3600) }
        if seconds >= 60 && seconds % 60 == 0 { return self(.durationMinutes, seconds / 60) }
        return self(.durationSeconds, seconds)
    }

    public func describe(_ error: Error?) -> String? {
        guard let error else { return nil }
        if let error = error as? SystemReadError { return error.description(using: self) }
        if let error = error as? InterfaceReadError { return error.description(using: self) }
        if let error = error as? POSIXReadError { return error.description(using: self) }
        return error.localizedDescription
    }
}
