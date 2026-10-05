import Foundation
import IOKit.ps
import Testing
@testable import SpeedCore

struct BatteryTests {
    private func source(_ overrides: [String: Any] = [:]) -> [String: Any] {
        var fields: [String: Any] = [kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSIsPresentKey: true,
            kIOPSCurrentCapacityKey: 60, kIOPSMaxCapacityKey: 100,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue, kIOPSIsChargingKey: false,
            kIOPSIsChargedKey: false, kIOPSTimeToEmptyKey: 120]
        fields.merge(overrides) { _, replacement in replacement }
        return fields
    }

    private func decode(_ fields: [String: Any], smart: [[String: Any]] = []) -> BatterySnapshot? {
        BatteryDecoder.decode(powerSources: [fields], smartBatteries: smart, timestamp: 1)
    }

    @Test func onlyPresentInternalHostBatteriesAreAccepted() {
        #expect(BatteryDecoder.decode(powerSources: [], timestamp: 1) == nil)
        #expect(decode(source([kIOPSTypeKey: kIOPSUPSType])) == nil)
        #expect(decode(source([kIOPSTypeKey: "Accessory" ])) == nil)
        #expect(decode(source([kIOPSIsPresentKey: false])) == nil)
        #expect(decode(source([kIOPSIsPresentKey: 1])) == nil)
        var missingPresence = source()
        missingPresence.removeValue(forKey: kIOPSIsPresentKey)
        #expect(decode(missingPresence) == nil)
        var missingType = source()
        missingType.removeValue(forKey: kIOPSTypeKey)
        #expect(decode(missingType) == nil)
        #expect(BatteryDecoder.decode(powerSources: [source(), source()], timestamp: 1) == nil)
        #expect(BatteryDecoder.decode(powerSources: [source()], timestamp: .nan) == nil)
        let mixed = BatteryDecoder.decode(powerSources: [source([kIOPSTypeKey: kIOPSUPSType]), source()], timestamp: 1)
        #expect(mixed?.chargePercent == 60)
    }

    @Test func chargeUsesMatchingUnitsAndAllowsRealEmptyCharge() {
        #expect(decode(source())?.chargePercent == 60)
        #expect(decode(source([kIOPSCurrentCapacityKey: 3_000, kIOPSMaxCapacityKey: 5_000]))?.chargePercent == 60)
        #expect(decode(source([kIOPSCurrentCapacityKey: 0]))?.chargePercent == 0)
        for invalid: Any in [-1, 101, Double.nan, Double.infinity, 3.5, true, "60"] {
            #expect(decode(source([kIOPSCurrentCapacityKey: invalid]))?.chargePercent == nil)
        }
        #expect(decode(source([kIOPSMaxCapacityKey: 0]))?.chargePercent == nil)
        var fields = source()
        fields.removeValue(forKey: kIOPSCurrentCapacityKey)
        #expect(decode(fields)?.chargePercent == nil)
        #expect(decode(fields)?.powerState == .onBattery)
    }

