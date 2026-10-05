import Foundation

public enum TemperatureComponent: String, CaseIterable, Identifiable {
    case cpu, gpu, memory, storage, battery
    public var id: String { rawValue }
}

public struct TemperatureSensorSample: Equatable {
    public let sensorID: String
    public let component: TemperatureComponent
    public let celsius: Double

    public init(sensorID: String, component: TemperatureComponent, celsius: Double) {
        self.sensorID = sensorID
        self.component = component
        self.celsius = celsius
    }
}

/// The highest currently valid reading among the mapped sensors for a component.
/// The IDs describe which physical sensors contributed, rather than claiming a
/// package, core, proximity, or DIMM sensor represents an entire component.
public struct TemperatureReading: Equatable, Identifiable {
    public let component: TemperatureComponent
    public let celsius: Double
    public let sensorIDs: [String]
    public var id: String { component.rawValue }

    public init(component: TemperatureComponent, celsius: Double, sensorIDs: [String]) {
        self.component = component
        self.celsius = celsius
        self.sensorIDs = sensorIDs
    }

    public static func summarize(_ samples: [TemperatureSensorSample]) -> [TemperatureReading] {
        TemperatureComponent.allCases.compactMap { component in
            let valid = samples.filter {
                $0.component == component && !$0.sensorID.isEmpty && TemperatureDecoder.isPlausible($0.celsius)
            }
            guard let peak = valid.map(\.celsius).max() else { return nil }
            return TemperatureReading(component: component, celsius: peak,
                sensorIDs: Array(Set(valid.map(\.sensorID))).sorted())
        }
    }
}

public enum TemperatureDecoder {
    /// An application plausibility filter, not an operating limit or health score.
    /// Reject known zero/sentinel and implausible values instead of displaying them
    /// or carrying a previous reading forward.
    public static func isPlausible(_ celsius: Double) -> Bool {
        celsius.isFinite && (10...125).contains(celsius)
    }

    public static func decodeSMC(dataType: String, bytes: [UInt8]) -> Double? {
        let value: Double
        switch dataType {
        case "sp78":
            guard bytes.count == 2 else { return nil }
            let bits = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            value = Double(Int16(bitPattern: bits)) / 256
        case "flt ":
            guard bytes.count == 4 else { return nil }
            // AppleSMC's flt payload is IEEE 754 in little-endian byte order on
            // the supported Intel and Apple Silicon macOS machines.
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 |
                       UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            value = Double(Float(bitPattern: bits))
        default:
            return nil
        }
        return isPlausible(value) ? value : nil
    }
}
