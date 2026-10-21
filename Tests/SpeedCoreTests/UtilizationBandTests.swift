import Testing
@testable import SpeedCore

struct UtilizationBandTests {
    @Test func cpuAndStorageUseTheSameInclusiveWarningBoundaries() {
        for percent in [-1.0, 0, 23.4, 60, 79.999] {
            #expect(UtilizationBand(percent: percent) == .normal)
        }
        for percent in [80.0, 85, 89.999, 90] {
            #expect(UtilizationBand(percent: percent) == .warning)
        }
        for percent in [90.001, 91.2, 100, 101] {
            #expect(UtilizationBand(percent: percent) == .critical)
        }
    }

    @Test func unavailableUsageHasNoBand() {
        for percent: Double? in [nil, .nan, .infinity, -.infinity] {
            #expect(UtilizationBand(percent: percent) == nil)
        }
    }

    @Test func numericalChoicesNeverChangeTheThreeConfiguredRings() {
        #expect(MenuBarSelection(metrics: [.diskRead]).ringMetrics == [.storage, .memory, .cpu])
        #expect(MenuBarSelection(metrics: [.upload]).ringMetrics == [.storage, .memory, .cpu])
        var selection = MenuBarSelection(metrics: [.diskRead, .upload])
        selection.set(.diskRead, visible: false)
        #expect(selection.ringMetrics == [.storage, .memory, .cpu])
        selection.set(.memory, visible: true)
        #expect(selection.ringMetrics == [.storage, .memory, .cpu])
        selection.setRingMetric(.gpu, at: .middle)
        #expect(selection.ringMetrics == [.storage, .gpu, .cpu])
        #expect(selection.visibleNumberMetrics == [.memory, .upload])
    }
}
