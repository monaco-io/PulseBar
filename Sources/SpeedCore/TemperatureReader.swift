import Foundation
import TemperatureSMC

/// Best-effort, read-only hardware temperatures. Call from one background queue.
/// Sampling cadence is controlled by SystemMonitor; this reader never substitutes
/// cached readings for a failed or invalid current read.
public final class TemperatureReader {
    private struct Sensor {
        let definition: TemperatureSensorDefinition
        let key: UInt32
        let dataType: String
        let dataSize: UInt32
    }

    private let platform: TemperaturePlatform
    private var connection: UInt32 = 0
    private var discovered: [Sensor]?
    private var nextAttempt: TimeInterval = 0

    public init(platform: TemperaturePlatform? = nil) {
        self.platform = platform ?? .current
    }

    deinit { PBTemperatureSMCClose(connection) }

    public func read() -> [TemperatureReading] {
        guard ProcessInfo.processInfo.systemUptime >= nextAttempt else { return [] }
        if connection == 0 {
            connection = PBTemperatureSMCOpen()
            guard connection != 0 else {
                reset(retryAfter: 60)
                return []
            }
        }
        if discovered == nil {
            discovered = TemperatureSensorCatalog.sensors(for: platform).compactMap { definition in
                let key = Self.fourCharacterCode(definition.sensorID)
                var type: UInt32 = 0
                var size: UInt32 = 0
                guard PBTemperatureSMCKeyInfo(connection, key, &type, &size) else { return nil }
                let dataType = Self.string(from: type)
                guard (dataType == "sp78" && size == 2) || (dataType == "flt " && size == 4) else { return nil }
                return Sensor(definition: definition, key: key, dataType: dataType, dataSize: size)
            }
        }
        guard let sensors = discovered, !sensors.isEmpty else {
            // Unsupported hardware should not repeat an entire metadata scan
            // on every five-second app tick. Retry occasionally so a temporary
            // unavailable service can recover without restarting the app.
            reset(retryAfter: 60)
            return []
        }

        var samples: [TemperatureSensorSample] = []
        var successfulReads = 0
        for sensor in sensors {
            var bytes = [UInt8](repeating: 0, count: Int(sensor.dataSize))
            let success = bytes.withUnsafeMutableBufferPointer {
                PBTemperatureSMCRead(connection, sensor.key, sensor.dataSize, $0.baseAddress)
            }
            guard success else { continue }
            successfulReads += 1
            guard let value = TemperatureDecoder.decodeSMC(dataType: sensor.dataType, bytes: bytes) else { continue }
            samples.append(TemperatureSensorSample(sensorID: sensor.definition.sensorID,
                component: sensor.definition.component, celsius: value))
        }
        // A dead user-client after sleep or service replacement must be reopened;
        // malformed individual sensors simply disappear from this sample.
        if successfulReads == 0 { reset(retryAfter: 5) }
        return TemperatureReading.summarize(samples)
    }

    private func reset(retryAfter delay: TimeInterval) {
        PBTemperatureSMCClose(connection)
        connection = 0
        discovered = nil
        nextAttempt = ProcessInfo.processInfo.systemUptime + delay
    }

    private static func fourCharacterCode(_ string: String) -> UInt32 {
        string.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    private static func string(from code: UInt32) -> String {
        let bytes = [UInt8(truncatingIfNeeded: code >> 24), UInt8(truncatingIfNeeded: code >> 16),
                     UInt8(truncatingIfNeeded: code >> 8), UInt8(truncatingIfNeeded: code)]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}
