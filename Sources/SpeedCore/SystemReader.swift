import Darwin
import Foundation
import IOKit

public struct SystemReadError: LocalizedError {
    public let metric: TextKey
    public let code: kern_return_t
    public var errorDescription: String? {
        description(using: Localizer(language: .system))
    }
    public func description(using localizer: Localizer) -> String {
        localizer(.readFailed, localizer(metric), String(cString: mach_error_string(code)))
    }
}

/// Read-only Mach and IOKit calls; no subprocesses or administrator access.
public struct SystemReader {
    public init() {}

    public func readCPU() throws -> CPUSnapshot {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let capacity = Int(count)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { throw SystemReadError(metric: .cpu, code: result) }
        return CPUSnapshot(timestamp: ProcessInfo.processInfo.systemUptime,
                           user: info.cpu_ticks.0, system: info.cpu_ticks.1,
                           idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
    }

    public func readMemory() throws -> MemoryUsage {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let capacity = Int(count)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { throw SystemReadError(metric: .memory, code: result) }
        var pageSize: vm_size_t = 0
        let pageResult = host_page_size(host, &pageSize)
        guard pageResult == KERN_SUCCESS else { throw SystemReadError(metric: .memoryPageSize, code: pageResult) }
        return MemoryUsage(timestamp: ProcessInfo.processInfo.systemUptime,
                           totalBytes: ProcessInfo.processInfo.physicalMemory, pageSize: UInt64(pageSize),
                           internalPages: UInt64(info.internal_page_count), purgeablePages: UInt64(info.purgeable_count),
                           wiredPages: UInt64(info.wire_count), compressedPages: UInt64(info.compressor_page_count))
    }

    public func readDisks() throws -> DiskSnapshot {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator)
        guard result == KERN_SUCCESS else { throw SystemReadError(metric: .diskIO, code: result) }
        defer { IOObjectRelease(iterator) }
        var disks: [DiskCounter] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            // Disk images expose virtual block devices. Count hardware drivers only,
            // once per device, rather than adding APFS volumes or partitions again.
            let parents = IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
            let characteristics = IORegistryEntrySearchCFProperty(service, kIOServicePlane,
                "Protocol Characteristics" as CFString, kCFAllocatorDefault, parents) as? [String: Any]
            if characteristics?["Physical Interconnect"] as? String == "Virtual Interface" { continue }

            // Keys are defined in the SDK's IOBlockStorageDriver.h.
            guard let statistics = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString,
                    kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any],
                  let read = statistics["Bytes (Read)"] as? NSNumber,
                  let written = statistics["Bytes (Write)"] as? NSNumber else {
                throw SystemReadError(metric: .diskCounters, code: KERN_FAILURE)
            }
            var id: UInt64 = 0
            let idResult = IORegistryEntryGetRegistryEntryID(service, &id)
            guard idResult == KERN_SUCCESS else { throw SystemReadError(metric: .diskIdentity, code: idResult) }
            let name = IORegistryEntrySearchCFProperty(service, kIOServicePlane,
                "BSD Name" as CFString, kCFAllocatorDefault,
                IOOptionBits(kIORegistryIterateRecursively)) as? String ?? "#\(id)"
            disks.append(DiskCounter(id: id, name: name, readBytes: read.uint64Value, writtenBytes: written.uint64Value))
        }
        guard !disks.isEmpty else { throw SystemReadError(metric: .noDisks, code: KERN_NOT_SUPPORTED) }
        return DiskSnapshot(timestamp: ProcessInfo.processInfo.systemUptime, disks: disks.sorted { $0.name < $1.name })
    }
}
