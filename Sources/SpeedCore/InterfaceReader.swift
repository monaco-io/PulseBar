import Darwin
import Foundation
import SystemConfiguration

public struct InterfaceReadError: LocalizedError {
    public let code: Int32
    public var errorDescription: String? {
        description(using: Localizer(language: .system))
    }
    public func description(using localizer: Localizer) -> String {
        localizer(.networkReadFailed, String(cString: strerror(code)))
    }
}

public struct InterfaceReader {
    public init() {}

    /// Reads the kernel's 64-bit counters in-process. No subprocesses, packet
    /// capture, elevated privileges, or outbound requests are needed.
    public func read() throws -> TrafficSnapshot {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        let links = SCDynamicStoreCopyMultiple(nil, nil,
            ["State:/Network/Interface/en[0-9]+/Link"] as CFArray) as? [String: [String: Any]] ?? [:]
        // The interface list can grow between the size query and the read.
        for _ in 0..<3 {
            var length = 0
            guard sysctl(&mib, u_int(mib.count), nil, &length, nil, 0) == 0 else {
                throw InterfaceReadError(code: errno)
            }
            var data = Data(count: length)
            let result = data.withUnsafeMutableBytes { buffer in
                sysctl(&mib, u_int(mib.count), buffer.baseAddress, &length, nil, 0)
            }
            guard result == 0 else {
                let code = errno
                if code == ENOMEM { continue }
                throw InterfaceReadError(code: code)
            }
            let interfaces: [InterfaceCounter] = data.withUnsafeBytes { buffer in
                var items: [InterfaceCounter] = []
                var offset = 0
                while offset + 4 <= length {
                    let messageLength = Int(buffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                    guard messageLength >= 4, offset + messageLength <= length else { break }
                    let kind = buffer.load(fromByteOffset: offset + 3, as: UInt8.self)
                    if kind == RTM_IFINFO2, messageLength >= MemoryLayout<if_msghdr2>.size {
                        let info = buffer.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                        var nameBuffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                        if if_indextoname(UInt32(info.ifm_index), &nameBuffer) != nil {
                            let name = String(cString: nameBuffer)
                            let linkActive = links["State:/Network/Interface/\(name)/Link"]?["Active"] as? Bool
                            if Self.isIncluded(name: name, flags: info.ifm_flags, linkActive: linkActive) {
                                items.append(InterfaceCounter(name: name, index: UInt32(info.ifm_index),
                                                              received: info.ifm_data.ifi_ibytes,
                                                              sent: info.ifm_data.ifi_obytes))
                            }
                        }
                    }
                    offset += messageLength
                }
                return items.sorted { $0.name < $1.name }
            }
            return TrafficSnapshot(timestamp: ProcessInfo.processInfo.systemUptime, interfaces: interfaces)
        }
        throw InterfaceReadError(code: ENOMEM)
    }

    /// macOS uses en<N> for Wi-Fi, Ethernet, USB tethering and Ethernet adapters.
    /// Exclude VPN, loopback, bridges, and AirDrop interfaces to avoid duplicates.
    public static func isIncluded(name: String, flags: Int32, linkActive: Bool? = nil) -> Bool {
        let suffix = name.dropFirst(2)
        return name.hasPrefix("en") && !suffix.isEmpty && suffix.allSatisfy(\.isNumber)
            && flags & IFF_UP != 0 && flags & IFF_RUNNING != 0 && flags & IFF_LOOPBACK == 0
            && linkActive != false
    }
}
