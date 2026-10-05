import Foundation
import IOKit

/// Best-effort read-only accelerator statistics, without a privileged service.
/// IORegistry's driver-specific PerformanceStatistics is also used by Stats:
/// https://github.com/exelban/stats/blob/master/Modules/GPU/reader.swift
/// It is not a guaranteed macOS API: missing keys or unsupported drivers simply
/// produce no reading. Call from the monitor's background hardware queue.
public struct GPUReader {
    public init() {}

    public func read() -> [GPUUsage] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var readings: [GPUUsage] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let statistics = IORegistryEntryCreateCFProperty(service,
                    "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] else { continue }
            var id: UInt64 = 0
            guard IORegistryEntryGetRegistryEntryID(service, &id) == KERN_SUCCESS else { continue }
            // Apple GPUs keep model on the accelerator. Intel/AMD hardware may
            // keep it on the accelerator's parent PCI device. This parent search
            // never combines unrelated devices or guesses a marketing name.
            let model = IORegistryEntrySearchCFProperty(service, kIOServicePlane,
                "model" as CFString, kCFAllocatorDefault,
                IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents))
            guard let reading = GPUDecoder.usage(id: id, model: model, statistics: statistics) else { continue }
            readings.append(reading)
        }
        return readings.sorted { $0.id < $1.id }
    }
}
