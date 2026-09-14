import Foundation

public struct InterfaceCounter: Equatable {
    public let name: String
    public let index: UInt32
    public let received: UInt64
    public let sent: UInt64

    public init(name: String, index: UInt32, received: UInt64, sent: UInt64) {
        self.name = name
        self.index = index
        self.received = received
        self.sent = sent
    }
}

public struct TrafficSnapshot {
    public let timestamp: TimeInterval
    public let interfaces: [InterfaceCounter]

    public init(timestamp: TimeInterval, interfaces: [InterfaceCounter]) {
        self.timestamp = timestamp
        self.interfaces = interfaces
    }
}

public struct TrafficRate: Equatable {
    public let download: Double
    public let upload: Double
    public static let zero = TrafficRate(download: 0, upload: 0)

    public init(download: Double, upload: Double) {
        self.download = download
        self.upload = upload
    }
}

/// Tracks each interface independently so reconnects and counter resets cannot
/// turn historical traffic into a one-second speed spike.
public struct TrafficAccumulator {
    private var previous: TrafficSnapshot?
    private var window = SamplingWindow()
    public private(set) var totalReceived: UInt64 = 0
    public private(set) var totalSent: UInt64 = 0

    public init() {}

    public mutating func setRefreshInterval(_ seconds: Int) { window.configure(seconds: seconds) }

    public mutating func consume(_ snapshot: TrafficSnapshot) -> TrafficRate {
        guard let old = previous else {
            previous = snapshot
            return .zero
        }
        let elapsed = snapshot.timestamp - old.timestamp
        guard elapsed > 0 else { return .zero }
        previous = snapshot
        // Sleep, wake, or a stalled run loop needs a new baseline.
        guard window.accepts(elapsed) else { return .zero }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        for current in snapshot.interfaces {
            guard let last = old.interfaces.first(where: {
                $0.name == current.name && $0.index == current.index
            }) else { continue }
            if current.received >= last.received {
                received += current.received - last.received
            }
            if current.sent >= last.sent {
                sent += current.sent - last.sent
            }
        }
        totalReceived += received
        totalSent += sent
        return TrafficRate(download: Double(received) / elapsed,
                           upload: Double(sent) / elapsed)
    }

    public mutating func resetBaseline() { previous = nil }

    public mutating func reset() {
        previous = nil
        totalReceived = 0
        totalSent = 0
    }
}

public struct FormattedAmount: Equatable {
    public let value: String
    public let unit: String
    public var text: String { "\(value) \(unit)" }
}

public enum TrafficFormatter {
    public static func speed(_ bytesPerSecond: Double) -> FormattedAmount {
        FormattedAmount(value: megabyteValue(bytesPerSecond), unit: "MB/s")
    }

    /// A shared reference keeps related values, such as used / total memory, in the same unit.
    public static func amount(_ bytes: UInt64, unitFor referenceBytes: UInt64? = nil) -> FormattedAmount {
        let units = ["B", "KB", "MB", "GB", "TB", "PB", "EB"]
        var reference = Double(max(bytes, referenceBytes ?? bytes))
        var divisor = 1.0
        var unitIndex = 0
        // Promote at the displayed rounding boundary to avoid labels such as 1000.0 MB.
        while unitIndex < units.count - 1 && (reference * 10).rounded() >= 10_000 {
            reference /= 1_000
            divisor *= 1_000
            unitIndex += 1
        }
        return FormattedAmount(value: decimalValue(Double(bytes) / divisor), unit: units[unitIndex])
    }

    public static func total(_ bytes: UInt64) -> String {
        amount(bytes).text
    }

    private static func megabyteValue(_ bytes: Double) -> String {
        let value = bytes.isFinite ? max(0, bytes) / 1_000_000 : 0
        return decimalValue(value)
    }

    private static func decimalValue(_ value: Double) -> String {
        if value > 0 && value < 0.1 { return "<0.1" }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
