import Foundation

public enum PerformanceEventKind: String, Codable, CaseIterable {
    case highCPU, memoryWarning, memoryCritical
    public var titleKey: TextKey {
        switch self {
        case .highCPU: return .eventHighCPU
        case .memoryWarning: return .eventMemoryWarning
        case .memoryCritical: return .eventMemoryCritical
        }
    }
}

public struct PerformanceEvent: Identifiable, Codable, Equatable {
    public let id: UUID
    public let kind: PerformanceEventKind
    public let date: Date
    public let duration: TimeInterval
    public let cpuPercent: Double?
    public let pressure: MemoryPressure?
    public let swapBytes: UInt64?
    public let topCPU: [AppUsage]
    public let topMemory: [AppUsage]
    public let rankingAvailable: Bool

    public init(id: UUID = UUID(), kind: PerformanceEventKind, date: Date, duration: TimeInterval,
                cpuPercent: Double?, pressure: MemoryPressure?, swapBytes: UInt64?, apps: [AppUsage],
                rankingAvailable: Bool = true) {
        self.id = id; self.kind = kind; self.date = date; self.duration = duration
        self.cpuPercent = cpuPercent; self.pressure = pressure; self.swapBytes = swapBytes
        topCPU = AppRanking.cpu(apps); topMemory = AppRanking.memory(apps)
        self.rankingAvailable = rankingAvailable
    }
}

public struct PerformanceEventDetector {
    public static let cpuThreshold = 85.0
    public static let cpuDuration = 30.0
    public static let pressureDuration = 10.0
    private var previousTimestamp: TimeInterval?
    private var cpuSince: TimeInterval?
    private var recordedCPU = false
    private var pressureSince: TimeInterval?
    private var lastPressure: MemoryPressure?
    private var recordedPressure = false

    public init() {}

    public mutating func resetContinuity() {
        previousTimestamp = nil; cpuSince = nil; recordedCPU = false
        pressureSince = nil; lastPressure = nil; recordedPressure = false
    }

    public mutating func consume(timestamp: TimeInterval, date: Date, cpu: Double?, pressure: MemoryPressure?,
                                 swapBytes: UInt64?, apps: [AppUsage], maximumGap: TimeInterval,
                                 rankingAvailable: Bool = true) -> [PerformanceEvent] {
        guard timestamp.isFinite else { resetContinuity(); return [] }
        if let previousTimestamp, timestamp <= previousTimestamp || timestamp - previousTimestamp > maximumGap {
            resetContinuity()
        }
        previousTimestamp = timestamp
        var result: [PerformanceEvent] = []
        if let cpu, cpu.isFinite, cpu >= Self.cpuThreshold {
            if cpuSince == nil { cpuSince = timestamp }
            let duration = timestamp - (cpuSince ?? timestamp)
            if !recordedCPU, duration >= Self.cpuDuration {
                result.append(PerformanceEvent(kind: .highCPU, date: date, duration: duration, cpuPercent: cpu,
                    pressure: pressure, swapBytes: swapBytes, apps: apps, rankingAvailable: rankingAvailable))
                recordedCPU = true
            }
        } else { cpuSince = nil; recordedCPU = false }

        if let pressure, pressure != .normal {
            if lastPressure != pressure { pressureSince = timestamp; recordedPressure = false }
            let duration = timestamp - (pressureSince ?? timestamp)
            if !recordedPressure, duration >= Self.pressureDuration {
                result.append(PerformanceEvent(kind: pressure == .critical ? .memoryCritical : .memoryWarning,
                    date: date, duration: duration, cpuPercent: cpu, pressure: pressure, swapBytes: swapBytes,
                    apps: apps, rankingAvailable: rankingAvailable))
                recordedPressure = true
            }
        } else { pressureSince = nil; recordedPressure = false }
        lastPressure = pressure
        return result
    }
}

public struct NotificationCooldown {
    public private(set) var lastSent: [String: Date]
    public init(lastSent: [String: Date] = [:]) { self.lastSent = lastSent }

    public func allows(_ event: PerformanceEvent, minutes: Int) -> Bool {
        guard let last = lastSent[event.kind.rawValue] else { return true }
        return event.date.timeIntervalSince(last) >= Double(max(1, minutes)) * 60
    }

    public mutating func markSent(_ event: PerformanceEvent) { lastSent[event.kind.rawValue] = event.date }
}

public struct PerformanceEventStore {
    public static let maximumCount = 200
    public static let retention: TimeInterval = 7 * 86400
    public let url: URL

    public init(url: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("PulseBar/events.json")) { self.url = url }

    public static func retained(_ events: [PerformanceEvent], now: Date) -> [PerformanceEvent] {
        Array(events.filter { $0.date >= now.addingTimeInterval(-retention) }
            .sorted { $0.date > $1.date }.prefix(maximumCount))
    }

    public func load(now: Date = Date()) throws -> [PerformanceEvent] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return Self.retained(try JSONDecoder().decode([PerformanceEvent].self, from: data), now: now)
    }

    public func save(_ events: [PerformanceEvent], now: Date = Date()) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(Self.retained(events, now: now)).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
