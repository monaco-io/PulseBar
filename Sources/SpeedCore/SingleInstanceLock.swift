import Darwin
import Foundation

/// An advisory lock held for the lifetime of the GUI process. All installed
/// copies use the same per-user path; process exit (including a crash) releases it.
public final class SingleInstanceLock {
    private let descriptor: Int32

    private init(descriptor: Int32) { self.descriptor = descriptor }

    /// Returns nil only when another instance owns the lock. Filesystem failures
    /// are errors, so a failed check never silently allows another GUI to start.
    public static func acquire(at url: URL) throws -> SingleInstanceLock? {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let descriptor = url.path.withCString {
            Darwin.open($0, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        }
        guard descriptor >= 0 else { throw posixError(errno, url: url) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            Darwin.close(descriptor)
            if code == EWOULDBLOCK { return nil }
            throw posixError(code, url: url)
        }
        return SingleInstanceLock(descriptor: descriptor)
    }

    deinit {
        // Never unlink the lock file: a waiting launcher might already have it
        // open, and replacing its inode would allow two independent locks.
        Darwin.close(descriptor)
    }

    private static func posixError(_ code: Int32, url: URL) -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: [NSFilePathErrorKey: url.path])
    }
}
