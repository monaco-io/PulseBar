import Darwin
import Foundation
import Testing
@testable import SpeedCore

struct SingleInstanceLockTests {
    private func withLockURL(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appendingPathComponent("instance.lock"))
    }

    @Test func competingLaunchesCannotOwnTheSameLock() throws {
        try withLockURL { url in
            let first = try #require(try SingleInstanceLock.acquire(at: url))
            try withExtendedLifetime(first) { () throws -> Void in
                for _ in 0..<30 { #expect(try SingleInstanceLock.acquire(at: url) == nil) }
            }
        }
    }

    @Test func releaseAllowsRelaunchWithoutDeletingTheLockFile() throws {
        try withLockURL { url in
            var first = try SingleInstanceLock.acquire(at: url)
            #expect(first != nil)
            first = nil
            #expect(FileManager.default.fileExists(atPath: url.path))
            let second = try #require(try SingleInstanceLock.acquire(at: url))
            try withExtendedLifetime(second) { () throws -> Void in
                #expect(try SingleInstanceLock.acquire(at: url) == nil)
            }
        }
    }

    @Test func processCrashReleasesTheLock() throws {
        try withLockURL { url in
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let child = Process()
            child.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            child.arguments = ["-c", "import fcntl,sys,time; f=open(sys.argv[1],'a'); fcntl.flock(f,fcntl.LOCK_EX); print('ready',flush=True); time.sleep(30)", url.path]
            let pipe = Pipe()
            child.standardOutput = pipe
            try child.run()
            defer {
                if child.isRunning { kill(child.processIdentifier, SIGKILL) }
                child.waitUntilExit()
            }
            #expect(!pipe.fileHandleForReading.availableData.isEmpty)
            #expect(try SingleInstanceLock.acquire(at: url) == nil)
            kill(child.processIdentifier, SIGKILL)
            child.waitUntilExit()
            #expect(try SingleInstanceLock.acquire(at: url) != nil)
        }
    }

    @Test func filesystemErrorsDoNotMasqueradeAsAnExistingInstance() throws {
        try withLockURL { url in
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            #expect(throws: (any Error).self) { try SingleInstanceLock.acquire(at: url) }
        }
    }

    @Test func symlinkLockIsRejected() throws {
        try withLockURL { url in
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let target = url.deletingLastPathComponent().appendingPathComponent("target")
            try Data().write(to: target)
            try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target)
            #expect(throws: (any Error).self) { try SingleInstanceLock.acquire(at: url) }
        }
    }
}
