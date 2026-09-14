import Foundation
import Testing
@testable import SpeedCore

struct SystemMetricsTests {
    @Test func cpuIsIntervalUsageNormalizedAcrossAllCores() {
        var tracker = CPUAccumulator()
        #expect(tracker.consume(CPUSnapshot(timestamp: 1, user: 9_000, system: 1_000, idle: 90_000, nice: 100)) == nil)
        let usage = tracker.consume(CPUSnapshot(timestamp: 3, user: 9_200, system: 1_100, idle: 90_600, nice: 200))
        #expect(usage?.userPercent == 30)
        #expect(usage?.systemPercent == 10)
        #expect(usage?.usedPercent == 40)
    }

    @Test func cpuTicksCanWrapWithoutOverflowOrSpikes() {
        var tracker = CPUAccumulator()
        _ = tracker.consume(CPUSnapshot(timestamp: 1, user: UInt32.max - 9, system: 100, idle: 200))
        let usage = tracker.consume(CPUSnapshot(timestamp: 2, user: 10, system: 100, idle: 280))
        #expect(usage?.usedPercent == 20)
    }

    @Test func cpuRebaselinesAfterSleepAndIgnoresInvalidTime() {
        var tracker = CPUAccumulator()
        _ = tracker.consume(CPUSnapshot(timestamp: 1, user: 100, system: 0, idle: 100))
        #expect(tracker.consume(CPUSnapshot(timestamp: .nan, user: 900, system: 0, idle: 100)) == nil)
        #expect(tracker.consume(CPUSnapshot(timestamp: 1, user: 800, system: 0, idle: 100)) == nil)
        #expect(tracker.consume(CPUSnapshot(timestamp: 0, user: 800, system: 0, idle: 100)) == nil)
        #expect(tracker.consume(CPUSnapshot(timestamp: 2, user: 150, system: 0, idle: 150))?.usedPercent == 50)
        #expect(tracker.consume(CPUSnapshot(timestamp: 100, user: 1_000, system: 0, idle: 10_000)) == nil)
        #expect(tracker.consume(CPUSnapshot(timestamp: 101, user: 1_020, system: 0, idle: 10_080))?.usedPercent == 20)
        tracker.resetBaseline()
        #expect(tracker.consume(CPUSnapshot(timestamp: 102, user: 1_030, system: 0, idle: 10_100)) == nil)
        #expect(tracker.consume(CPUSnapshot(timestamp: 103, user: 1_030, system: 0, idle: 10_100)) == nil)
    }

    @Test(arguments: [UInt64(4_096), UInt64(16_384)])
    func memoryCountsCompressedPhysicalPagesAndExcludesPurgeableCache(pageSize: UInt64) {
        let memory = MemoryUsage(timestamp: 1, totalBytes: pageSize * 1_000, pageSize: pageSize,
                                 internalPages: 400, purgeablePages: 100, wiredPages: 200, compressedPages: 100)
        #expect(memory.appBytes == 300 * pageSize)
        #expect(memory.wiredBytes == 200 * pageSize)
        #expect(memory.compressedBytes == 100 * pageSize)
        #expect(memory.usedBytes == 600 * pageSize)
        #expect(memory.usedPercent == 60)
    }

    @Test func memoryHandlesNonAtomicPageCountersAndMissingTotal() {
        let memory = MemoryUsage(timestamp: 1, totalBytes: 1_000, pageSize: 100,
                                 internalPages: 2, purgeablePages: 3, wiredPages: 10, compressedPages: 2)
        #expect(memory.appBytes == 0)
        #expect(memory.usedBytes == 1_000)
        #expect(memory.usedPercent == 100)
        let empty = MemoryUsage(timestamp: 1, totalBytes: 0, pageSize: 16_384,
                                internalPages: 0, purgeablePages: 0, wiredPages: 0, compressedPages: 0)
        #expect(empty.usedPercent == 0)
    }

    private func disk(_ id: UInt64, _ read: UInt64, _ write: UInt64 = 0, name: String = "disk0") -> DiskCounter {
        DiskCounter(id: id, name: name, readBytes: read, writtenBytes: write)
    }

    @Test func diskAggregates64BitCountersUsingActualElapsedTime() {
        var tracker = DiskAccumulator()
        #expect(tracker.consume(DiskSnapshot(timestamp: 1, disks: [
            disk(1, 10_000_000_000, 20_000_000_000), disk(2, 1_000, 1_000, name: "disk4")
        ])) == nil)
        let rate = tracker.consume(DiskSnapshot(timestamp: 3.5, disks: [
            disk(1, 10_005_000_000, 20_002_000_000), disk(2, 5_001_000, 3_001_000, name: "disk4")
        ]))
        #expect(rate == DiskRate(read: 4_000_000, write: 2_000_000))
        #expect(tracker.totalRead == 10_000_000)
        #expect(tracker.totalWritten == 5_000_000)
    }

    @Test func diskReconnectWithReusedNameDoesNotCountHistoricalIO() {
        var tracker = DiskAccumulator()
        _ = tracker.consume(DiskSnapshot(timestamp: 1, disks: [disk(1, 1_000)]))
        #expect(tracker.consume(DiskSnapshot(timestamp: 2, disks: [disk(2, 9_000_000)])) == .zero)
        #expect(tracker.consume(DiskSnapshot(timestamp: 3, disks: [disk(2, 9_001_000)]))?.read == 1_000)
        _ = tracker.consume(DiskSnapshot(timestamp: 4, disks: []))
        #expect(tracker.consume(DiskSnapshot(timestamp: 5, disks: [disk(2, 90_000_000)])) == .zero)
        #expect(tracker.totalRead == 1_000)
    }

    @Test func diskCounterResetIsIsolatedToDeviceAndDirection() {
        var tracker = DiskAccumulator()
        _ = tracker.consume(DiskSnapshot(timestamp: 1, disks: [disk(1, 8_000, 9_000), disk(2, 1_000, 2_000)]))
        let rate = tracker.consume(DiskSnapshot(timestamp: 2, disks: [disk(1, 10, 9_100), disk(2, 1_200, 2_300)]))
        #expect(rate == DiskRate(read: 200, write: 400))
        #expect(tracker.totalRead == 200)
        #expect(tracker.totalWritten == 400)
    }

    @Test func diskSleepFailuresAndResetDoNotInventTraffic() {
        var tracker = DiskAccumulator()
        _ = tracker.consume(DiskSnapshot(timestamp: 1, disks: [disk(1, 100)]))
        #expect(tracker.consume(DiskSnapshot(timestamp: 1, disks: [disk(1, 1_000)])) == nil)
        #expect(tracker.consume(DiskSnapshot(timestamp: .infinity, disks: [disk(1, 1_000)])) == nil)
        #expect(tracker.consume(DiskSnapshot(timestamp: 2, disks: [disk(1, 200)]))?.read == 100)
        #expect(tracker.consume(DiskSnapshot(timestamp: 100, disks: [disk(1, 9_000_000)])) == nil)
        #expect(tracker.totalRead == 100)
        tracker.resetBaseline()
        #expect(tracker.consume(DiskSnapshot(timestamp: 101, disks: [disk(1, 10_000_000)])) == nil)
        #expect(tracker.totalRead == 100)
        tracker.reset()
        #expect(tracker.totalRead == 0)
        #expect(tracker.totalWritten == 0)
        #expect(tracker.consume(DiskSnapshot(timestamp: 102, disks: [disk(1, 11_000_000)])) == nil)
    }
}
