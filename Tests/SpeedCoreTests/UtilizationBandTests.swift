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

    @Test func storageKeepsARingEvenWithoutCPUAndMemory() {
        #expect(MenuBarSelection(metrics: [.disk]).ringMetrics == [.disk])
        #expect(MenuBarSelection(metrics: [.disk, .network]).ringMetrics == [.disk])
        #expect(MenuBarSelection(metrics: [.network]).ringMetrics.isEmpty)
        #expect(MenuBarSelection().ringMetrics == [.cpu, .memory, .disk])
        var selection = MenuBarSelection(metrics: [.disk, .network])
        selection.set(.disk, visible: false)
        #expect(selection.ringMetrics.isEmpty)
        selection.set(.memory, visible: true)
        #expect(selection.ringMetrics == [.memory])
    }
}
