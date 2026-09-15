import Foundation
import Testing
@testable import SpeedCore

struct PerformanceEventsTests {
    private func sample(_ detector: inout PerformanceEventDetector, time: Double, cpu: Double? = 90,
                        pressure: MemoryPressure? = .normal, gap: Double = 5) -> [PerformanceEvent] {
        detector.consume(timestamp: time, date: Date(timeIntervalSince1970: time), cpu: cpu, pressure: pressure,
                         swapBytes: 1000, apps: [AppUsage(id: "editor", name: "Editor", cpuPercent: 50, memoryBytes: 100)], maximumGap: gap)
    }

    @Test func shortSpikesAreIgnoredAndSustainedCPURecordsOnceUntilRecovery() {
        var detector = PerformanceEventDetector()
        var events: [PerformanceEvent] = []
        for time in 0...90 { events += sample(&detector, time: Double(time)) }
        #expect(events.count == 1)
        #expect(events.first?.duration == 30)
        #expect(events.first?.topCPU.first?.name == "Editor")
        #expect(events.first?.topMemory.first?.memoryBytes == 100)
        _ = sample(&detector, time: 91, cpu: 20)
        for time in 92...122 { events += sample(&detector, time: Double(time)) }
        #expect(events.count == 2)
    }

    @Test func failedReadsAndSleepGapsResetDuration() {
        var detector = PerformanceEventDetector()
        for time in 0...25 { #expect(sample(&detector, time: Double(time)).isEmpty) }
        _ = sample(&detector, time: 26, cpu: nil)
        for time in 27...55 { #expect(sample(&detector, time: Double(time)).isEmpty) }
        #expect(sample(&detector, time: 100).isEmpty)
        for time in 101...129 { #expect(sample(&detector, time: Double(time)).isEmpty) }
        #expect(sample(&detector, time: 130).count == 1)
    }

    @Test func pressureEscalationAndRecoveryStartNewEpisodes() {
        var detector = PerformanceEventDetector()
        var events: [PerformanceEvent] = []
        for time in 0...15 { events += sample(&detector, time: Double(time), cpu: 20, pressure: .warning) }
        #expect(events.map(\.kind) == [.memoryWarning])
        for time in 16...26 { events += sample(&detector, time: Double(time), cpu: 20, pressure: .critical) }
        #expect(events.map(\.kind) == [.memoryWarning, .memoryCritical])
        _ = sample(&detector, time: 27, cpu: 20, pressure: nil)
        #expect(sample(&detector, time: 28, cpu: 20, pressure: .critical).isEmpty)
    }

    @Test func configuredLongRefreshIntervalsRemainValid() {
        var detector = PerformanceEventDetector()
        #expect(sample(&detector, time: 1, gap: 90).isEmpty)
        #expect(sample(&detector, time: 61, gap: 90).first?.duration == 60)
    }

    @Test func notificationsHaveIndependentPersistentCooldowns() {
        func event(_ time: Double, _ kind: PerformanceEventKind = .highCPU) -> PerformanceEvent {
            PerformanceEvent(kind: kind, date: Date(timeIntervalSince1970: time), duration: 30,
                             cpuPercent: 90, pressure: .normal, swapBytes: nil, apps: [])
        }
        var cooldown = NotificationCooldown()
        #expect(cooldown.allows(event(10), minutes: 10))
        cooldown.markSent(event(10))
        #expect(!cooldown.allows(event(609), minutes: 10))
        #expect(cooldown.allows(event(610), minutes: 10))
        #expect(cooldown.allows(event(11, .memoryWarning), minutes: 10))
        #expect(!NotificationCooldown(lastSent: cooldown.lastSent).allows(event(200), minutes: 10))
        #expect(!cooldown.allows(event(0), minutes: 10))
    }

    @Test func eventStorageRoundTripsSnapshotsAndBoundsRetention() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PerformanceEventStore(url: directory.appendingPathComponent("events.json"))
        let now = Date()
        let events = (0..<220).map { offset in
            PerformanceEvent(kind: .memoryWarning, date: now.addingTimeInterval(-Double(offset)), duration: 10,
                cpuPercent: 10, pressure: .warning, swapBytes: 2000,
                apps: [AppUsage(id: "editor", name: "Editor", cpuPercent: 12, memoryBytes: 100)])
        }
        try store.save(events, now: now)
        let restored = try store.load(now: now)
        #expect(restored == Array(events.prefix(200)))
        #expect(try store.load(now: now.addingTimeInterval(8 * 86400)).isEmpty)
        try Data("invalid".utf8).write(to: store.url)
        #expect(throws: (any Error).self) { try store.load(now: now) }
        #expect(try String(contentsOf: store.url, encoding: .utf8) == "invalid")
    }
}
