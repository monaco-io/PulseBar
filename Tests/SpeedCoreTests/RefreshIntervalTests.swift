import Testing
@testable import SpeedCore

struct RefreshIntervalTests {
    private func traffic(_ time: Double, _ count: UInt64) -> TrafficSnapshot {
        TrafficSnapshot(timestamp: time, interfaces: [InterfaceCounter(name: "en0", index: 1, received: count, sent: count)])
    }

    private func disk(_ time: Double, _ count: UInt64) -> DiskSnapshot {
        DiskSnapshot(timestamp: time, disks: [DiskCounter(id: 1, name: "disk0", readBytes: count, writtenBytes: count)])
    }

    @Test(arguments: [6, 10, 30, 60])
    func configuredIntervalsStillProduceRealRates(seconds: Int) throws {
        var network = TrafficAccumulator()
        var cpu = CPUAccumulator()
        var disks = DiskAccumulator()
        network.setRefreshInterval(seconds)
        cpu.setRefreshInterval(seconds)
        disks.setRefreshInterval(seconds)
        _ = network.consume(traffic(0, 1_000))
        _ = cpu.consume(CPUSnapshot(timestamp: 0, user: 100, system: 100, idle: 100))
        _ = disks.consume(disk(0, 1_000))
        let elapsed = Double(seconds) + 0.2
        let networkRate = network.consume(traffic(elapsed, 2_000))
        let cpuSample = cpu.consume(CPUSnapshot(timestamp: elapsed, user: 120, system: 110, idle: 170))
        let diskSample = disks.consume(disk(elapsed, 2_000))
        let cpuRate = try #require(cpuSample)
        let diskRate = try #require(diskSample)
        #expect(abs(networkRate.download - 1_000 / elapsed) < 0.0001)
        #expect(cpuRate.usedPercent == 30)
        #expect(abs(diskRate.read - 1_000 / elapsed) < 0.0001)
        #expect(network.totalReceived == 1_000)
        #expect(disks.totalRead == 1_000)
        #expect(network.consume(traffic(elapsed + 180, 999_000)) == .zero)
        #expect(cpu.consume(CPUSnapshot(timestamp: elapsed + 180, user: 900, system: 900, idle: 900)) == nil)
        #expect(disks.consume(disk(elapsed + 180, 999_000)) == nil)
    }

    @Test func shorteningTheIntervalAcceptsTheTransitionThenDetectsStalls() {
        var tracker = DiskAccumulator()
        tracker.setRefreshInterval(60)
        _ = tracker.consume(disk(0, 1_000))
        #expect(tracker.consume(disk(60, 61_000))?.read == 1_000)
        tracker.setRefreshInterval(1)
        #expect(tracker.consume(disk(101, 102_000))?.read == 1_000)
        #expect(tracker.consume(disk(102, 103_000))?.read == 1_000)
        #expect(tracker.totalRead == 102_000)
        #expect(tracker.consume(disk(110, 999_000)) == nil)
        #expect(tracker.totalRead == 102_000)
        #expect(tracker.consume(disk(111, 1_000_000))?.read == 1_000)
    }
}