    @Test func powerStateDistinguishesChargeFromExternalSupplyAndChargedState() {
        #expect(decode(source())?.powerState == .onBattery)
        #expect(decode(source([kIOPSPowerSourceStateKey: kIOPSACPowerValue]))?.powerState == .externalPower)
        #expect(decode(source([kIOPSPowerSourceStateKey: kIOPSACPowerValue, kIOPSIsChargedKey: true]))?.powerState == .full)
        #expect(decode(source([kIOPSPowerSourceStateKey: kIOPSACPowerValue, kIOPSIsChargedKey: true,
                              kIOPSIsChargingKey: true]))?.powerState == .charging)
        // An inconsistent/unknown source must not infer discharging from charge %.
        #expect(decode(source([kIOPSIsChargingKey: true]))?.powerState == nil)
        #expect(decode(source([kIOPSPowerSourceStateKey: "Unknown"]))?.powerState == nil)
        #expect(decode(source([kIOPSIsChargingKey: 0]))?.powerState == nil)
        var unknownCharge = source([kIOPSPowerSourceStateKey: kIOPSACPowerValue, kIOPSIsChargedKey: true])
        unknownCharge.removeValue(forKey: kIOPSIsChargingKey)
        #expect(decode(unknownCharge)?.powerState == .externalPower)
        #expect(decode(unknownCharge)?.timeEstimate == nil)
    }

    @Test func timeEstimatesUseOnlyTheOfficialActiveDirection() {
        #expect(decode(source())?.timeEstimate == BatteryTimeEstimate(kind: .untilEmpty, minutes: 120))
        let charging = source([kIOPSPowerSourceStateKey: kIOPSACPowerValue, kIOPSIsChargingKey: true,
                               kIOPSTimeToFullChargeKey: 45])
        #expect(decode(charging)?.timeEstimate == BatteryTimeEstimate(kind: .untilFull, minutes: 45))
        #expect(decode(source([kIOPSPowerSourceStateKey: kIOPSACPowerValue]))?.timeEstimate == nil)
        #expect(decode(source([kIOPSIsChargingKey: true]))?.timeEstimate == nil)
        for invalid: Any in [-1, 0, 65_535, Double.nan, Double.infinity, 1.5, true] {
            #expect(decode(source([kIOPSTimeToEmptyKey: invalid]))?.timeEstimate == nil)
        }
        var unknown = charging
        unknown.removeValue(forKey: kIOPSTimeToFullChargeKey)
        #expect(decode(unknown)?.timeEstimate == nil)
    }

    @Test func healthUsesNativeCapacityPairWithoutPercentageUnitMixing() {
        let smart: [String: Any] = ["BatteryInstalled": true, "AppleRawMaxCapacity": 4_500,
                                   "MaxCapacity": 100, "DesignCapacity": 5_000, "CycleCount": 230]
        #expect(decode(source(), smart: [smart])?.healthPercent == 90)
        #expect(decode(source(), smart: [smart])?.cycleCount == 230)
        #expect(decode(source(), smart: [["BatteryInstalled": true, "MaxCapacity": 4_500,
                                       "DesignCapacity": 5_000]])?.healthPercent == 90)
        #expect(decode(source(), smart: [["BatteryInstalled": true, "MaxCapacity": 100,
                                       "DesignCapacity": 5_000]])?.healthPercent == nil)
        #expect(decode(source(), smart: [["BatteryInstalled": true, "AppleRawMaxCapacity": 5_200,
                                       "DesignCapacity": 5_000]])?.healthPercent == 100)
        #expect(decode(source(), smart: [["BatteryInstalled": true, "AppleRawMaxCapacity": 65_535,
                                       "DesignCapacity": 5_000]])?.healthPercent == nil)
        #expect(decode(source(), smart: [["BatteryInstalled": true, "AppleRawMaxCapacity": 4_500,
                                       "DesignCapacity": 65_535]])?.healthPercent == nil)
        #expect(decode(source(), smart: [["BatteryInstalled": true, "AppleRawMaxCapacity": true,
                                       "DesignCapacity": 5_000]])?.healthPercent == nil)
        #expect(decode(source(), smart: [smart, smart])?.healthPercent == nil)
        #expect(decode(source(), smart: [smart, smart])?.cycleCount == nil)
        #expect(decode(source(), smart: [["BatteryInstalled": false, "AppleRawMaxCapacity": 4_500,
                                       "DesignCapacity": 5_000, "CycleCount": 230]])?.healthPercent == nil)
    }

    @Test func absentMetadataAndInvalidCyclesStayUnavailable() {
        #expect(decode(source())?.healthPercent == nil)
        #expect(decode(source())?.cycleCount == nil)
        #expect(decode(source(), smart: [["BatteryInstalled": true, "CycleCount": 0]])?.cycleCount == 0)
        for invalid: Any in [-1, 20_001, 65_535, UInt32.max, Double.infinity, 1.5, true] {
            #expect(decode(source(), smart: [["BatteryInstalled": true, "CycleCount": invalid]])?.cycleCount == nil)
        }
        #expect(decode(source([kIOPSTypeKey: kIOPSUPSType]),
                       smart: [["BatteryInstalled": true, "CycleCount": 230]]) == nil)
    }
}
