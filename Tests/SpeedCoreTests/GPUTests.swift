import Foundation
import Testing
@testable import SpeedCore

struct GPUTests {
    @Test func deviceCounterPreservesIdleAndFullUtilization() {
        for percent in [0.0, 84.0, 85.5, 100.0] {
            let reading = GPUDecoder.usage(id: 7, model: "Apple M4",
                statistics: ["Device Utilization %": NSNumber(value: percent)])
            #expect(reading?.id == 7)
            #expect(reading?.name == "Apple M4")
            #expect(reading?.utilizationPercent == percent)
        }
    }

    @Test func invalidAndMissingCountersAreHiddenWithoutRendererFallback() {
        for percent in [-1.0, 100.01, .nan, .infinity, -.infinity] {
            #expect(GPUDecoder.usage(id: 1, model: "Apple M4",
                statistics: ["Device Utilization %": NSNumber(value: percent)]) == nil)
        }
        for stats: [String: Any] in [[:], ["Renderer Utilization %": 90],
                ["Device Utilization %": "85"], ["Device Utilization %": true]] {
            #expect(GPUDecoder.usage(id: 1, model: "Apple M4", statistics: stats) == nil)
        }
    }

    @Test func registryNamesAcceptStringAndNullTerminatedPCIData() {
        #expect(GPUDecoder.modelName("Apple M4") == "Apple M4")
        #expect(GPUDecoder.modelName(Data("AMD Radeon Pro 5500M\0".utf8)) == "AMD Radeon Pro 5500M")
        #expect(GPUDecoder.modelName("  Intel Iris Pro\n") == "Intel Iris Pro")
        #expect(GPUDecoder.modelName(Data([0xFF])) == nil)
        #expect(GPUDecoder.modelName(nil) == nil)
    }

    @Test func missingSoftwareAndVirtualNamesDoNotInventHardware() {
        for name in ["", " \0", "Unknown", "Virtual GPU", "Apple Software Renderer",
                     "GPU\nFake", String(repeating: "A", count: 161)] {
            #expect(GPUDecoder.usage(id: 1, model: name,
                statistics: ["Device Utilization %": 85]) == nil)
        }
    }

    @Test func perDevicePercentagesStayIndependent() {
        let integrated = GPUDecoder.usage(id: 1, model: "Intel Iris Pro",
            statistics: ["Device Utilization %": 30])
        let discrete = GPUDecoder.usage(id: 2, model: "AMD Radeon Pro",
            statistics: ["Device Utilization %": 80])
        #expect(integrated?.utilizationPercent == 30)
        #expect(discrete?.utilizationPercent == 80)
        #expect(integrated?.id != discrete?.id)
    }
}
