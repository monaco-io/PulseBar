import Foundation

public struct CPUSnapshot {
    public let timestamp: TimeInterval
    public let user: UInt32
    public let system: UInt32
    public let idle: UInt32
    public let nice: UInt32

    public init(timestamp: TimeInterval, user: UInt32, system: UInt32, idle: UInt32, nice: UInt32 = 0) {
        self.timestamp = timestamp
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

public struct CPUUsage: Equatable {
    public let userPercent: Double
    public let systemPercent: Double
    public var usedPercent: Double { userPercent + systemPercent }
}

public struct CPUAccumulator {
    private var previous: CPUSnapshot?
    private var window = SamplingWindow()

    public init() {}

    public mutating func setRefreshInterval(_ seconds: Int) { window.configure(seconds: seconds) }

    public mutating func consume(_ snapshot: CPUSnapshot) -> CPUUsage? {
        guard snapshot.timestamp.isFinite else { return nil }
        guard let old = previous else {
            previous = snapshot
            return nil
        }
        let elapsed = snapshot.timestamp - old.timestamp
        guard elapsed > 0 else { return nil }
        previous = snapshot
        guard window.accepts(elapsed) else { return nil }

        // Mach exposes wrapping 32-bit ticks summed over all logical CPUs.
        // Widen after subtraction; dividing by total ticks normalizes to 100%.
        let user = UInt64(snapshot.user &- old.user) + UInt64(snapshot.nice &- old.nice)
        let system = UInt64(snapshot.system &- old.system)
        let idle = UInt64(snapshot.idle &- old.idle)
        let total = Double(user + system + idle)
        guard total > 0 else { return nil }
        return CPUUsage(userPercent: Double(user) / total * 100,
                        systemPercent: Double(system) / total * 100)
    }

    public mutating func resetBaseline() { previous = nil }
}

public struct MemoryUsage: Equatable {
    public let timestamp: TimeInterval
    public let totalBytes: UInt64
    public let appBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public var usedBytes: UInt64 { min(totalBytes, appBytes + wiredBytes + compressedBytes) }
    public var usedPercent: Double {
        totalBytes == 0 ? 0 : Double(usedBytes) / Double(totalBytes) * 100
    }

    public init(timestamp: TimeInterval, totalBytes: UInt64, pageSize: UInt64,
                internalPages: UInt64, purgeablePages: UInt64, wiredPages: UInt64, compressedPages: UInt64) {
        self.timestamp = timestamp
        self.totalBytes = totalBytes
        // Reclaimable purgeable pages and file cache are not app memory.
        appBytes = (internalPages - min(internalPages, purgeablePages)) * pageSize
        wiredBytes = wiredPages * pageSize
        compressedBytes = compressedPages * pageSize
    }
}

public struct DiskCounter: Equatable {
    public let id: UInt64
    public let name: String
    public let readBytes: UInt64
    public let writtenBytes: UInt64

    public init(id: UInt64, name: String, readBytes: UInt64, writtenBytes: UInt64) {
        self.id = id
        self.name = name
        self.readBytes = readBytes
        self.writtenBytes = writtenBytes
    }
}

public struct DiskSnapshot {
    public let timestamp: TimeInterval
    public let disks: [DiskCounter]

    public init(timestamp: TimeInterval, disks: [DiskCounter]) {
        self.timestamp = timestamp
        self.disks = disks
    }
}

public struct DiskRate: Equatable {
    public let read: Double
    public let write: Double
    public static let zero = DiskRate(read: 0, write: 0)

    public init(read: Double, write: Double) {
        self.read = read
        self.write = write
    }
}

public struct DiskAccumulator {
    private var previous: DiskSnapshot?
    private var window = SamplingWindow()
    public private(set) var totalRead: UInt64 = 0
    public private(set) var totalWritten: UInt64 = 0

    public init() {}

    public mutating func setRefreshInterval(_ seconds: Int) { window.configure(seconds: seconds) }

    public mutating func consume(_ snapshot: DiskSnapshot) -> DiskRate? {
        guard snapshot.timestamp.isFinite else { return nil }
        guard let old = previous else {
            previous = snapshot
            return nil
        }
        let elapsed = snapshot.timestamp - old.timestamp
        guard elapsed > 0 else { return nil }
        previous = snapshot
        guard window.accepts(elapsed) else { return nil }

        var read: UInt64 = 0
        var written: UInt64 = 0
        for disk in snapshot.disks {
            // Registry IDs distinguish a reconnected device even if its BSD name is reused.
            guard let last = old.disks.first(where: { $0.id == disk.id }) else { continue }
            if disk.readBytes >= last.readBytes { read += disk.readBytes - last.readBytes }
            if disk.writtenBytes >= last.writtenBytes { written += disk.writtenBytes - last.writtenBytes }
        }
        totalRead += read
        totalWritten += written
        return DiskRate(read: Double(read) / elapsed, write: Double(written) / elapsed)
    }

    public mutating func resetBaseline() { previous = nil }

    public mutating func reset() {
        previous = nil
        totalRead = 0
        totalWritten = 0
    }
}

public enum SystemFormatter {
    public static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return String(format: "%.1f%%", locale: Locale(identifier: "en_US_POSIX"), min(100, max(0, value)))
    }

    public static func memory(_ bytes: UInt64) -> String {
        TrafficFormatter.total(bytes)
    }
}
