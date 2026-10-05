import Foundation

/// Capacity visible to the startup data volume, not a sum of APFS volumes.
/// APFS volumes can share their container's space, so `usedBytes` also includes
/// space unavailable because of other volumes and snapshots in that container.
public struct StorageCapacity: Equatable {
    public let name: String
    public let path: String
    public let totalBytes: UInt64
    /// Ordinary free space. This excludes estimated space reclaimed by purging
    /// caches, unlike `volumeAvailableCapacityForImportantUsage`.
    public let availableBytes: UInt64
    public var usedBytes: UInt64 { totalBytes - availableBytes }
    public var usedPercent: Double { Double(usedBytes) / Double(totalBytes) * 100 }

    public init?(name: String, path: String, totalBytes: Int64, availableBytes: Int64) {
        guard totalBytes > 0, availableBytes >= 0, availableBytes <= totalBytes else { return nil }
        self.name = name
        self.path = path
        self.totalBytes = UInt64(totalBytes)
        self.availableBytes = UInt64(availableBytes)
    }
}

/// A lightweight, read-only Foundation query. Call on the sampling queue rather
/// than the main thread, at a slower cadence than CPU and traffic counters.
public struct StorageCapacityReader {
    private let volumeURL: URL

    public init() {
        let dataVolume = URL(fileURLWithPath: "/System/Volumes/Data", isDirectory: true)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: dataVolume.path, isDirectory: &isDirectory), isDirectory.boolValue {
            volumeURL = dataVolume
        } else {
            // Macs without a separate startup data volume still expose capacity
            // through the root volume. Never choose the user's home directory.
            volumeURL = URL(fileURLWithPath: "/", isDirectory: true)
        }
    }

    init(volumeURL: URL) { self.volumeURL = volumeURL }

    public func read() -> StorageCapacity? {
        guard volumeURL.isFileURL else { return nil }
        // Recreate the URL so Foundation cannot reuse cached resource values
        // from an earlier capacity sample.
        let freshURL = URL(fileURLWithPath: volumeURL.path, isDirectory: true)
        guard let values = try? freshURL.resourceValues(forKeys: [
            .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
            .volumeIsLocalKey
        ]), values.volumeIsLocal != false,
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacity else { return nil }
        let name = values.volumeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return StorageCapacity(name: name.flatMap { $0.isEmpty ? nil : $0 } ?? freshURL.path,
                               path: freshURL.path, totalBytes: Int64(total), availableBytes: Int64(available))
    }
}
