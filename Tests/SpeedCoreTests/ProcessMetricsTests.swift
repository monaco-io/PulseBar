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
                         cpu: UInt64 = 0, memory: UInt64 = 100) -> ProcessSample {
        ProcessSample(pid: pid, parentPID: parent, startedAt: start, name: "process-\(pid)",
                      executablePath: path, cpuNanoseconds: cpu, memoryBytes: memory)
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
