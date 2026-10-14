import Foundation
import HelperIPC
import SpeedCore
import Testing

struct HelperSnapshotTests {
    private func sample(timestamp: TimeInterval = 100, temperatureTimestamp: TimeInterval = 100,
                        cpu: Double? = 12, apps: [AppUsage]? = nil) -> HelperSnapshot {
        HelperSnapshot(helperVersion: "1.0.0", timestamp: timestamp,
            apps: apps ?? [AppUsage(id: "app", name: "Example", cpuPercent: cpu, memoryBytes: 1024)],
            processCount: 50, skippedProcessCount: 2, processError: nil,
            temperatures: [TemperatureReading(component: .cpu, celsius: 65, sensorIDs: ["Tp01"])],
            temperatureTimestamp: temperatureTimestamp)
    }

    @Test func acceptsFreshSamplesAndPreservesRankings() throws {
        let decoded = try HelperSnapshot.decode(JSONEncoder().encode(sample()), now: 101, refreshSeconds: 1)
        #expect(decoded.apps.first?.cpuPercent == 12)
        #expect(decoded.processCount == 50)
        #expect(decoded.temperatures.first?.celsius == 65)
    }

    @Test func rejectsStaleFutureAndMismatchedPayloads() throws {
        for value in [sample(timestamp: 80), sample(timestamp: 105), sample(temperatureTimestamp: 70), sample(cpu: 101)] {
            let data = try JSONEncoder().encode(value)
            #expect(throws: (any Error).self) { try HelperSnapshot.decode(data, now: 101, refreshSeconds: 1) }
        }
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(sample())) as? [String: Any])
        object["schemaVersion"] = 2
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: (any Error).self) { try HelperSnapshot.decode(data, now: 101, refreshSeconds: 1) }
    }

    @Test func rejectsDuplicateRankingsAndOversizedResponses() throws {
        let app = AppUsage(id: "duplicate", name: "Example", cpuPercent: nil, memoryBytes: 10)
        let data = try JSONEncoder().encode(sample(apps: [app, app]))
        #expect(throws: (any Error).self) { try HelperSnapshot.decode(data, now: 101, refreshSeconds: 1) }
        #expect(throws: (any Error).self) {
            try HelperSnapshot.decode(Data(repeating: 0, count: 262_145), now: 101, refreshSeconds: 1)
        }
    }
}
