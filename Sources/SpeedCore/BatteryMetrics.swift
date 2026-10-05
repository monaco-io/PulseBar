import CoreFoundation
import Foundation
import IOKit.ps

public enum BatteryPowerState: Equatable {
    case charging, full, onBattery, externalPower
}

public struct BatteryTimeEstimate: Equatable {
    public enum Kind: Equatable { case untilEmpty, untilFull }
    public let kind: Kind
    public let minutes: Int

    public init(kind: Kind, minutes: Int) {
        self.kind = kind
        self.minutes = minutes
    }
}

/// A present internal host battery. Every metric is optional: an unavailable or
/// invalid value is not a zero, and a desktop has no snapshot at all.
public struct BatterySnapshot: Equatable {
    public let timestamp: TimeInterval
    public let chargePercent: Double?
    public let powerState: BatteryPowerState?
    /// Full-charge capacity relative to design capacity, not a health score.
    public let healthPercent: Double?
    public let cycleCount: Int?
    public let timeEstimate: BatteryTimeEstimate?

    public init(timestamp: TimeInterval, chargePercent: Double?, powerState: BatteryPowerState?,
                healthPercent: Double? = nil, cycleCount: Int? = nil,
                timeEstimate: BatteryTimeEstimate? = nil) {
        self.timestamp = timestamp
        self.chargePercent = chargePercent
        self.powerState = powerState
        self.healthPercent = healthPercent
        self.cycleCount = cycleCount
        self.timeEstimate = timeEstimate
    }
}

enum BatteryDecoder {
    static func decode(powerSources: [[String: Any]], smartBatteries: [[String: Any]] = [],
                       timestamp: TimeInterval) -> BatterySnapshot? {
        guard timestamp.isFinite else { return nil }
        let internalSources = powerSources.filter {
            $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType &&
            boolean($0[kIOPSIsPresentKey]) == true
        }
        // Modern supported Macs expose one host battery. With ambiguous sources,
        // do not attach another battery's state or registry metadata to this UI.
        guard internalSources.count == 1, let source = internalSources.first else { return nil }

        var chargePercent: Double?
        if let current = integer(source[kIOPSCurrentCapacityKey]), current >= 0,
           let maximum = integer(source[kIOPSMaxCapacityKey]), maximum > 0, current <= maximum {
            // Both keys belong to the same public dictionary and capacity unit.
            chargePercent = Double(current) / Double(maximum) * 100
        }

        let charging = boolean(source[kIOPSIsChargingKey])
        let charged = boolean(source[kIOPSIsChargedKey])
        let supply = source[kIOPSPowerSourceStateKey] as? String
        let state: BatteryPowerState?
        if supply == kIOPSACPowerValue {
            if charging == true { state = .charging }
            else if charging == false && charged == true { state = .full }
            else { state = .externalPower }
        } else if supply == kIOPSBatteryPowerValue && charging == false {
            state = .onBattery
        } else {
            state = nil
        }

        let timeEstimate: BatteryTimeEstimate?
        if state == .charging, let minutes = validMinutes(source[kIOPSTimeToFullChargeKey]) {
            timeEstimate = BatteryTimeEstimate(kind: .untilFull, minutes: minutes)
        } else if state == .onBattery, let minutes = validMinutes(source[kIOPSTimeToEmptyKey]) {
            timeEstimate = BatteryTimeEstimate(kind: .untilEmpty, minutes: minutes)
        } else {
            timeEstimate = nil
        }

        let installed = smartBatteries.filter { boolean($0["BatteryInstalled"]) == true }
        let smartBattery = installed.count == 1 ? installed.first : nil
        let healthPercent = smartBattery.flatMap(maximumCapacityPercent)
        let cycleCount = smartBattery.flatMap { properties -> Int? in
            guard let cycles = integer(properties["CycleCount"]), (0...20_000).contains(cycles) else { return nil }
            return cycles
        }
        return BatterySnapshot(timestamp: timestamp, chargePercent: chargePercent, powerState: state,
                               healthPercent: healthPercent, cycleCount: cycleCount, timeEstimate: timeEstimate)
    }

    private static func maximumCapacityPercent(_ properties: [String: Any]) -> Double? {
        // AppleSmartBattery may normalize MaxCapacity to 100 on Apple Silicon.
        // AppleRawMaxCapacity and DesignCapacity are the native mAh pair. On older
        // drivers, only use MaxCapacity when it is a native capacity (>100).
        // Never mix public IOPS percentages with registry capacity values.
        let maximumValue = properties["AppleRawMaxCapacity"] ?? properties["MaxCapacity"]
        guard let maximum = integer(maximumValue), (101...50_000).contains(maximum),
              let design = integer(properties["DesignCapacity"]), (101...50_000).contains(design) else { return nil }
        let percentage = Double(maximum) / Double(design) * 100
        // A new battery can exceed its rated design capacity. Reject incompatible
        // units/sentinels, then normalize the retained-capacity display to 100%.
        guard percentage > 0, percentage <= 120 else { return nil }
        return min(100, percentage)
    }

    private static func validMinutes(_ value: Any?) -> Int? {
        // IOPS estimates are integer minutes; -1 means still calculating. Huge
        // firmware sentinels and implausible estimates are not useful countdowns.
        guard let minutes = integer(value), (1...10_080).contains(minutes) else { return nil }
        return minutes
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return Int(exactly: number.doubleValue)
    }

    private static func boolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
}
