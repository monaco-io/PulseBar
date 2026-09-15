import Darwin
import Foundation

public struct ProcessSample {
    public let pid: Int32
    public let parentPID: Int32
    public let startedAt: UInt64
    public let name: String
    public let executablePath: String
    public let cpuNanoseconds: UInt64
    public let memoryBytes: UInt64

    public init(pid: Int32, parentPID: Int32, startedAt: UInt64, name: String,
                executablePath: String, cpuNanoseconds: UInt64, memoryBytes: UInt64) {
        self.pid = pid; self.parentPID = parentPID; self.startedAt = startedAt
        self.name = name; self.executablePath = executablePath
        self.cpuNanoseconds = cpuNanoseconds; self.memoryBytes = memoryBytes
    }
}

public struct ProcessSnapshot {
    public let timestamp: TimeInterval
    public let processes: [ProcessSample]
    public let skippedCount: Int

    public init(timestamp: TimeInterval, processes: [ProcessSample], skippedCount: Int = 0) {
        self.timestamp = timestamp; self.processes = processes; self.skippedCount = skippedCount
    }
}

public struct AppUsage: Identifiable, Equatable, Codable {
    public let id: String
    public let name: String
    public let bundlePath: String?
    public var cpuPercent: Double?
    public var memoryBytes: UInt64
    public var processCount: Int

    public init(id: String, name: String, bundlePath: String? = nil, cpuPercent: Double?,
                memoryBytes: UInt64, processCount: Int = 1) {
        self.id = id; self.name = name; self.bundlePath = bundlePath
        self.cpuPercent = cpuPercent; self.memoryBytes = memoryBytes; self.processCount = processCount
    }
}

public enum AppRanking {
    public static func cpu(_ apps: [AppUsage]) -> [AppUsage] {
        Array(apps.filter { $0.cpuPercent != nil }.sorted {
            if $0.cpuPercent != $1.cpuPercent { return ($0.cpuPercent ?? 0) > ($1.cpuPercent ?? 0) }
            return $0.id < $1.id
        }.prefix(5))
    }

    public static func memory(_ apps: [AppUsage]) -> [AppUsage] {
        Array(apps.sorted {
            if $0.memoryBytes != $1.memoryBytes { return $0.memoryBytes > $1.memoryBytes }
            return $0.id < $1.id
        }.prefix(5))
    }
}

public struct ProcessAccumulator {
    private var previous: ProcessSnapshot?
    private var window = SamplingWindow()
    private let coreCount: Int
    private var appNames: [String: String] = [:]

    public init(coreCount: Int = ProcessInfo.processInfo.activeProcessorCount) {
        self.coreCount = max(1, coreCount)
    }

    public mutating func setRefreshInterval(_ seconds: Int) { window.configure(seconds: seconds) }
    public mutating func resetBaseline() { previous = nil }

    public mutating func consume(_ snapshot: ProcessSnapshot) -> [AppUsage] {
        guard snapshot.timestamp.isFinite else { return [] }
        let elapsed = previous.map { snapshot.timestamp - $0.timestamp } ?? 0
        guard previous == nil || elapsed > 0 else { return [] }
        let canMeasure = elapsed > 0 && window.accepts(elapsed)
        let old = Dictionary((previous?.processes ?? []).map { ($0.pid, $0) }, uniquingKeysWith: { _, new in new })
        previous = snapshot
        let current = Dictionary(snapshot.processes.map { ($0.pid, $0) }, uniquingKeysWith: { _, new in new })
        var groups: [String: AppUsage] = [:]
        for process in snapshot.processes {
            let bundle = Self.owningBundle(process, processes: current)
            let id = bundle ?? (process.executablePath.isEmpty ? "pid:\(process.pid):\(process.startedAt)" : process.executablePath)
            let name: String
            if let bundle {
                if appNames[bundle] == nil {
                    let metadata = Bundle(path: bundle)
                    appNames[bundle] = metadata?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? metadata?.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? URL(fileURLWithPath: bundle).deletingPathExtension().lastPathComponent
                }
                name = appNames[bundle] ?? process.name
            } else { name = process.name }
            var cpu: Double?
            if canMeasure, let last = old[process.pid], last.startedAt == process.startedAt,
               process.cpuNanoseconds >= last.cpuNanoseconds {
                cpu = min(100, Double(process.cpuNanoseconds - last.cpuNanoseconds) / 1_000_000_000 / elapsed / Double(coreCount) * 100)
            }
            if var group = groups[id] {
                if let cpu { group.cpuPercent = min(100, (group.cpuPercent ?? 0) + cpu) }
                group.memoryBytes += process.memoryBytes
                group.processCount += 1
                groups[id] = group
            } else {
                groups[id] = AppUsage(id: id, name: name, bundlePath: bundle, cpuPercent: cpu,
                                     memoryBytes: process.memoryBytes)
            }
        }
        appNames = appNames.filter { groups[$0.key] != nil }
        return groups.values.sorted { $0.id < $1.id }
    }

