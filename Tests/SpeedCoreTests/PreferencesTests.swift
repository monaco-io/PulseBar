import Darwin
import Foundation
import Testing
@testable import SpeedCore

struct PreferencesTests {
    @Test func everyVisibilityCombinationKeepsAtLeastOneMetric() {
        let metrics = MonitorMetric.allCases
        for mask in 1..<16 {
            let enabled = Set(metrics.enumerated().compactMap { mask & (1 << $0.offset) != 0 ? $0.element : nil })
            for metric in metrics {
                var selection = MenuBarSelection(metrics: enabled)
                #expect(selection.canToggle(metric) == (enabled.count > 1 || !enabled.contains(metric)))
                selection.set(metric, visible: false)
                #expect(!selection.metrics.isEmpty)
                if enabled.count == 1 { #expect(selection.metrics == enabled) }
                selection.set(metric, visible: true)
                #expect(selection.contains(metric))
            }
        }
    }

    @Test func visibilityLanguageAndRefreshPersistTogether() throws {
        let suite = "NetSpeed.Tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = AppPreferences(defaults: defaults)
        #expect(first.selection.metrics.count == 4)
        #expect(first.language == .system)
        #expect(first.refreshSeconds == 1)
        #expect(first.historySeconds == 3600)
        for metric in [MonitorMetric.cpu, .memory, .disk, .network] { first.setVisible(metric, false) }
        first.language = .english
        first.setRefreshSeconds(17)
        first.setHistorySeconds(300)
        let restored = AppPreferences(defaults: defaults)
        #expect(restored.selection.metrics == [.network])
        #expect(defaults.stringArray(forKey: "menuBarMetrics") == ["network"])
        #expect(restored.language == .english)
        #expect(restored.refreshSeconds == 17)
        #expect(restored.historySeconds == 300)
        restored.setHistorySeconds(100000)
        #expect(AppPreferences(defaults: defaults).historySeconds == 86400)
        #expect(restored.refreshSeconds == 17)
        restored.setRefreshSeconds(0)
        #expect(restored.refreshSeconds == 1)
        restored.setRefreshSeconds(120)
        #expect(AppPreferences(defaults: defaults).refreshSeconds == 60)
    }

    @Test func invalidStoredPreferencesCannotHideTheAppOrStopSampling() throws {
        let suite = "NetSpeed.Tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set([], forKey: "menuBarMetrics")
        defaults.set("unsupported", forKey: "appLanguage")
        defaults.set(-10, forKey: "refreshSeconds")
        defaults.set(-1, forKey: "historySeconds")
        let restored = AppPreferences(defaults: defaults)
        #expect(restored.selection.metrics == [.network])
        #expect(restored.language == .system)
        #expect(restored.refreshSeconds == 1)
        #expect(restored.historySeconds == 1)
        defaults.set(["removed-metric"], forKey: "menuBarMetrics")
        #expect(AppPreferences(defaults: defaults).selection.metrics == [.network])
    }

    @Test func localizedResourcesAreCompleteAndSelectable() {
        for language in [AppLanguage.english, .simplifiedChinese] {
            let localizer = Localizer(language: language)
            for key in TextKey.allCases {
                #expect(!localizer(key).isEmpty)
                #expect(localizer(key) != key.rawValue, "Missing \(language.rawValue): \(key.rawValue)")
            }
        }
        let english = Localizer(language: .english)
        let chinese = Localizer(language: .simplifiedChinese)
        #expect(english(.appTitle) == "PulseBar")
        #expect(chinese(.appTitle) == "脉动")
        #expect(english(.updatingEvery, 10) == "Every 10 s")
        #expect(chinese(.updatingEvery, 10) == "每 10 秒更新")
        #expect(english(.usageChart, "CPU", english.duration(300)) == "CPU usage over the last 5 min, from 0 to 100%")
        #expect(chinese(.usageChart, "CPU", chinese.duration(300)) == "最近5 分钟CPU使用率曲线，范围 0 到 100%")
        #expect(chinese(.secondsAgo, chinese.duration(300)) == "5 分钟前")
        #expect(english.duration(3600) == "1 h")
        #expect(chinese.duration(125) == "125 秒")
        #expect(english(.hoursUnit) == "hour")
        #expect(chinese(.hoursUnit) == "小时")
        #expect(english(.settings) == "Settings")
        #expect(chinese(.settings) == "设置")
        #expect(english(.launchAtLogin) == "Launch at login")
        #expect(chinese(.launchAtLogin) == "开机启动")
        #expect(chinese(.loginItemFailed, "error") == "无法更改开机启动：error")
        let used = TrafficFormatter.amount(21_000_120_000, unitFor: 25_769_800_000)
        let total = TrafficFormatter.amount(25_769_800_000)
        #expect(english(.memoryRatio, used.value, total.value, total.unit) == "21.0 / 25.8 GB")
        #expect(chinese(.memoryRatio, used.value, total.value, total.unit) == "21.0 / 25.8 GB")
        #expect(english(.showInMenuBar, english(.memory)) == "Show Memory in menu bar")
    }

    @Test func languageFollowsPreferencesWithAnEnglishFallback() {
        #expect(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN", "en"]) == .simplifiedChinese)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["en-GB", "zh-Hans"]) == .english)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["fr-FR", "zh_CN"]) == .simplifiedChinese)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]) == .english)
        #expect(AppLanguage.system.resolved(preferredLanguages: []) == .english)
        #expect(AppLanguage.english.resolved(preferredLanguages: ["zh-Hans"]) == .english)
    }

    @Test func existingErrorsCanChangeLanguageWithoutBeingReadAgain() {
        let error = SystemReadError(metric: .diskIO, code: KERN_FAILURE)
        let english = Localizer(language: .english)
        let chinese = Localizer(language: .simplifiedChinese)
        #expect(english.describe(error)?.hasPrefix("Unable to read Disk I/O:") == true)
        #expect(chinese.describe(error)?.hasPrefix("无法读取磁盘 I/O：") == true)
        #expect(english.describe(InterfaceReadError(code: EPERM))?.hasPrefix("Unable to read network counters:") == true)
        #expect(chinese.describe(InterfaceReadError(code: EPERM))?.hasPrefix("无法读取网卡统计：") == true)
    }
}
