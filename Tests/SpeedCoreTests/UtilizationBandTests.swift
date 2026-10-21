import Testing
@testable import SpeedCore

struct UtilizationBandTests {
    @Test func cpuAndStorageUseTheSameInclusiveWarningBoundaries() {
        for percent in [-1.0, 0, 23.4, 59.999] {
            #expect(UtilizationBand(percent: percent) == .normal)
        }
        for percent in [60.0, 72, 80] {
            #expect(UtilizationBand(percent: percent) == .warning)
        }
        for percent in [80.001, 91.2, 100, 101] {
            #expect(UtilizationBand(percent: percent) == .critical)
        }
    }

    @Test func unavailableUsageHasNoBand() {
        for percent: Double? in [nil, .nan, .infinity, -.infinity] {
            #expect(UtilizationBand(percent: percent) == nil)
        }
    }

    @Test func numericalChoicesNeverChangeTheTwoConfiguredRings() {
        #expect(MenuBarSelection(metrics: [.disk]).ringMetrics == [.cpu, .memory])
        #expect(MenuBarSelection(metrics: [.network]).ringMetrics == [.cpu, .memory])
        var selection = MenuBarSelection(metrics: [.disk, .network])
        selection.set(.disk, visible: false)
        #expect(selection.ringMetrics == [.cpu, .memory])
        selection.set(.memory, visible: true)
        #expect(selection.ringMetrics == [.cpu, .memory])
        selection.setRingMetric(.storage, at: .inner)
        #expect(selection.ringMetrics == [.cpu, .storage])
        #expect(selection.visibleNumberMetrics == [.memory, .network])
    }
}
