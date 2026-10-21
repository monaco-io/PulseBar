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
        #expect(first.selection.metrics == [.disk, .network])
        #expect(first.selection.ringMetrics == [.cpu, .memory])
        #expect(first.language == .system)
        #expect(first.refreshSeconds == 2)
        #expect(first.historySeconds == 3600)
        #expect(!first.notificationsEnabled)
        #expect(first.notificationCooldownMinutes == 10)
        first.notificationsEnabled = true
        first.notificationCooldownMinutes = 30
        for metric in [MonitorMetric.cpu, .memory, .disk, .network] { first.setVisible(metric, false) }
        first.language = .english
        first.setRefreshSeconds(17)
        first.setHistorySeconds(300)
        let restored = AppPreferences(defaults: defaults)
        #expect(restored.selection.metrics == [.network])
        #expect(defaults.stringArray(forKey: "menuBarNumberMetrics") == ["network"])
        #expect(restored.language == .english)
        #expect(restored.refreshSeconds == 17)
        #expect(restored.historySeconds == 300)
        #expect(restored.notificationsEnabled)
        #expect(restored.notificationCooldownMinutes == 30)
        restored.setHistorySeconds(100000)
        #expect(AppPreferences(defaults: defaults).historySeconds == 86400)
        #expect(restored.refreshSeconds == 17)
        restored.setRefreshSeconds(0)
        #expect(restored.refreshSeconds == 1)
        restored.setRefreshSeconds(120)
        #expect(AppPreferences(defaults: defaults).refreshSeconds == 60)
    }

    @Test func ringsAndNumbersPersistIndependentlyWithoutLosingChoices() throws {
        let suite = "PulseBar.Display.Tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = AppPreferences(defaults: defaults)
        first.setRingMetric(.storage, at: .outer)
        first.setRingMetric(.gpu, at: .inner)
        first.setVisible(.cpu, true)
        first.setNumbersVisible(false)
        let restored = AppPreferences(defaults: defaults)
        #expect(restored.selection.ringMetrics == [.storage, .gpu])
        #expect(restored.selection.visibleNumberMetrics.isEmpty)
        #expect(restored.selection.metrics == [.cpu, .disk, .network])
        restored.setRingsVisible(false)
        #expect(restored.selection.showsRings) // Never remove the final way to open the app.
        restored.setNumbersVisible(true)
        restored.setRingsVisible(false)
        let numbersOnly = AppPreferences(defaults: defaults)
        #expect(numbersOnly.selection.ringMetrics.isEmpty)
        #expect(numbersOnly.selection.visibleNumberMetrics == [.cpu, .disk, .network])
        numbersOnly.setNumbersVisible(false)
        #expect(numbersOnly.selection.showsNumbers)
        numbersOnly.setRingsVisible(true)
        #expect(numbersOnly.selection.ringMetrics == [.storage, .gpu])
        numbersOnly.setRingMetric(.battery, at: .outer)
        numbersOnly.setRingMetric(.battery, at: .inner)
        #expect(AppPreferences(defaults: defaults).selection.ringMetrics == [.battery, .battery])
    }

    @Test func legacyCombinedVisibilityMigratesWithoutInventingNumericCPUOrMemory() throws {
        let metrics = MonitorMetric.allCases
        for mask in 0..<16 {
            let suite = "PulseBar.Migration.Tests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            var old = Set(metrics.enumerated().compactMap { mask & (1 << $0.offset) != 0 ? $0.element : nil })
            defaults.set(old.map(\.rawValue), forKey: "menuBarMetrics")
            if old.isEmpty { old = [.network] }
            let restored = AppPreferences(defaults: defaults)
            #expect(restored.selection.showsRings == !old.subtracting([.network]).isEmpty)
            #expect(Set(restored.selection.visibleNumberMetrics) == old.intersection([.disk, .network]))
            #expect(restored.selection.outerRing == .cpu)
            #expect(restored.selection.innerRing == .memory)
            #expect(restored.selection == AppPreferences(defaults: defaults).selection)
        }
    }

    @Test func corruptNewPreferencesCannotHideBothSections() throws {
        let suite = "PulseBar.CorruptDisplay.Tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(2, forKey: "menuBarDisplayVersion")
        defaults.set(false, forKey: "menuBarShowsRings")
        defaults.set(false, forKey: "menuBarShowsNumbers")
        defaults.set(["removed"], forKey: "menuBarNumberMetrics")
        defaults.set("network", forKey: "menuBarOuterRingMetric")
        defaults.set("unknown", forKey: "menuBarInnerRingMetric")
        let restored = AppPreferences(defaults: defaults)
        #expect(restored.selection.showsRings)
        #expect(!restored.selection.showsNumbers)
        #expect(restored.selection.ringMetrics == [.cpu, .memory])
        restored.setNumbersVisible(true)
        #expect(restored.selection.visibleNumberMetrics == [.network])
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
