import Foundation
import HardwareReaders
import HelperIPC
import SpeedCore

private final class SamplingSession: NSObject, PulseBarHelperProtocol {
    private let queue = DispatchQueue(label: "PulseBarHelper.sampling", qos: .utility)
    private let processes = ProcessReader()
    private let temperatureReader = TemperatureReader()
    private var accumulator = ProcessAccumulator()
    private var temperatures: [TemperatureReading] = []
    private var temperatureTimestamp: TimeInterval = 0
    private var lastPayload: Data?
    private var lastSample: TimeInterval = 0

    func sample(refreshSeconds: Int, withReply reply: @escaping (Data?, String?) -> Void) {
        guard RefreshInterval.range.contains(refreshSeconds) else { reply(nil, "Invalid refresh interval"); return }
        queue.async { [self] in
            let now = ProcessInfo.processInfo.systemUptime
            // A client cannot make the helper scan processes more than once/sec.
            if now - lastSample < 1, let lastPayload { reply(lastPayload, nil); return }
            var apps: [AppUsage] = []
            var count = 0, skipped = 0
            var processError: String?
            accumulator.setRefreshInterval(refreshSeconds)
            do {
                let snapshot = try processes.read()
                let all = accumulator.consume(snapshot)
                var seen: Set<String> = []
                apps = (AppRanking.cpu(all) + AppRanking.memory(all)).filter { seen.insert($0.id).inserted }
                count = snapshot.processes.count; skipped = snapshot.skippedCount
            } catch {
                accumulator.resetBaseline()
                processError = "Process sampling unavailable"
            }
            if temperatureTimestamp == 0 || now - temperatureTimestamp >= max(5, Double(refreshSeconds)) {
                temperatures = temperatureReader.read()
                temperatureTimestamp = now
            }
            let snapshot = HelperSnapshot(helperVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0",
                timestamp: now, apps: apps, processCount: count, skippedProcessCount: skipped,
                processError: processError, temperatures: temperatures, temperatureTimestamp: temperatureTimestamp)
            do {
                let payload = try JSONEncoder().encode(snapshot)
                lastPayload = payload; lastSample = now
                reply(payload, nil)
            } catch { reply(nil, "Could not encode sample") }
        }
    }
}

private final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    // Reconnecting clients share one sampler and cache. A timed-out request
    // must not leave a separate process scan running for every new connection.
    private let session = SamplingSession()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == getuid() else { return false }
        connection.setCodeSigningRequirement(HelperIdentity.clientRequirement)
        connection.exportedInterface = NSXPCInterface(with: PulseBarHelperProtocol.self)
        connection.exportedObject = session
        connection.resume()
        return true
    }
}

private let listener = NSXPCListener(machServiceName: HelperIdentity.serviceName)
private let delegate = ListenerDelegate()
listener.setConnectionCodeSigningRequirement(HelperIdentity.clientRequirement)
listener.delegate = delegate
listener.resume()
withExtendedLifetime((listener, delegate)) { RunLoop.main.run() }
