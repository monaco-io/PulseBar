import Foundation

/// Call from a background queue. A bounded wait prevents a missing, hung, or
/// rejected companion from blocking monitoring or retaining stale readings.
public final class HelperClient {
    private let lock = NSLock()
    private var connection: NSXPCConnection?
    public init() {}
    deinit { connection?.invalidate() }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        connection?.invalidate()
        connection = nil
    }

    public func read(refreshSeconds: Int) throws -> HelperSnapshot {
        lock.lock()
        defer { lock.unlock() }
        let connection: NSXPCConnection
        if let existing = self.connection { connection = existing }
        else {
            connection = NSXPCConnection(machServiceName: HelperIdentity.serviceName)
            connection.remoteObjectInterface = NSXPCInterface(with: PulseBarHelperProtocol.self)
            connection.setCodeSigningRequirement(HelperIdentity.serviceRequirement)
            connection.resume()
            self.connection = connection
        }
        let reply = PendingReply()
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
            reply.finish(.failure(HelperError.unavailable))
        }) as? PulseBarHelperProtocol else { throw HelperError.unavailable }
        proxy.sample(refreshSeconds: refreshSeconds) { data, _ in
            guard let data else { reply.finish(.failure(HelperError.unavailable)); return }
            reply.finish(.success(data))
        }
        do {
            let data = try reply.wait()
            return try HelperSnapshot.decode(data, now: ProcessInfo.processInfo.systemUptime,
                                             refreshSeconds: refreshSeconds)
        } catch {
            connection.invalidate()
            self.connection = nil
            throw error
        }
    }
}

private final class PendingReply: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: Result<Data, Error>?

    func finish(_ value: Result<Data, Error>) {
        lock.lock()
        guard result == nil else { lock.unlock(); return }
        result = value
        lock.unlock()
        semaphore.signal()
    }

    func wait() throws -> Data {
        guard semaphore.wait(timeout: .now() + 3) == .success else { throw HelperError.timeout }
        lock.lock()
        defer { lock.unlock() }
        return try result!.get()
    }
}
