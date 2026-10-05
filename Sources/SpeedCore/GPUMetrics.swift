import Foundation

/// One hardware accelerator's driver-reported device utilization. Different
/// devices are kept separate; their percentages must not be added together.
public struct GPUUsage: Equatable, Identifiable {
    public let id: UInt64
    public let name: String
    public let utilizationPercent: Double

    public init(id: UInt64, name: String, utilizationPercent: Double) {
        self.id = id
        self.name = name
        self.utilizationPercent = utilizationPercent
    }
}

enum GPUDecoder {
    static func usage(id: UInt64, model: Any?, statistics: [String: Any]) -> GPUUsage? {
        guard let name = modelName(model),
              let number = statistics["Device Utilization %"] as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let percent = number.doubleValue
        // 0% is a valid idle GPU. Reject invalid counters instead of clamping
        // them, reusing old values, or substituting renderer-only utilization.
        guard percent.isFinite, (0...100).contains(percent) else { return nil }
        return GPUUsage(id: id, name: name, utilizationPercent: percent)
    }

    static func modelName(_ value: Any?) -> String? {
        let decoded: String
        if let string = value as? String {
            decoded = string
        } else if let data = value as? Data,
                  let string = String(data: data, encoding: .utf8) {
            decoded = string
        } else { return nil }
        let name = decoded.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0")))
        guard !name.isEmpty, name.count <= 160,
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        // IORegistry can expose software renderers or virtual display devices.
        // They must not be presented as host hardware.
        let lower = name.lowercased()
        guard !lower.contains("virtual"), !lower.contains("software"),
              !lower.contains("unknown") else { return nil }
        return name
    }
}
