import AppKit
import Combine
import SpeedCore
import SystemConfiguration

struct ResourceState {
    var cpu: CPUUsage?
    var memory: MemoryUsage?
    var diskRate: DiskRate?
    var cpuHistory: [HistoryPoint] = []
    var memoryHistory: [HistoryPoint] = []
    var diskHistory: [HistoryPoint] = []
    var disks: [String] = []
    var totalDiskRead: UInt64 = 0
    var totalDiskWritten: UInt64 = 0
    var cpuError: Error?
    var memoryError: Error?
    var diskError: Error?
    var hasError: Bool { cpuError != nil || memoryError != nil || diskError != nil }
}

final class SystemMonitor: ObservableObject {
    @Published private(set) var rate = TrafficRate.zero
    @Published private(set) var history: [HistoryPoint] = []
    @Published private(set) var resources = ResourceState()
    @Published private(set) var totalReceived: UInt64 = 0
    @Published private(set) var totalSent: UInt64 = 0
    @Published private(set) var interfaces: [String] = []
    @Published private(set) var networkError: Error?
    @Published private(set) var sessionStart = Date()

    private let reader = InterfaceReader()
    private let systemReader = SystemReader()
    private var accumulator = TrafficAccumulator()
    private var cpuAccumulator = CPUAccumulator()
    private var diskAccumulator = DiskAccumulator()
    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var interfaceLabels: [String: String] = [:]
    private var labelRefresh = 0
    private(set) var refreshSeconds = 1
    private var maximumHistoryGap: TimeInterval { max(5, Double(refreshSeconds) * 1.5) }

    func interfaceDescription(using localizer: Localizer) -> String {
        interfaces.map { name in
            guard let label = interfaceLabels[name] else { return name }
            return "\(label) (\(name))"
        }.joined(separator: localizer(.listSeparator))
    }

    func start(refreshSeconds: Int = 1) {
        guard timer == nil else { return }
        self.refreshSeconds = RefreshInterval.normalized(refreshSeconds)
        configureSamplingWindows()
        sample()
        scheduleTimer()

        let center = NSWorkspace.shared.notificationCenter
        for event in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification] {
            workspaceObservers.append(center.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in
                self?.accumulator.resetBaseline()
                self?.rate = .zero
                self?.history.removeAll()
                self?.resetResourceBaselines()
            })
        }
    }

    func setRefreshInterval(_ seconds: Int) {
        let value = RefreshInterval.normalized(seconds)
        guard value != refreshSeconds else { return }
        refreshSeconds = value
        configureSamplingWindows()
        if timer != nil {
            timer?.invalidate()
            scheduleTimer()
        }
    }

    private func configureSamplingWindows() {
        accumulator.setRefreshInterval(refreshSeconds)
        cpuAccumulator.setRefreshInterval(refreshSeconds)
        diskAccumulator.setRefreshInterval(refreshSeconds)
    }

    private func scheduleTimer() {
        let timer = Timer(timeInterval: Double(refreshSeconds), repeats: true) { [weak self] _ in self?.sample() }
        timer.tolerance = min(1, Double(refreshSeconds) * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        workspaceObservers.removeAll()
    }

    func reset() {
        accumulator.reset()
        totalReceived = 0
        totalSent = 0
        history.removeAll()
        rate = .zero
        cpuAccumulator.resetBaseline()
        diskAccumulator.reset()
        resources = ResourceState()
        sessionStart = Date()
        sample()
    }

    private func sample() {
        sampleNetwork()
        sampleResources()
    }

    private func sampleNetwork() {
        do {
            let snapshot = try reader.read()
            let names = snapshot.interfaces.map(\.name)
            if names != interfaces || labelRefresh % 30 == 0 { refreshInterfaceLabels() }
            labelRefresh += 1
            interfaces = names
            networkError = nil
            rate = accumulator.consume(snapshot)
            totalReceived = accumulator.totalReceived
            totalSent = accumulator.totalSent
            if let last = history.last, snapshot.timestamp - last.timestamp > maximumHistoryGap { history.removeAll() }
            history.append(HistoryPoint(timestamp: snapshot.timestamp, primary: rate.download, secondary: rate.upload))
            trimHistory(&history, at: snapshot.timestamp)
        } catch {
            networkError = error
            rate = .zero
            history.removeAll()
            accumulator.resetBaseline()
        }
    }

    private func resetResourceBaselines() {
        cpuAccumulator.resetBaseline()
        diskAccumulator.resetBaseline()
        var next = resources
        next.cpu = nil
        next.memory = nil
        next.diskRate = nil
        next.cpuHistory.removeAll()
        next.memoryHistory.removeAll()
        next.diskHistory.removeAll()
        resources = next
    }

    private func sampleResources() {
        // Publish one coherent update after independent reads: one failure must
        // not hide the other metrics or leave a stale value looking current.
        var next = resources
        do {
            let snapshot = try systemReader.readCPU()
            next.cpu = cpuAccumulator.consume(snapshot)
            next.cpuError = nil
            if let usage = next.cpu {
                next.cpuHistory.append(HistoryPoint(timestamp: snapshot.timestamp, primary: usage.usedPercent))
                trimHistory(&next.cpuHistory, at: snapshot.timestamp)
            } else { next.cpuHistory.removeAll() }
        } catch {
            next.cpu = nil
            next.cpuError = error
            next.cpuHistory.removeAll()
            cpuAccumulator.resetBaseline()
        }
        do {
            let memory = try systemReader.readMemory()
            next.memory = memory
            next.memoryError = nil
            if let last = next.memoryHistory.last, memory.timestamp - last.timestamp > maximumHistoryGap { next.memoryHistory.removeAll() }
            next.memoryHistory.append(HistoryPoint(timestamp: memory.timestamp, primary: memory.usedPercent))
            trimHistory(&next.memoryHistory, at: memory.timestamp)
        } catch {
            next.memory = nil
            next.memoryError = error
            next.memoryHistory.removeAll()
        }
        do {
            let snapshot = try systemReader.readDisks()
            next.diskRate = diskAccumulator.consume(snapshot)
            next.diskError = nil
            next.disks = snapshot.disks.map(\.name)
            next.totalDiskRead = diskAccumulator.totalRead
            next.totalDiskWritten = diskAccumulator.totalWritten
            if let rate = next.diskRate {
                next.diskHistory.append(HistoryPoint(timestamp: snapshot.timestamp, primary: rate.read, secondary: rate.write))
                trimHistory(&next.diskHistory, at: snapshot.timestamp)
            } else { next.diskHistory.removeAll() }
        } catch {
            next.diskRate = nil
            next.diskError = error
            next.disks.removeAll()
            next.diskHistory.removeAll()
            diskAccumulator.resetBaseline()
        }
        resources = next
    }

    private func refreshInterfaceLabels() {
        guard let list = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return }
        interfaceLabels = [:]
        for interface in list {
            guard let name = SCNetworkInterfaceGetBSDName(interface) as String?,
                  let label = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? else { continue }
            interfaceLabels[name] = label
        }
    }

    private func trimHistory(_ points: inout [HistoryPoint], at timestamp: TimeInterval) {
        HistoryWindow.trim(&points, at: timestamp)
    }
}
