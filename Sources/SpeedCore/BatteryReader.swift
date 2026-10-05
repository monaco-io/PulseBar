import Foundation
import IOKit
import IOKit.ps

/// Public read-only IOPowerSources and IORegistry access. No subprocesses,
/// privileged helpers, or external/peripheral power-source aggregation.
public struct BatteryReader {
    public init() {}

    public func read() -> BatterySnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        let descriptions = sources.compactMap { source in
            IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
        }
        // Avoid touching battery registry services on desktops or when the public
        // source snapshot cannot establish a present internal host battery.
        let timestamp = ProcessInfo.processInfo.systemUptime
        guard BatteryDecoder.decode(powerSources: descriptions, timestamp: timestamp) != nil else { return nil }
        return BatteryDecoder.decode(powerSources: descriptions, smartBatteries: readSmartBatteries(), timestamp: timestamp)
    }

    private func readSmartBatteries() -> [[String: Any]] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }
        var batteries: [[String: Any]] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dictionary = properties?.takeRetainedValue() as? [String: Any] {
                batteries.append(dictionary)
            }
        }
        return batteries
    }
}
