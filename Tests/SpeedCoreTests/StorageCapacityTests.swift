import Foundation
import Testing
@testable import SpeedCore

struct StorageCapacityTests {
    @Test func storageCountsOrdinaryUnavailableSpaceOnce() {
        let capacity = StorageCapacity(name: "Macintosh HD - Data", path: "/System/Volumes/Data",
                                       totalBytes: 1_000_000_000, availableBytes: 250_000_000)
        #expect(capacity?.name == "Macintosh HD - Data")
        #expect(capacity?.path == "/System/Volumes/Data")
        #expect(capacity?.totalBytes == 1_000_000_000)
        #expect(capacity?.availableBytes == 250_000_000)
        #expect(capacity?.usedBytes == 750_000_000)
        #expect(capacity?.usedPercent == 75)
    }

    @Test(arguments: [
        (Int64(0), Int64(0)),
        (-1, 0),
        (1_000, -1),
        (1_000, 1_001),
        (Int64.min, Int64.max)
    ])
    func invalidOrInconsistentReadingsAreHidden(values: (Int64, Int64)) {
        #expect(StorageCapacity(name: "Data", path: "/System/Volumes/Data",
                                totalBytes: values.0, availableBytes: values.1) == nil)
    }

    @Test func genuinelyFullOrEmptyVolumeIsValid() {
        let full = StorageCapacity(name: "Data", path: "/System/Volumes/Data",
                                   totalBytes: 1_000, availableBytes: 0)
        #expect(full?.usedPercent == 100)
        #expect(full?.availableBytes == 0)
        let empty = StorageCapacity(name: "Data", path: "/System/Volumes/Data",
                                    totalBytes: 1_000, availableBytes: 1_000)
        #expect(empty?.usedPercent == 0)
        #expect(empty?.usedBytes == 0)
    }

    @Test func largeCapacitiesRemainFiniteWithoutIntegerOverflow() {
        let capacity = StorageCapacity(name: "Data", path: "/System/Volumes/Data",
                                       totalBytes: Int64.max, availableBytes: 1)
        #expect(capacity?.usedBytes == UInt64(Int64.max) - 1)
        #expect(capacity?.usedPercent.isFinite == true)
        #expect((capacity?.usedPercent ?? -1) <= 100)
    }

    @Test func unreadableOrNonFileVolumesAreHidden() {
        let absent = URL(fileURLWithPath: "/pulsebar-unavailable-volume-\(UUID().uuidString)")
        #expect(StorageCapacityReader(volumeURL: absent).read() == nil)
        #expect(StorageCapacityReader(volumeURL: URL(string: "https://example.invalid/volume")!).read() == nil)
    }
}
