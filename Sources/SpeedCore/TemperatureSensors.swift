import Darwin
import Foundation

public enum TemperaturePlatform: Equatable {
    case intel, appleM1, appleM2, appleM3, appleM4, appleM5, unknownAppleSilicon

    public static func detect(cpuBrand: String, isAppleSilicon: Bool) -> TemperaturePlatform {
        guard isAppleSilicon else { return .intel }
        // A chip's generation matters: reused four-character keys can describe
        // different sensors on different Apple Silicon generations.
        for (name, platform) in [
            ("Apple M1", TemperaturePlatform.appleM1), ("Apple M2", .appleM2),
            ("Apple M3", .appleM3), ("Apple M4", .appleM4), ("Apple M5", .appleM5)
        ] {
            if cpuBrand == name || cpuBrand.hasPrefix(name + " ") { return platform }
        }
        return .unknownAppleSilicon
    }

    static var current: TemperaturePlatform {
        var size = 0
        var brand = ""
        if sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0 && size > 0 && size < 4096 {
            var bytes = [CChar](repeating: 0, count: size)
            if sysctlbyname("machdep.cpu.brand_string", &bytes, &size, nil, 0) == 0 {
                brand = String(cString: bytes)
            }
        }
        var arm64: Int32 = 0
        var armSize = MemoryLayout<Int32>.size
        let armAvailable = sysctlbyname("hw.optional.arm64", &arm64, &armSize, nil, 0) == 0 && arm64 == 1
        #if arch(arm64)
        let isAppleSilicon = true
        #else
        let isAppleSilicon = armAvailable || brand.hasPrefix("Apple ")
        #endif
        return detect(cpuBrand: brand, isAppleSilicon: isAppleSilicon)
    }
}

public struct TemperatureSensorDefinition: Equatable {
    public let sensorID: String
    public let component: TemperatureComponent

    public init(sensorID: String, component: TemperatureComponent) {
        self.sensorID = sensorID
        self.component = component
    }
}

/// A deliberately bounded catalog of identified temperature keys. Unknown T*
/// keys, virtual thermal targets, PMU names, voltage, and power are not inferred.
/// Mapping references and supported hardware limits are in docs/TEMPERATURES.md.
public enum TemperatureSensorCatalog {
    public static func sensors(for platform: TemperaturePlatform) -> [TemperatureSensorDefinition] {
        var result: [TemperatureSensorDefinition] = []
        func append(_ component: TemperatureComponent, _ keys: [String]) {
            result += keys.map { TemperatureSensorDefinition(sensorID: $0, component: component) }
        }

        switch platform {
        case .intel:
            append(.cpu, ["TC0D", "TC0H", "TC0P", "TCAD", "TCAC", "TCBC", "TCAH", "TCBH"])
            append(.cpu, (0..<10).flatMap { ["TC\($0)c", "TC\($0)C"] })
            append(.gpu, ["TCGC", "TG0D", "TGDD", "TG0H", "TG0P"])
            append(.memory, (1...4).flatMap { ["TMA\($0)", "TMB\($0)"] })
            append(.memory, ["TM0D", "TM1D", "TM2D", "TM3D", "TMXD"])
        case .appleM1:
            append(.cpu, ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b"])
            append(.gpu, ["Tg05", "Tg0D", "Tg0L", "Tg0T"])
            append(.memory, ["Tm02", "Tm06", "Tm08", "Tm09"])
        case .appleM2:
            append(.cpu, ["Tp1h", "Tp1t", "Tp1p", "Tp1l", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j"])
            append(.gpu, ["Tg0f", "Tg0j"])
        case .appleM3:
            append(.cpu, ["Te05", "Te0L", "Te0P", "Te0S", "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E", "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E"])
            append(.gpu, ["Tf14", "Tf18", "Tf19", "Tf1A", "Tf24", "Tf28", "Tf29", "Tf2A"])
        case .appleM4:
            append(.cpu, ["Te05", "Te0S", "Te09", "Te0H", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"])
            append(.gpu, ["Tg0G", "Tg0H", "Tg1U", "Tg1k", "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k"])
        case .appleM5:
            append(.cpu, ["Tp00", "Tp04", "Tp08", "Tp0C", "Tp0G", "Tp0K", "Tp0O", "Tp0R", "Tp0U", "Tp0X", "Tp0a", "Tp0d", "Tp0g", "Tp0j", "Tp0m", "Tp0p", "Tp0u", "Tp0y"])
            append(.gpu, ["Tg0U", "Tg0X", "Tg0d", "Tg0g", "Tg0j", "Tg1Y", "Tg1c", "Tg1g"])
        case .unknownAppleSilicon:
            break
        }

        append(.storage, (0..<10).flatMap { ["TH\($0)A", "TH\($0)B", "TH\($0)C"] })
        if platform != .intel { append(.storage, ["TH0x"]) }
        append(.battery, platform == .intel ? ["TB1T"] : ["TB1T", "TB2T"])
        return result
    }
}
