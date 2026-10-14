import Darwin
import Foundation
import SpeedCore

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
        // Resolve owners independently of readable resource counters. A WebKit
        // process can be sampled even when its app's counters are inaccessible.
        // Keep this cache local to the snapshot so PID reuse cannot retain owners.
        var paths: [Int32: String] = [:]
        func executablePath(for pid: Int32) -> String {
            if let cached = paths[pid] { return cached }
            var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            let size = UInt32(path.count)
            let result = proc_pidpath(pid, &path, size)
            let executable = result > 0 ? String(cString: path) : ""
            paths[pid] = executable
            return executable
        }
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
            let executable = executablePath(for: pid)
            let responsibleBundle = ProcessResponsibility.responsiblePID(for: pid).flatMap {
                ProcessAccumulator.bundlePath(for: executablePath(for: $0))
            }
            let name = executable.isEmpty ? "PID \(pid)" : URL(fileURLWithPath: executable).lastPathComponent
            samples.append(ProcessSample(pid: pid, parentPID: Int32(info.pbi_ppid), startedAt: usage.ri_proc_start_abstime,
                name: name, executablePath: executable,
                cpuNanoseconds: ProcessClock.nanoseconds(usage.ri_user_time + usage.ri_system_time,
                                                         numerator: timebase.numer, denominator: timebase.denom),
                memoryBytes: usage.ri_phys_footprint, responsibleBundlePath: responsibleBundle))
        }
        guard !samples.isEmpty else { throw POSIXReadError(metric: .appRanking, code: EACCES) }
        return ProcessSnapshot(timestamp: ProcessInfo.processInfo.systemUptime, processes: samples, skippedCount: skipped)
    }
}

private enum ProcessResponsibility {
    private typealias Lookup = @convention(c) (Int32) -> Int32

    // macOS's responsibility SPI identifies the app behind launchd-hosted XPC
    // services. Resolve it optionally: it is not a public SDK contract, and
    // unavailable/denied lookups must preserve bundle/parent-chain attribution.
    private static let lookup: Lookup? = {
        let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2) // Darwin RTLD_DEFAULT
        guard let symbol = dlsym(defaultHandle, "responsibility_get_pid_responsible_for_pid") else { return nil }
        return unsafeBitCast(symbol, to: Lookup.self)
    }()

    static func responsiblePID(for pid: Int32) -> Int32? {
        guard let responsible = lookup?(pid), responsible > 1, responsible != pid else { return nil }
        return responsible
    }
}

