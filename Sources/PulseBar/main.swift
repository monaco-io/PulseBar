import AppKit
import Foundation
import SpeedCore

private func hardwareDiagnostics(gpus: [GPUUsage], capacity: StorageCapacity?, battery: BatterySnapshot?) -> [String: Any] {
    var payload: [String: Any] = [
        "gpuUsage": gpus.map { ["id": $0.id, "name": $0.name, "utilizationPercent": $0.utilizationPercent] as [String: Any] },
        "storageCapacity": NSNull(), "battery": NSNull()
    ]
    if let capacity {
        payload["storageCapacity"] = ["name": capacity.name, "path": capacity.path, "totalBytes": capacity.totalBytes,
                                      "availableBytes": capacity.availableBytes, "usedBytes": capacity.usedBytes,
                                      "usedPercent": capacity.usedPercent] as [String: Any]
    }
    if let battery {
        let state: String?
        switch battery.powerState {
        case .charging?: state = "charging"
        case .full?: state = "full"
        case .onBattery?: state = "onBattery"
        case .externalPower?: state = "externalPower"
        case nil: state = nil
        }
        payload["battery"] = [
            "chargePercent": battery.chargePercent as Any? ?? NSNull(),
            "powerState": state as Any? ?? NSNull(),
            "maximumCapacityPercent": battery.healthPercent as Any? ?? NSNull(),
            "cycleCount": battery.cycleCount as Any? ?? NSNull(),
            "timeEstimate": battery.timeEstimate.map {
                ["kind": $0.kind == .untilFull ? "untilFull" : "untilEmpty", "minutes": $0.minutes] as [String: Any]
            } as Any? ?? NSNull()
        ] as [String: Any]
    }
    return payload
}

#if DEBUG
if CommandLine.arguments.contains("--preview-hardware") || Bundle.main.object(forInfoDictionaryKey: "PulseBarHardwarePreview") as? Bool == true {
    HardwarePreview.run()
}

// Exercise the real timer, background process sampler, and event store without
// opening a window, touching user history, or requesting notification permission.
if CommandLine.arguments.contains("--verify-insights") {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PulseBar-check-" + UUID().uuidString)
    let store = PerformanceEventStore(url: directory.appendingPathComponent("events.json"))
    let monitor = SystemMonitor(eventStore: store)
    monitor.start(refreshSeconds: 1)
    RunLoop.main.run(until: Date().addingTimeInterval(13))
    let temperatures = monitor.temperatures
    let hardware = hardwareDiagnostics(gpus: monitor.gpuUsage, capacity: monitor.storageCapacity, battery: monitor.battery)
    monitor.stop()
    let stoppedHardwareCleared = monitor.gpuUsage.isEmpty && monitor.storageCapacity == nil && monitor.battery == nil && monitor.temperatures.isEmpty
    do {
        let saved = try store.load()
        var payload: [String: Any] = [
            "stoppedHardwareCleared": stoppedHardwareCleared,
            "cpuSamples": monitor.resources.cpuHistory.count,
            "memorySamples": monitor.resources.memoryHistory.count,
            "diskSamples": monitor.resources.diskHistory.count,
            "networkSamples": monitor.history.count,
            "swapSamples": monitor.resources.swapHistory.count,
            "temperatures": temperatures.map { ["component": $0.component.rawValue,
                                                  "celsius": $0.celsius, "sensorIDs": $0.sensorIDs] as [String: Any] },
            "memoryPressure": monitor.resources.pressure?.rawValue as Any? ?? NSNull(),
            "sampledProcesses": monitor.processCount,
            "events": monitor.events.count,
            "savedEvents": saved.count,
            "eventKinds": saved.map { $0.kind.rawValue },
            "eventRankingCounts": saved.map { ["cpu": $0.topCPU.count, "memory": $0.topMemory.count] },
            "eventStoreError": monitor.eventStoreError?.localizedDescription as Any? ?? NSNull()
        ]
        payload.merge(hardware) { _, new in new }
        print(String(decoding: try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]), as: UTF8.self))
        try? FileManager.default.removeItem(at: directory)
        exit(monitor.resources.cpuHistory.count >= 5 && monitor.processCount > 0 && saved == monitor.events
             && !monitor.resources.hasError && monitor.eventStoreError == nil && stoppedHardwareCleared ? 0 : 1)
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        try? FileManager.default.removeItem(at: directory)
        exit(1)
    }
}
#endif

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
    let temperatureReader = TemperatureReader()
    let gpuReader = GPUReader()
    let capacityReader = StorageCapacityReader()
    let batteryReader = BatteryReader()
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
    let processReader = ProcessReader()
    var processAccumulator = ProcessAccumulator()
    accumulator.setRefreshInterval(interval)
    cpuAccumulator.setRefreshInterval(interval)
    diskAccumulator.setRefreshInterval(interval)
    processAccumulator.setRefreshInterval(interval)
    var hadError = false
    for sample in 0..<count {
        autoreleasepool {
            var row: [String: Any] = ["sample": sample, "uptime": ProcessInfo.processInfo.systemUptime, "refreshSeconds": interval]
            var errors: [String: String] = [:]
            // Optional hardware sensors are absent on unsupported machines;
            // they must not turn an otherwise healthy diagnostic into an error.
            row["temperatures"] = temperatureReader.read().map { reading in
                ["component": reading.component.rawValue, "celsius": reading.celsius,
                 "sensorIDs": reading.sensorIDs] as [String: Any]
            }
            row.merge(hardwareDiagnostics(gpus: gpuReader.read(), capacity: capacityReader.read(), battery: batteryReader.read())) { _, new in new }
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
            do { row["memoryPressure"] = try systemReader.readMemoryPressure().rawValue }
            catch { errors["memoryPressure"] = error.localizedDescription }
            do {
                let swap = try systemReader.readSwap()
                row["swap"] = ["usedBytes": swap.usedBytes, "totalBytes": swap.totalBytes]
            } catch { errors["swap"] = error.localizedDescription }
            do {
                let snapshot = try processReader.read()
                let apps = processAccumulator.consume(snapshot)
                let encodeApp: (AppUsage) -> [String: Any] = { app in
                    ["name": app.name, "cpuPercent": app.cpuPercent.map { $0 as Any } ?? NSNull(),
                     "memoryBytes": app.memoryBytes, "processCount": app.processCount]
                }
                row["apps"] = ["topCPU": AppRanking.cpu(apps).map(encodeApp),
                               "topMemory": AppRanking.memory(apps).map(encodeApp),
                               "sampledProcesses": snapshot.processes.count, "skippedProcesses": snapshot.skippedCount]
            } catch { errors["apps"] = error.localizedDescription; processAccumulator.resetBaseline() }
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
        }
        if sample + 1 < count { Thread.sleep(forTimeInterval: Double(interval)) }
    }
    exit(hadError ? 1 : 0)
} else {
    do {
        let activation = AppInstance()
        guard let instance = try AppInstance.acquire() else {
            AppInstance.reopenExisting()
            exit(0)
        }
        withExtendedLifetime((instance, activation)) {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            activation.onReopen = { [weak delegate] in delegate?.requestReopen() }
            withExtendedLifetime(delegate) { app.run() }
        }
    } catch {
        fputs("PulseBar could not acquire its instance lock: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}
