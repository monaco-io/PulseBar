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
    var pressure: MemoryPressure?
    var swap: SwapUsage?
    var swapHistory: [HistoryPoint] = []
    var pressureError: Error?
    var swapError: Error?
    var hasError: Bool { cpuError != nil || memoryError != nil || diskError != nil || pressureError != nil || swapError != nil }
}

private final class ProcessSampler {
    private let reader = ProcessReader()
    private var accumulator = ProcessAccumulator()
    func read(interval: Int) throws -> (ProcessSnapshot, [AppUsage]) {
        accumulator.setRefreshInterval(interval)
        do {
            let snapshot = try reader.read()
            return (snapshot, accumulator.consume(snapshot))
        } catch { accumulator.resetBaseline(); throw error }
    }
    func reset() { accumulator.resetBaseline() }
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
    @Published private(set) var timelineEnd = ProcessInfo.processInfo.systemUptime
    @Published private(set) var apps: [AppUsage] = []
    @Published private(set) var processError: Error?
    @Published private(set) var processCount = 0
    @Published private(set) var skippedProcessCount = 0
    @Published private(set) var rankingDate: Date?
    @Published private(set) var events: [PerformanceEvent] = []
    @Published private(set) var eventStoreError: Error?
    var onEvent: ((PerformanceEvent) -> Void)?
    private var eventDetector = PerformanceEventDetector()
    private let eventStore: PerformanceEventStore
    private let eventQueue = DispatchQueue(label: "PulseBar.event-storage", qos: .utility)
    private let processQueue = DispatchQueue(label: "PulseBar.process-sampling", qos: .utility)
    private let processSampler = ProcessSampler()
    private var processSampling = false
    private var processGeneration = 0

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

    init(eventStore: PerformanceEventStore = PerformanceEventStore()) {
        self.eventStore = eventStore
        do { events = try eventStore.load() } catch { eventStoreError = error }
    }

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
                self?.resetProcessBaselines()
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
        resetProcessBaselines()
        eventQueue.sync {} // Complete any atomic event write before the app exits.
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
        resetProcessBaselines()
        sessionStart = Date()
        sample()
    }

    private func sample() {
        let timestamp = ProcessInfo.processInfo.systemUptime
        sampleNetwork(at: timestamp)
        sampleResources(at: timestamp)
        timelineEnd = timestamp
        sampleProcesses(at: timestamp)
    }

    private func sampleNetwork(at timestamp: TimeInterval) {
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
            if let last = history.last, timestamp - last.timestamp > maximumHistoryGap { history.removeAll() }
            history.append(HistoryPoint(timestamp: timestamp, primary: rate.download, secondary: rate.upload))
            trimHistory(&history, at: timestamp)
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
        next.pressure = nil
        next.swap = nil
        next.swapHistory.removeAll()
        next.cpuHistory.removeAll()
        next.memoryHistory.removeAll()
        next.diskHistory.removeAll()
        resources = next
    }

    private func sampleResources(at timestamp: TimeInterval) {
        // Publish one coherent update after independent reads: one failure must
        // not hide the other metrics or leave a stale value looking current.
        var next = resources
        do {
            let snapshot = try systemReader.readCPU()
            next.cpu = cpuAccumulator.consume(snapshot)
            next.cpuError = nil
            if let usage = next.cpu {
                next.cpuHistory.append(HistoryPoint(timestamp: timestamp, primary: usage.usedPercent))
                trimHistory(&next.cpuHistory, at: timestamp)
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
            if let last = next.memoryHistory.last, timestamp - last.timestamp > maximumHistoryGap { next.memoryHistory.removeAll() }
            next.memoryHistory.append(HistoryPoint(timestamp: timestamp, primary: memory.usedPercent))
            trimHistory(&next.memoryHistory, at: timestamp)
        } catch {
            next.memory = nil
            next.memoryError = error
            next.memoryHistory.removeAll()
        }
        do { next.pressure = try systemReader.readMemoryPressure(); next.pressureError = nil }
        catch { next.pressure = nil; next.pressureError = error }
        do {
            let swap = try systemReader.readSwap()
            next.swap = swap; next.swapError = nil
            if let last = next.swapHistory.last, timestamp - last.timestamp > maximumHistoryGap { next.swapHistory.removeAll() }
            next.swapHistory.append(HistoryPoint(timestamp: timestamp, primary: Double(swap.usedBytes)))
            trimHistory(&next.swapHistory, at: timestamp)
        } catch { next.swap = nil; next.swapError = error; next.swapHistory.removeAll() }
        do {
            let snapshot = try systemReader.readDisks()
            next.diskRate = diskAccumulator.consume(snapshot)
            next.diskError = nil
            next.disks = snapshot.disks.map(\.name)
            next.totalDiskRead = diskAccumulator.totalRead
            next.totalDiskWritten = diskAccumulator.totalWritten
            if let rate = next.diskRate {
                next.diskHistory.append(HistoryPoint(timestamp: timestamp, primary: rate.read, secondary: rate.write))
                trimHistory(&next.diskHistory, at: timestamp)
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

    private func resetProcessBaselines() {
        processGeneration += 1
        eventDetector.resetContinuity()
        apps = []; rankingDate = nil; processError = nil
        processQueue.async { [processSampler] in processSampler.reset() }
    }

    private func sampleProcesses(at timestamp: TimeInterval) {
        guard !processSampling else { return }
        processSampling = true
        let generation = processGeneration
        let interval = refreshSeconds
        let cpu = resources.cpu?.usedPercent
        let pressure = resources.pressure
        let swap = resources.swap?.usedBytes
        let date = Date()
        let gap = maximumHistoryGap
        processQueue.async { [weak self, processSampler] in
            let result = Result { try processSampler.read(interval: interval) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.processSampling = false
                guard generation == self.processGeneration else { return }
                switch result {
                case let .success((snapshot, apps)):
                    self.apps = apps; self.processError = nil
                    self.processCount = snapshot.processes.count; self.skippedProcessCount = snapshot.skippedCount
                    self.rankingDate = date
                case let .failure(error):
                    self.apps = []; self.processError = error; self.rankingDate = nil
                }
                let newEvents = self.eventDetector.consume(timestamp: timestamp, date: date, cpu: cpu, pressure: pressure,
                    swapBytes: swap, apps: self.apps, maximumGap: gap, rankingAvailable: self.processError == nil)
                let retained = PerformanceEventStore.retained(newEvents + self.events, now: date)
                if retained != self.events {
                    self.events = retained
                    self.saveEvents()
                }
                for event in newEvents { self.onEvent?(event) }
            }
        }
    }

    func clearEvents() {
        events = []
        saveEvents()
    }

    private func saveEvents() {
        let snapshot = events
        eventQueue.async { [weak self, eventStore] in
            let result = Result { try eventStore.save(snapshot) }
            DispatchQueue.main.async {
                if case let .failure(error) = result { self?.eventStoreError = error }
                else { self?.eventStoreError = nil }
            }
        }
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
