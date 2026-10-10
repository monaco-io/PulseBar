import Darwin
import Testing
@testable import SpeedCore

struct ProcessMetricsTests {
    @Test func convertsAppleSiliconAndIntelCPUClocksWithoutOverflow() {
        #expect(ProcessClock.nanoseconds(9_600_000, numerator: 125, denominator: 3) == 400_000_000)
        #expect(ProcessClock.nanoseconds(400_000_000, numerator: 1, denominator: 1) == 400_000_000)
        #expect(ProcessClock.nanoseconds(.max, numerator: 125, denominator: 3) == .max)
    }

    @Test func liveReaderAgreesWithTheProcessCPUClock() throws {
        let reader = ProcessReader()
        let first = try #require(reader.read().processes.first { $0.pid == getpid() })
        func processTime() -> Double {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
                + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        }
        let start = processTime()
        while processTime() - start < 0.15 {}
        let last = try #require(reader.read().processes.first { $0.pid == getpid() })
        let consumed = Double(last.cpuNanoseconds - first.cpuNanoseconds) / 1_000_000_000
        #expect(consumed >= 0.12 && consumed < 2)
    }
    private func process(_ pid: Int32, parent: Int32 = 1, start: UInt64 = 10, path: String,
                         cpu: UInt64 = 0, memory: UInt64 = 100, owner: String? = nil) -> ProcessSample {
        ProcessSample(pid: pid, parentPID: parent, startedAt: start, name: "process-\(pid)",
                      executablePath: path, cpuNanoseconds: cpu, memoryBytes: memory,
                      responsibleBundlePath: owner)
    }

    @Test func groupsNestedHelpersAndChildToolsWithoutMergingSeparateApps() throws {
        let samples = [process(1, path: "/Applications/Editor.app/Contents/MacOS/Editor"),
                       process(2, path: "/Applications/Editor.app/Contents/Frameworks/Helper.app/Contents/MacOS/Helper"),
                       process(3, parent: 2, path: "/usr/bin/clang"),
                       process(4, path: "/Other/Editor.app/Contents/MacOS/Editor")]
        var accumulator = ProcessAccumulator(coreCount: 4)
        let apps = accumulator.consume(ProcessSnapshot(timestamp: 1, processes: samples))
        #expect(apps.count == 2)
        let editor = try #require(apps.first { $0.id == "/Applications/Editor.app" })
        #expect(editor.processCount == 3)
        #expect(editor.memoryBytes == 300)
        #expect(editor.cpuPercent == nil)
    }

    @Test func usesIntervalDeltasAndWholeMacCPUScale() throws {
        var accumulator = ProcessAccumulator(coreCount: 4)
        _ = accumulator.consume(ProcessSnapshot(timestamp: 10, processes: [process(5, path: "/bin/tool", cpu: 2_000_000_000)]))
        let apps = accumulator.consume(ProcessSnapshot(timestamp: 12, processes: [process(5, path: "/bin/tool", cpu: 4_000_000_000)]))
        #expect(try #require(apps.first?.cpuPercent) == 25)
    }

    @Test func groupsSharedWebKitServicesByResponsibleAppAndSumsTheirCounters() throws {
        let webKit = "/System/Library/Frameworks/WebKit.framework/XPCServices/com.apple.WebKit.WebContent.xpc/Contents/MacOS/com.apple.WebKit.WebContent"
        let safari = "/Applications/Safari.app"
        let dingTalk = "/Applications/DingTalk.app"
        func snapshot(_ timestamp: Double, cpu: UInt64) -> ProcessSnapshot {
            ProcessSnapshot(timestamp: timestamp, processes: [
                process(10, path: safari + "/Contents/MacOS/Safari", cpu: cpu, memory: 200),
                process(11, path: dingTalk + "/Contents/MacOS/DingTalk", cpu: cpu, memory: 300),
                process(20, path: webKit, cpu: cpu, memory: 400, owner: safari),
                process(21, path: webKit, cpu: cpu, memory: 500, owner: safari),
                process(22, path: webKit, cpu: cpu, memory: 600, owner: dingTalk)
            ])
        }
        var accumulator = ProcessAccumulator(coreCount: 4)
        _ = accumulator.consume(snapshot(10, cpu: 0))
        let apps = accumulator.consume(snapshot(12, cpu: 1_000_000_000))
        #expect(apps.count == 2)
        let browser = try #require(apps.first { $0.id == safari })
        #expect(browser.bundlePath == safari)
        #expect(browser.name == "Safari")
        #expect(browser.processCount == 3)
        #expect(browser.memoryBytes == 1_100)
        #expect(browser.cpuPercent == 37.5)
        let chat = try #require(apps.first { $0.id == dingTalk })
        #expect(chat.processCount == 2)
        #expect(chat.memoryBytes == 900)
        #expect(chat.cpuPercent == 25)
    }