    public static func bundlePath(for executable: String) -> String? {
        let components = (executable as NSString).pathComponents
        guard let end = components.firstIndex(where: { $0.lowercased().hasSuffix(".app") }) else { return nil }
        return NSString.path(withComponents: Array(components[...end]))
    }

    private static func owningBundle(_ process: ProcessSample, processes: [Int32: ProcessSample]) -> String? {
        var candidate = process
        var visited: Set<Int32> = []
        for _ in 0..<64 {
            guard visited.insert(candidate.pid).inserted else { break }
            if let bundle = bundlePath(for: candidate.executablePath) { return bundle }
            guard candidate.parentPID > 1, let parent = processes[candidate.parentPID] else { break }
            candidate = parent
        }
        return nil
    }
}

/// Reads only process identities and counters, never command-line arguments or contents.
public struct ProcessReader {
    public init() {}

    public func read() throws -> ProcessSnapshot {
        var timebase = mach_timebase_info_data_t()
        let clockResult = mach_timebase_info(&timebase)
        guard clockResult == KERN_SUCCESS, timebase.denom != 0 else {
            throw SystemReadError(metric: .appRanking, code: clockResult)
        }
        let capacity = max(256, Int(proc_listallpids(nil, 0)) + 256)
        var pids = [Int32](repeating: 0, count: capacity)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        guard count > 0 else { throw POSIXReadError(metric: .appRanking, code: errno) }
        var samples: [ProcessSample] = []
        var skipped = 0
        for pid in pids.prefix(min(capacity, Int(count))) where pid > 0 {
            var info = proc_bsdinfo()
            let infoSize = Int32(MemoryLayout<proc_bsdinfo>.stride)
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, infoSize) == infoSize else { skipped += 1; continue }
            var usage = rusage_info_v2()
            let result = withUnsafeMutablePointer(to: &usage) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
                }
            }
            guard result == 0 else { skipped += 1; continue }
            var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            let pathSize = UInt32(path.count)
            let pathResult = proc_pidpath(pid, &path, pathSize)
            let executable = pathResult > 0 ? String(cString: path) : ""
            let name = executable.isEmpty ? "PID \(pid)" : URL(fileURLWithPath: executable).lastPathComponent
            samples.append(ProcessSample(pid: pid, parentPID: Int32(info.pbi_ppid), startedAt: usage.ri_proc_start_abstime,
                name: name, executablePath: executable,
                cpuNanoseconds: ProcessClock.nanoseconds(usage.ri_user_time + usage.ri_system_time,
                                                         numerator: timebase.numer, denominator: timebase.denom),
                memoryBytes: usage.ri_phys_footprint))
        }
        guard !samples.isEmpty else { throw POSIXReadError(metric: .appRanking, code: EACCES) }
        return ProcessSnapshot(timestamp: ProcessInfo.processInfo.systemUptime, processes: samples, skippedCount: skipped)
    }
}

enum ProcessClock {
    // rusage_info CPU time is in Mach absolute ticks (125/3 ns on this Apple
    // Silicon machine), unlike the already-normalized uptime used for intervals.
    static func nanoseconds(_ ticks: UInt64, numerator: UInt32, denominator: UInt32) -> UInt64 {
        guard denominator > 0 else { return 0 }
        let divisor = UInt64(denominator), multiplier = UInt64(numerator)
        let (whole, overflow) = (ticks / divisor).multipliedReportingOverflow(by: multiplier)
        guard !overflow else { return .max }
        let remainder = (ticks % divisor) * multiplier / divisor
        let (result, additionOverflow) = whole.addingReportingOverflow(remainder)
        return additionOverflow ? .max : result
    }
}
