import Foundation
import Testing
@testable import SpeedCore

struct TemperatureTests {
    @Test func intelSMCTemperatureUsesSignedBigEndianFixedPoint() {
        #expect(TemperatureDecoder.decodeSMC(dataType: "sp78", bytes: [0x37, 0x80]) == 55.5)
        #expect(TemperatureDecoder.decodeSMC(dataType: "sp78", bytes: [0x2A, 0x40]) == 42.25)
        #expect(TemperatureDecoder.decodeSMC(dataType: "sp78", bytes: [0x0A, 0x00]) == 10)
        #expect(TemperatureDecoder.decodeSMC(dataType: "sp78", bytes: [0x7D, 0x00]) == 125)
        // A negative signed value must not become a large unsigned temperature.
        #expect(TemperatureDecoder.decodeSMC(dataType: "sp78", bytes: [0xFF, 0x00]) == nil)
        #expect(TemperatureDecoder.decodeSMC(dataType: "sp78", bytes: [0x80, 0x00]) == nil)
    }

    @Test func appleSiliconSMCTemperatureUsesLittleEndianIEEE754() {
        // 0x42650000 encodes 57.25; these bytes exercise the native SMC order.
        #expect(TemperatureDecoder.decodeSMC(dataType: "flt ", bytes: [0x00, 0x00, 0x65, 0x42]) == 57.25)
        #expect(TemperatureDecoder.decodeSMC(dataType: "flt ", bytes: floatBytes(10)) == 10)
        #expect(TemperatureDecoder.decodeSMC(dataType: "flt ", bytes: floatBytes(125)) == 125)
        #expect(TemperatureDecoder.decodeSMC(dataType: "flt ", bytes: [0x42, 0x65, 0x00, 0x00]) == nil)
    }

    @Test func unsupportedTypesAndIncorrectPayloadSizesAreMissingReadings() {
        for type in ["", "flt", "FLT ", "sp79", "ui16", "fpe2"] {
            #expect(TemperatureDecoder.decodeSMC(dataType: type, bytes: [0x37, 0x80]) == nil)
            #expect(TemperatureDecoder.decodeSMC(dataType: type, bytes: floatBytes(55.5)) == nil)
        }
        let invalidFixedPointSizes: [[UInt8]] = [[], [0x37], [0x37, 0x80, 0x00], [0x37, 0x80, 0x00, 0x00]]
        for bytes in invalidFixedPointSizes {
            #expect(TemperatureDecoder.decodeSMC(dataType: "sp78", bytes: bytes) == nil)
        }
        let invalidFloatSizes: [[UInt8]] = [[], [0x00], [0x00, 0x00, 0x65], [0x00, 0x00, 0x65, 0x42, 0x00]]
        for bytes in invalidFloatSizes {
            #expect(TemperatureDecoder.decodeSMC(dataType: "flt ", bytes: bytes) == nil)
        }
    }

    @Test func zeroSentinelsNonfiniteValuesAndOutOfRangeValuesStayHidden() {
        let invalidFloats: [Float] = [0, -0.0, -1, .nan, .infinity, -.infinity, .leastNonzeroMagnitude, 9.99, 125.01, 255]
        for value in invalidFloats {
            #expect(TemperatureDecoder.decodeSMC(dataType: "flt ", bytes: floatBytes(value)) == nil)
        }
        let invalidFixedPointValues: [[UInt8]] = [[0x00, 0x00], [0x09, 0xFF], [0x7D, 0x01], [0x7F, 0xFF], [0xFF, 0xFF]]
        for bytes in invalidFixedPointValues {
            #expect(TemperatureDecoder.decodeSMC(dataType: "sp78", bytes: bytes) == nil)
        }
    }

    @Test func componentSummaryUsesHottestValidSensorAndKeepsItsEvidence() {
        let readings = TemperatureReading.summarize([
            sample("TC1C", .cpu, 49.5), sample("TC0P", .cpu, 58.25),
            sample("TC1C", .cpu, 51), sample("invalid-zero", .cpu, 0),
            sample("invalid-nan", .cpu, .nan), sample("invalid-high", .cpu, 126),
            sample("", .cpu, 99), sample("TG0D", .gpu, 45)
        ])
        #expect(readings.count == 2)
        #expect(readings.first?.component == .cpu)
        #expect(readings.first?.celsius == 58.25)
        #expect(readings.first?.sensorIDs == ["TC0P", "TC1C"])
        #expect(readings.last?.component == .gpu)
        #expect(readings.last?.celsius == 45)
        #expect(readings.last?.sensorIDs == ["TG0D"])
    }

