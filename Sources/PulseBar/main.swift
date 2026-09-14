import AppKit
import Foundation
import SpeedCore

// A read-only diagnostic path exercises the exact same reader and accumulator
// as the menu bar, without launching a second GUI instance.
if let index = CommandLine.arguments.firstIndex(of: "--sample") {
    guard CommandLine.arguments.indices.contains(index + 1),
          let count = Int(CommandLine.arguments[index + 1]), (1...60).contains(count) else {
        fputs("Usage: PulseBar --sample <1...60>\n", stderr)
        exit(2)
    }
    let reader = InterfaceReader()
    let systemReader = SystemReader()
    var interval = 1
    if let intervalIndex = CommandLine.arguments.firstIndex(of: "--interval") {
        guard CommandLine.arguments.indices.contains(intervalIndex + 1),
              let value = Int(CommandLine.arguments[intervalIndex + 1]), RefreshInterval.range.contains(value) else {
            fputs("Usage: PulseBar --sample <1...60> [--interval <1...60>]\n", stderr)
            exit(2)
        }
        interval = value
    }
    var accumulator = TrafficAccumulator()
    var cpuAccumulator = CPUAccumulator()
    var diskAccumulator = DiskAccumulator()
    accumulator.setRefreshInterval(interval)
    cpuAccumulator.setRefreshInterval(interval)
    diskAccumulator.setRefreshInterval(interval)
    var hadError = false
    for sample in 0..<count {
        var row: [String: Any] = ["sample": sample, "uptime": ProcessInfo.processInfo.systemUptime, "refreshSeconds": interval]
        var errors: [String: String] = [:]
        do {
            let snapshot = try reader.read()
            let rate = accumulator.consume(snapshot)
            row.merge([
                "uptime": snapshot.timestamp,
                "downloadBytesPerSecond": rate.download,
                "uploadBytesPerSecond": rate.upload,
                "sessionReceived": accumulator.totalReceived,
                "sessionSent": accumulator.totalSent,
                "interfaces": snapshot.interfaces.map { ["name": $0.name, "received": $0.received, "sent": $0.sent] as [String: Any] }
            ]) { _, new in new }
        } catch {
            errors["network"] = error.localizedDescription
            accumulator.resetBaseline()
        }
        do {
            if let cpu = cpuAccumulator.consume(try systemReader.readCPU()) {
                row["cpu"] = ["usedPercent": cpu.usedPercent, "userPercent": cpu.userPercent, "systemPercent": cpu.systemPercent]
            } else { row["cpu"] = NSNull() }
        } catch {
            errors["cpu"] = error.localizedDescription
            cpuAccumulator.resetBaseline()
        }
        do {
            let memory = try systemReader.readMemory()
            row["memory"] = ["usedBytes": memory.usedBytes, "totalBytes": memory.totalBytes,
                             "usedPercent": memory.usedPercent, "appBytes": memory.appBytes,
                             "wiredBytes": memory.wiredBytes, "compressedBytes": memory.compressedBytes] as [String: Any]
        } catch { errors["memory"] = error.localizedDescription }
        do {
            let snapshot = try systemReader.readDisks()
            let rate = diskAccumulator.consume(snapshot)
            row["disk"] = [
                "readBytesPerSecond": rate.map { $0.read as Any } ?? NSNull(),
                "writeBytesPerSecond": rate.map { $0.write as Any } ?? NSNull(),
                "sessionRead": diskAccumulator.totalRead,
                "sessionWritten": diskAccumulator.totalWritten,
                "devices": snapshot.disks.map {
                    ["id": $0.id, "name": $0.name, "readBytes": $0.readBytes, "writtenBytes": $0.writtenBytes] as [String: Any]
                }
            ] as [String: Any]
        } catch {
            errors["disk"] = error.localizedDescription
            diskAccumulator.resetBaseline()
        }
        if !errors.isEmpty { row["errors"] = errors; hadError = true }
        do {
            let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
            print(String(decoding: data, as: UTF8.self))
            fflush(stdout)
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
        if sample + 1 < count { Thread.sleep(forTimeInterval: Double(interval)) }
    }
    exit(hadError ? 1 : 0)
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
