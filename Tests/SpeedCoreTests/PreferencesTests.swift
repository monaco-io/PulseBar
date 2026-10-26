import Darwin
import Foundation
import Testing
@testable import SpeedCore

struct PreferencesTests {
    @Test func everyVisibilityCombinationKeepsAtLeastOneMetric() {
        let metrics = MenuBarNumberMetric.allCases
        for mask in 1..<(1 << metrics.count) {
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
        #expect(first.selection.metrics == [.diskRead, .diskWrite, .upload, .download])
        #expect(first.selection.ringMetrics == [.storage, .memory, .cpu])
        #expect(first.language == .system)
        #expect(first.refreshSeconds == 2)
        #expect(first.historySeconds == 3600)
        #expect(!first.notificationsEnabled)
        #expect(first.notificationCooldownMinutes == 10)
        first.notificationsEnabled = true
        first.notificationCooldownMinutes = 30
        for metric in MenuBarNumberMetric.allCases { first.setVisible(metric, false) }
        first.language = .english
        first.setRefreshSeconds(17)
        first.setHistorySeconds(300)
        let restored = AppPreferences(defaults: defaults)
        #expect(restored.selection.metrics == [.download])
        #expect(defaults.stringArray(forKey: "menuBarNumberMetrics") == ["download"])
        #expect(defaults.integer(forKey: "menuBarDisplayVersion") == 3)
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

    @Test func networkAndDiskRateModesDefaultToAutomaticAndPersistIndependently() throws {
        let suite = "PulseBar.RateUnits.Tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = AppPreferences(defaults: defaults)
        #expect(first.networkSpeedMode == .automatic)
        #expect(first.diskSpeedMode == .automatic)

        first.networkSpeedMode = .megabytesPerSecond
        let networkFixed = AppPreferences(defaults: defaults)
        #expect(networkFixed.networkSpeedMode == .megabytesPerSecond)
        #expect(networkFixed.diskSpeedMode == .automatic)

        networkFixed.networkSpeedMode = .automatic
        networkFixed.diskSpeedMode = .megabytesPerSecond
        let diskFixed = AppPreferences(defaults: defaults)
        #expect(diskFixed.networkSpeedMode == .automatic)
        #expect(diskFixed.diskSpeedMode == .megabytesPerSecond)
        #expect(diskFixed.selection == first.selection)

        defaults.set("unknown", forKey: "networkSpeedDisplayMode")
        defaults.set("unknown", forKey: "diskSpeedDisplayMode")
        let invalid = AppPreferences(defaults: defaults)
        #expect(invalid.networkSpeedMode == .automatic)
        #expect(invalid.diskSpeedMode == .automatic)
    }

    @Test func ringsAndNumbersPersistIndependentlyWithoutLosingChoices() throws {
        let suite = "PulseBar.Display.Tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = AppPreferences(defaults: defaults)
        first.setRingMetric(.storage, at: .outer)
        first.setRingMetric(.battery, at: .middle)
        first.setRingMetric(.gpu, at: .inner)
        first.setVisible(.cpu, true)
        first.setNumbersVisible(false)
        let restored = AppPreferences(defaults: defaults)
        #expect(restored.selection.ringMetrics == [.storage, .battery, .gpu])
        #expect(restored.selection.visibleNumberMetrics.isEmpty)
        #expect(restored.selection.metrics == [.cpu, .diskRead, .diskWrite, .upload, .download])
        restored.setRingsVisible(false)
        #expect(restored.selection.showsRings) // Never remove the final way to open the app.
        restored.setNumbersVisible(true)
        restored.setRingsVisible(false)
        let numbersOnly = AppPreferences(defaults: defaults)
        #expect(numbersOnly.selection.ringMetrics.isEmpty)
        #expect(numbersOnly.selection.visibleNumberMetrics == [.cpu, .diskRead, .diskWrite, .upload, .download])
        numbersOnly.setNumbersVisible(false)
        #expect(numbersOnly.selection.showsNumbers)
        numbersOnly.setRingsVisible(true)
        #expect(numbersOnly.selection.ringMetrics == [.storage, .battery, .gpu])
        numbersOnly.setRingMetric(.battery, at: .outer)
        numbersOnly.setRingMetric(.battery, at: .inner)
        #expect(AppPreferences(defaults: defaults).selection.ringMetrics == [.battery, .battery, .battery])
    }

    @Test func eachTransferDirectionPersistsIndependently() throws {
        let directions: [MenuBarNumberMetric] = [.diskRead, .diskWrite, .upload, .download]
        for direction in directions {
            let suite = "PulseBar.Directions.Tests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let first = AppPreferences(defaults: defaults)
            for metric in directions where metric != direction { first.setVisible(metric, false) }
            first.setNumbersVisible(false)
            let restored = AppPreferences(defaults: defaults)
            #expect(restored.selection.metrics == [direction])
            #expect(restored.selection.visibleNumberMetrics.isEmpty)
            restored.setNumbersVisible(true)
            #expect(restored.selection.visibleNumberMetrics == [direction])
            #expect(restored.selection.ringMetrics == [.storage, .memory, .cpu])
            restored.setRingsVisible(false)
            restored.setVisible(direction, false)
            #expect(restored.selection.visibleNumberMetrics == [direction])
        }
    }

    @Test func twoRingSettingsExpandPairedNumbersAndRestoreClassicDefaultRings() throws {
        let oldMetrics = MonitorMetric.allCases
        for mask in 0..<(1 << oldMetrics.count) {
            let suite = "PulseBar.TwoRingMigration.Tests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let old = oldMetrics.enumerated().compactMap { mask & (1 << $0.offset) != 0 ? $0.element : nil }
            defaults.set(2, forKey: "menuBarDisplayVersion")
            defaults.set(old.map(\.rawValue), forKey: "menuBarNumberMetrics")
            defaults.set("cpu", forKey: "menuBarOuterRingMetric")
            defaults.set("memory", forKey: "menuBarInnerRingMetric")
            var expected: Set<MenuBarNumberMetric> = []
            if old.contains(.cpu) { expected.insert(.cpu) }
            if old.contains(.memory) { expected.insert(.memory) }
            if old.contains(.disk) { expected.formUnion([.diskRead, .diskWrite]) }
            if old.contains(.network) { expected.formUnion([.upload, .download]) }
            if expected.isEmpty { expected = [.upload, .download] }
            let restored = AppPreferences(defaults: defaults)
            #expect(restored.selection.metrics == expected)
            #expect(restored.selection.ringMetrics == [.storage, .memory, .cpu])
            #expect(defaults.integer(forKey: "menuBarDisplayVersion") == 3)
            #expect(restored.selection == AppPreferences(defaults: defaults).selection)
        }
    }

    @Test func migratingCustomizedTwoRingsPreservesTheirMetricsAndVisibility() throws {
        let suite = "PulseBar.CustomRingMigration.Tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(2, forKey: "menuBarDisplayVersion")
        defaults.set(["network"], forKey: "menuBarNumberMetrics")
        defaults.set("memory", forKey: "menuBarOuterRingMetric")
        defaults.set("battery", forKey: "menuBarInnerRingMetric")
        defaults.set(false, forKey: "menuBarShowsRings")
        let restored = AppPreferences(defaults: defaults)
        #expect(!restored.selection.showsRings)
        #expect(restored.selection.visibleNumberMetrics == [.upload, .download])
        restored.setRingsVisible(true)
        #expect(restored.selection.outerRing == .memory)
        #expect(restored.selection.innerRing == .battery)
        #expect(restored.selection.middleRing == .storage)
        #expect(AppPreferences(defaults: defaults).selection == restored.selection)
    }

    @Test func existingStorageAndMemoryPairAddsCPUAtTheInnerRing() throws {
        let suite = "PulseBar.StorageMemoryMigration.Tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(2, forKey: "menuBarDisplayVersion")
        defaults.set(["cpu", "memory", "network"], forKey: "menuBarNumberMetrics")
        defaults.set("storage", forKey: "menuBarOuterRingMetric")
        defaults.set("memory", forKey: "menuBarInnerRingMetric")
        let restored = AppPreferences(defaults: defaults)
        #expect(restored.selection.ringMetrics == [.storage, .memory, .cpu])
        #expect(restored.selection.visibleNumberMetrics == [.cpu, .memory, .upload, .download])
        #expect(restored.selection == AppPreferences(defaults: defaults).selection)
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
            var expectedNumbers: Set<MenuBarNumberMetric> = []
            if old.contains(.disk) { expectedNumbers.formUnion([.diskRead, .diskWrite]) }
            if old.contains(.network) { expectedNumbers.formUnion([.upload, .download]) }
            #expect(Set(restored.selection.visibleNumberMetrics) == expectedNumbers)
            #expect(restored.selection.outerRing == .storage)
            #expect(restored.selection.middleRing == .memory)
            #expect(restored.selection.innerRing == .cpu)
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
        #expect(restored.selection.ringMetrics == [.storage, .memory, .cpu])
        restored.setNumbersVisible(true)
        #expect(restored.selection.visibleNumberMetrics == [.upload, .download])
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
        #expect(restored.selection.metrics == [.upload, .download])
        #expect(restored.language == .system)
        #expect(restored.refreshSeconds == 1)
        #expect(restored.historySeconds == 1)
        defaults.set(["removed-metric"], forKey: "menuBarMetrics")
        #expect(AppPreferences(defaults: defaults).selection.metrics == [.upload, .download])
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