    @Test func attributesServicesWhenOwnerCountersAreMissingAndPreservesStandaloneApps() throws {
        let owner = "/Applications/Host.app"
        let standalone = "/Applications/Other.app"
        var accumulator = ProcessAccumulator()
        let apps = accumulator.consume(ProcessSnapshot(timestamp: 1, processes: [
            process(10, path: "/System/Library/Example.xpc/Contents/MacOS/Example", owner: owner),
            process(11, parent: 10, path: "/usr/bin/tool"),
            process(12, path: standalone + "/Contents/MacOS/Other", owner: owner),
            process(13, path: "/usr/libexec/unknown-service")
        ]))
        #expect(apps.count == 3)
        let host = try #require(apps.first { $0.id == owner })
        #expect(host.processCount == 2)
        #expect(host.memoryBytes == 200)
        #expect(apps.first { $0.id == standalone }?.processCount == 1)
        let unknown = try #require(apps.first { $0.id == "/usr/libexec/unknown-service" })
        #expect(unknown.bundlePath == nil)
        #expect(unknown.processCount == 1)
    }

    @Test func responsibilityChangesAndPIDReuseDoNotCarryOldAppTotalsForward() throws {
        let path = "/System/Library/Example.xpc/Contents/MacOS/Example"
        var accumulator = ProcessAccumulator(coreCount: 1)
        _ = accumulator.consume(ProcessSnapshot(timestamp: 1, processes: [
            process(10, path: path, owner: "/Applications/First.app")
        ]))
        let changed = accumulator.consume(ProcessSnapshot(timestamp: 2, processes: [
            process(10, path: path, cpu: 100_000_000, owner: "/Applications/Second.app")
        ]))
        #expect(changed.count == 1)
        #expect(changed.first?.id == "/Applications/Second.app")
        #expect(changed.first?.cpuPercent == 10)
        let reused = accumulator.consume(ProcessSnapshot(timestamp: 3, processes: [
            process(10, start: 11, path: path, cpu: 1_000_000_000)
        ]))
        #expect(reused.count == 1)
        #expect(reused.first?.id == path)
        #expect(reused.first?.bundlePath == nil)
        #expect(reused.first?.cpuPercent == nil)
    }

    @Test func pidReuseGapsAndCounterResetsNeverCreateSpikes() {
        var accumulator = ProcessAccumulator(coreCount: 1)
        _ = accumulator.consume(ProcessSnapshot(timestamp: 1, processes: [process(5, path: "/bin/tool", cpu: 5_000)]))
        let reused = accumulator.consume(ProcessSnapshot(timestamp: 2, processes: [process(5, start: 11, path: "/bin/tool", cpu: 8_000_000_000)]))
        #expect(reused.first?.cpuPercent == nil)
        let reset = accumulator.consume(ProcessSnapshot(timestamp: 3, processes: [process(5, start: 11, path: "/bin/tool", cpu: 2)]))
        #expect(reset.first?.cpuPercent == nil)
        let gap = accumulator.consume(ProcessSnapshot(timestamp: 100, processes: [process(5, start: 11, path: "/bin/tool", cpu: 9_000_000_000)]))
        #expect(gap.first?.cpuPercent == nil)
        #expect(gap.first?.memoryBytes == 100)
    }

    @Test func rankingSortsBeforeTakingFiveAndSkipsUnmeasuredCPU() {
        let apps: [AppUsage] = (0..<9).map { (index: Int) -> AppUsage in
            let cpu: Double? = index == 8 ? nil : Double(index)
            return AppUsage(id: String(index), name: "App \(index)", cpuPercent: cpu, memoryBytes: UInt64(index * 10))
        }
        #expect(AppRanking.cpu(apps).map(\.id) == ["7", "6", "5", "4", "3"])
        #expect(AppRanking.memory(apps).map(\.id) == ["8", "7", "6", "5", "4"])
    }

    @Test func cyclicParentRecordsDoNotHangAndExitedProcessesDisappear() {
        var accumulator = ProcessAccumulator()
        let apps = accumulator.consume(ProcessSnapshot(timestamp: 1, processes: [
            process(4, parent: 5, path: "/bin/a"), process(5, parent: 4, path: "/bin/b")
        ]))
        #expect(apps.count == 2)
        #expect(accumulator.consume(ProcessSnapshot(timestamp: 2, processes: [])).isEmpty)
    }
}