    @Test func missingOrInvalidComponentsDoNotProduceZeroTemperatureRows() {
        #expect(TemperatureReading.summarize([]).isEmpty)
        #expect(TemperatureReading.summarize([
            sample("missing", .cpu, 0), sample("bad", .memory, .nan),
            sample("infinite", .storage, .infinity), sample("negative", .battery, -1)
        ]).isEmpty)
        let readings = TemperatureReading.summarize([sample("TC0P", .cpu, 50)])
        #expect(readings.map(\.component) == [.cpu])
        #expect(readings.allSatisfy { $0.celsius > 0 })
    }

    @Test func summariesHaveStableComponentOrderRegardlessOfSensorOrder() {
        let readings = TemperatureReading.summarize([
            sample("TB0T", .battery, 31), sample("TH0P", .storage, 42),
            sample("TM0P", .memory, 44), sample("TG0D", .gpu, 52),
            sample("TC0P", .cpu, 57)
        ])
        #expect(readings.map(\.component) == [.cpu, .gpu, .memory, .storage, .battery])
        #expect(Set(readings.map(\.id)).count == readings.count)
    }

    @Test func platformDetectionRequiresArchitectureAndAnExactKnownChipGeneration() {
        #expect(TemperaturePlatform.detect(cpuBrand: "Intel(R) Core(TM) i7", isAppleSilicon: false) == .intel)
        #expect(TemperaturePlatform.detect(cpuBrand: "Apple M1", isAppleSilicon: false) == .intel)
        let knownBrands: [(String, TemperaturePlatform)] = [
            ("Apple M1", .appleM1), ("Apple M1 Pro", .appleM1),
            ("Apple M2 Max", .appleM2), ("Apple M3 Ultra", .appleM3),
            ("Apple M4", .appleM4), ("Apple M5 Pro", .appleM5)
        ]
        for (brand, platform) in knownBrands {
            #expect(TemperaturePlatform.detect(cpuBrand: brand, isAppleSilicon: true) == platform)
        }
        for brand in ["", "Apple M6", "Apple M10", "Apple M1foo", "M1", "Unknown Apple Silicon"] {
            #expect(TemperaturePlatform.detect(cpuBrand: brand, isAppleSilicon: true) == .unknownAppleSilicon)
        }
    }

    @Test func catalogMapsIdentifiedSensorsToTheirPhysicalComponent() {
        let knownSensors: [(TemperaturePlatform, String, TemperatureComponent)] = [
            (.intel, "TC0D", .cpu), (.intel, "TCAD", .cpu), (.intel, "TC1c", .cpu),
            (.intel, "TG0D", .gpu), (.intel, "TCGC", .gpu),
            (.intel, "TMA1", .memory), (.intel, "TMB4", .memory), (.intel, "TM0D", .memory),
            (.intel, "TH0A", .storage), (.intel, "TB1T", .battery),
            (.appleM1, "Tp09", .cpu), (.appleM1, "Tg05", .gpu), (.appleM1, "Tm02", .memory),
            (.appleM2, "Tp1h", .cpu), (.appleM2, "Tg0f", .gpu),
            (.appleM3, "Te05", .cpu), (.appleM3, "Tf14", .gpu),
            (.appleM4, "Tp0V", .cpu), (.appleM4, "Tg0G", .gpu),
            (.appleM5, "Tp00", .cpu), (.appleM5, "Tg0U", .gpu),
            (.appleM4, "TH0x", .storage), (.appleM4, "TB2T", .battery)
        ]
        for (platform, key, component) in knownSensors {
            let definition = TemperatureSensorCatalog.sensors(for: platform).first { $0.sensorID == key }
            #expect(definition?.component == component)
        }
    }

    @Test func catalogDoesNotInferAmbiguousPMUMainboardVoltageOrVirtualSensors() {
        let platforms: [TemperaturePlatform] = [.intel, .appleM1, .appleM2, .appleM3, .appleM4, .appleM5, .unknownAppleSilicon]
        let ambiguousKeys = ["TM0P", "Tm0P", "TM0S", "TM0V", "TMBS", "TpMU", "TpMP", "PMU ",
                             "VC0C", "VM0R", "PC0C", "TC0E", "TC0F", "Tzzz"]
        for platform in platforms {
            let definitions = TemperatureSensorCatalog.sensors(for: platform)
            let keys = definitions.map(\.sensorID)
            #expect(Set(keys).count == keys.count)
            #expect(keys.allSatisfy { $0.utf8.count == 4 })
            for key in ambiguousKeys {
                #expect(!keys.contains(key))
            }
        }
    }

    @Test func generationSpecificKeysAreNotReusedToInventUnknownChipOrMemorySensors() {
        let unknown = TemperatureSensorCatalog.sensors(for: .unknownAppleSilicon)
        #expect(unknown.allSatisfy { $0.component == .storage || $0.component == .battery })
        let generationsWithoutMappedMemory: [TemperaturePlatform] = [.appleM2, .appleM3, .appleM4, .appleM5]
        for platform in generationsWithoutMappedMemory {
            let definitions = TemperatureSensorCatalog.sensors(for: platform)
            #expect(!definitions.contains { $0.component == .memory })
            #expect(!definitions.contains { $0.sensorID == "Tm02" })
        }
        #expect(!TemperatureSensorCatalog.sensors(for: .intel).contains { $0.sensorID == "Tp09" })
        #expect(!TemperatureSensorCatalog.sensors(for: .appleM1).contains { $0.sensorID == "Tp1h" })
    }

    private func floatBytes(_ value: Float) -> [UInt8] {
        let bits = value.bitPattern
        return (0..<4).map { UInt8(truncatingIfNeeded: bits >> ($0 * 8)) }
    }

    private func sample(_ id: String, _ component: TemperatureComponent, _ celsius: Double) -> TemperatureSensorSample {
        TemperatureSensorSample(sensorID: id, component: component, celsius: celsius)
    }
}
