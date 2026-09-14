import Darwin
import Testing
@testable import SpeedCore

struct TrafficTests {
    private func snapshot(_ time: Double, _ received: UInt64, _ sent: UInt64 = 0,
                          name: String = "en0", index: UInt32 = 1) -> TrafficSnapshot {
        TrafficSnapshot(timestamp: time, interfaces: [InterfaceCounter(name: name, index: index, received: received, sent: sent)])
    }

    @Test func firstSampleIsBaselineAndUsesActualElapsedTime() {
        var tracker = TrafficAccumulator()
        #expect(tracker.consume(snapshot(1, 8_000_000_000, 9_000_000_000)) == .zero)
        let rate = tracker.consume(snapshot(3, 8_004_000_000, 9_001_000_000))
        #expect(rate.download == 2_000_000)
        #expect(rate.upload == 500_000)
        #expect(tracker.totalReceived == 4_000_000)
        #expect(tracker.totalSent == 1_000_000)
    }

    @Test func interfaceSwitchAndReconnectDoNotCreateSpikes() {
        var tracker = TrafficAccumulator()
        _ = tracker.consume(snapshot(1, 10_000))
        #expect(tracker.consume(snapshot(2, 8_000_000, name: "en7", index: 2)) == .zero)
        #expect(tracker.consume(snapshot(3, 8_001_000, name: "en7", index: 2)).download == 1_000)
        _ = tracker.consume(TrafficSnapshot(timestamp: 4, interfaces: []))
        #expect(tracker.consume(snapshot(5, 8_900_000, name: "en7", index: 2)) == .zero)
        #expect(tracker.totalReceived == 1_000)
    }

    @Test func counterResetOnlyDiscardsAffectedDirection() {
        var tracker = TrafficAccumulator()
        _ = tracker.consume(snapshot(1, 1_000_000, 2_000))
        #expect(tracker.consume(snapshot(2, 0, 2_100)) == TrafficRate(download: 0, upload: 100))
        #expect(tracker.consume(snapshot(3, 200, 2_300)) == TrafficRate(download: 200, upload: 200))
    }

    @Test func wakeAndInvalidTimestampsDoNotCreateSpikes() {
        var tracker = TrafficAccumulator()
        _ = tracker.consume(snapshot(1, 1_000))
        #expect(tracker.consume(snapshot(1, 2_000)) == .zero)
        #expect(tracker.consume(snapshot(2, 2_000)).download == 1_000)
        #expect(tracker.consume(snapshot(600, 99_000_000)) == .zero)
        #expect(tracker.consume(snapshot(601, 99_001_000)).download == 1_000)
    }

    @Test func aggregatesMultiplePhysicalInterfacesAndResets() {
        var tracker = TrafficAccumulator()
        _ = tracker.consume(TrafficSnapshot(timestamp: 1, interfaces: [
            InterfaceCounter(name: "en0", index: 1, received: 1_000, sent: 100),
            InterfaceCounter(name: "en7", index: 2, received: 2_000, sent: 200)
        ]))
        let rate = tracker.consume(TrafficSnapshot(timestamp: 2, interfaces: [
            InterfaceCounter(name: "en0", index: 1, received: 2_000, sent: 300),
            InterfaceCounter(name: "en7", index: 2, received: 4_000, sent: 500)
        ]))
        #expect(rate == TrafficRate(download: 3_000, upload: 500))
        tracker.reset()
        #expect(tracker.totalReceived == 0)
        #expect(tracker.totalSent == 0)
        #expect(tracker.consume(snapshot(3, 99_999)) == .zero)
    }

    @Test func interfaceFilteringAvoidsVPNAndLoopbackDoubleCounting() {
        let active = Int32(IFF_UP | IFF_RUNNING)
        #expect(InterfaceReader.isIncluded(name: "en0", flags: active))
        #expect(InterfaceReader.isIncluded(name: "en12", flags: active))
        for name in ["lo0", "utun3", "bridge0", "awdl0", "llw0", "en", "en0x"] {
            #expect(!InterfaceReader.isIncluded(name: name, flags: active))
        }
        #expect(!InterfaceReader.isIncluded(name: "en0", flags: Int32(IFF_UP)))
        #expect(!InterfaceReader.isIncluded(name: "en2", flags: active, linkActive: false))
        #expect(InterfaceReader.isIncluded(name: "en0", flags: active, linkActive: true))
    }

    @Test func formattingUnitsAndRoundingBoundaries() {
        #expect(TrafficFormatter.speed(0).text == "0.0 MB/s")
        #expect(TrafficFormatter.speed(1_240_000).text == "1.2 MB/s")
        #expect(TrafficFormatter.speed(500).text == "<0.1 MB/s")
        #expect(TrafficFormatter.speed(99_999).text == "<0.1 MB/s")
        #expect(TrafficFormatter.speed(100_000).text == "0.1 MB/s")
        #expect(TrafficFormatter.speed(999_990).text == "1.0 MB/s")
        #expect(TrafficFormatter.speed(1_000_000_000).text == "1000.0 MB/s")
        #expect(TrafficFormatter.speed(.infinity).text == "0.0 MB/s")
        #expect(SystemFormatter.memory(25_769_803_776) == "25.8 GB")
        #expect(SystemFormatter.percent(24.876) == "24.9%")
        #expect(SystemFormatter.percent(100) == "100.0%")
    }

    @Test func summaryAmountsChooseReadableDecimalUnits() {
        #expect(TrafficFormatter.total(0) == "0.0 B")
        #expect(TrafficFormatter.total(512) == "512.0 B")
        #expect(TrafficFormatter.total(1_000) == "1.0 KB")
        #expect(TrafficFormatter.total(100_000) == "100.0 KB")
        #expect(TrafficFormatter.total(378_300_000) == "378.3 MB")
        #expect(TrafficFormatter.total(1_500_000_000) == "1.5 GB")
        #expect(TrafficFormatter.total(31_145_500_000) == "31.1 GB")
        #expect(TrafficFormatter.total(8_090_700_000) == "8.1 GB")
        #expect(TrafficFormatter.total(1_000_000_000_000) == "1.0 TB")
        #expect(TrafficFormatter.total(1_000_000_000_000_000) == "1.0 PB")
        #expect(TrafficFormatter.total(UInt64.max) == "18.4 EB")
        #expect(TrafficFormatter.total(999_949) == "999.9 KB")
        #expect(TrafficFormatter.total(999_950) == "1.0 MB")
        #expect(TrafficFormatter.total(999_950_000) == "1.0 GB")
    }

    @Test func memoryRatioSharesTheTotalCapacityUnit() {
        let total: UInt64 = 32_000_000_000
        #expect(TrafficFormatter.amount(500_000_000, unitFor: total).text == "0.5 GB")
        #expect(TrafficFormatter.amount(1_000_000, unitFor: total).text == "<0.1 GB")
        #expect(TrafficFormatter.amount(0, unitFor: total).text == "0.0 GB")
        #expect(TrafficFormatter.amount(999_000_000, unitFor: 999_950_000).text == "1.0 GB")
    }
}
