import Foundation
import SpeedCore

/// The companion exposes one read-only operation. No paths, commands, file
/// writes, process control, or arbitrary selectors can be requested over IPC.
@objc public protocol PulseBarHelperProtocol {
    func sample(refreshSeconds: Int, withReply reply: @escaping (Data?, String?) -> Void)
}

public enum HelperIdentity {
    public static let teamID = "45Y6A23PTN"
    public static let appID = "io.github.monaco-io.PulseBar"
    public static let helperID = appID + ".Helper"
    public static let serviceID = appID + ".HelperService"
    public static let agentPlist = serviceID + ".plist"
    public static let downloadURL = URL(string: "https://github.com/monaco-io/PulseBar/releases/tag/helper-v1.0.0")!

    public static var serviceName: String {
        #if DEBUG
        if let name = ProcessInfo.processInfo.environment["PULSEBAR_HELPER_TEST_SERVICE"] { return name }
        #endif
        return teamID + "." + serviceID
    }

    public static func requirement(identifier: String, team: String = teamID, allowMacAppStore: Bool = false) -> String {
        // Enforced by XPC on messages, not a PID lookup vulnerable to PID reuse.
        let developerID = "(certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"\(team)\")"
        // App Store distribution re-signs the client with Apple's certificate,
        // whose OU is not our Team ID. Require its Mac App Store OID and the
        // full, Apple-signed application identifier instead. See Apple TN3127.
        let store = "(certificate leaf[field.1.2.840.113635.100.6.1.9] exists and entitlement[\"com.apple.application-identifier\"] = \"\(team).\(identifier)\")"
        let signer = allowMacAppStore ? "(\(developerID) or \(store))" : developerID
        return "anchor apple generic and identifier \"\(identifier)\" and \(signer)"
    }

    public static var serviceRequirement: String {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["PULSEBAR_HELPER_TEST_SERVICE_REQUIREMENT"] { return value }
        #endif
        return requirement(identifier: serviceID)
    }

    public static var clientRequirement: String {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["PULSEBAR_HELPER_TEST_CLIENT_REQUIREMENT"] { return value }
        if let identifier = ProcessInfo.processInfo.environment["PULSEBAR_HELPER_TEST_CLIENT_ID"] {
            return requirement(identifier: identifier, allowMacAppStore: true)
        }
        #endif
        return requirement(identifier: appID, allowMacAppStore: true)
    }
}

public enum HelperError: Error, LocalizedError {
    case unavailable, timeout, invalidResponse, incompatibleVersion
    public var errorDescription: String? {
        let localizer = Localizer(language: .system)
        switch self {
        case .unavailable: return localizer(.helperUnavailable)
        case .timeout: return localizer(.helperTimeout)
        case .invalidResponse, .incompatibleVersion: return localizer(.helperIncompatible)
        }
    }
}

public struct HelperSnapshot: Codable {
    public let schemaVersion: Int
    public let helperVersion: String
    public let timestamp: TimeInterval
    public let apps: [AppUsage]
    public let processCount: Int
    public let skippedProcessCount: Int
    public let processError: String?
    public let temperatures: [TemperatureReading]
    public let temperatureTimestamp: TimeInterval

    public init(helperVersion: String, timestamp: TimeInterval, apps: [AppUsage], processCount: Int,
                skippedProcessCount: Int, processError: String?, temperatures: [TemperatureReading],
                temperatureTimestamp: TimeInterval) {
        schemaVersion = 1
        self.helperVersion = helperVersion; self.timestamp = timestamp
        self.apps = apps; self.processCount = processCount; self.skippedProcessCount = skippedProcessCount
        self.processError = processError; self.temperatures = temperatures
        self.temperatureTimestamp = temperatureTimestamp
    }

    public static func decode(_ data: Data, now: TimeInterval, refreshSeconds: Int) throws -> HelperSnapshot {
        guard data.count <= 262_144 else { throw HelperError.invalidResponse }
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.schemaVersion == 1 else { throw HelperError.incompatibleVersion }
        let maximumAge = max(5, Double(RefreshInterval.normalized(refreshSeconds)) * 1.5)
        guard value.timestamp.isFinite, value.timestamp <= now + 1, now - value.timestamp <= maximumAge,
              value.processCount >= 0, value.skippedProcessCount >= 0,
              value.apps.count <= 10, Set(value.apps.map(\.id)).count == value.apps.count,
              value.apps.allSatisfy({ !$0.id.isEmpty && $0.id.count <= 4096 && $0.name.count <= 512 &&
                  $0.processCount > 0 && ($0.cpuPercent.map { $0.isFinite && (0...100).contains($0) } ?? true) }),
              value.temperatureTimestamp.isFinite, value.temperatureTimestamp <= now + 1,
              now - value.temperatureTimestamp <= max(15, Double(refreshSeconds) * 1.5),
              value.temperatures.count <= TemperatureComponent.allCases.count,
              Set(value.temperatures.map(\.component)).count == value.temperatures.count,
              value.temperatures.allSatisfy({ TemperatureDecoder.isPlausible($0.celsius) &&
                  $0.sensorIDs.count <= 128 && $0.sensorIDs.allSatisfy { $0.count == 4 } })
        else { throw HelperError.invalidResponse }
        return value
    }
}
