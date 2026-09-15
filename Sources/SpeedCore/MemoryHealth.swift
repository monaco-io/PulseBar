import Darwin
import Foundation

public struct POSIXReadError: LocalizedError {
    public let metric: TextKey
    public let code: Int32
    public var errorDescription: String? { description(using: Localizer(language: .system)) }
    public func description(using localizer: Localizer) -> String {
        localizer(.readFailed, localizer(metric), String(cString: strerror(code)))
    }
}

public enum MemoryPressure: Int, Codable, CaseIterable {
    // The sysctl returns NOTE_MEMORYSTATUS_PRESSURE_* flags, not the kernel's internal enum.
    case normal = 1, warning = 2, critical = 4
    public var titleKey: TextKey {
        switch self {
        case .normal: return .pressureNormal
        case .warning: return .pressureWarning
        case .critical: return .pressureCritical
        }
    }
}

public struct SwapUsage: Equatable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    public init(usedBytes: UInt64, totalBytes: UInt64) {
        self.usedBytes = usedBytes; self.totalBytes = totalBytes
    }
}

public extension SystemReader {
    func readMemoryPressure() throws -> MemoryPressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else {
            throw POSIXReadError(metric: .memoryPressure, code: errno)
        }
        guard let pressure = MemoryPressure(rawValue: Int(level)) else {
            throw POSIXReadError(metric: .memoryPressure, code: ENOTSUP)
        }
        return pressure
    }

    func readSwap() throws -> SwapUsage {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else {
            throw POSIXReadError(metric: .swap, code: errno)
        }
        return SwapUsage(usedBytes: usage.xsu_used, totalBytes: usage.xsu_total)
    }
}
