import Testing
@testable import SpeedCore

struct HistoryWindowTests {
    private let points = [
        HistoryPoint(timestamp: 0, primary: 0, secondary: 100),
        HistoryPoint(timestamp: 50, primary: 100, secondary: 50),
        HistoryPoint(timestamp: 100, primary: 200, secondary: 0)
    ]

    @Test func usesElapsedTimeAndInterpolatesBothSeriesAtTheWindowBoundary() {
        let visible = HistoryWindow.visiblePoints(points, seconds: 60)
        #expect(visible == [HistoryPoint(timestamp: 40, primary: 80, secondary: 60), points[1], points[2]])
        #expect(HistoryWindow.visiblePoints(points, seconds: 50) == [points[1], points[2]])
        #expect(HistoryWindow.visiblePoints(points, seconds: 10) == [
            HistoryPoint(timestamp: 90, primary: 180, secondary: 10), points[2]
        ])
    }

    @Test func expandingTheWindowReusesCollectedDataWithoutInventingSamples() {
        _ = HistoryWindow.visiblePoints(points, seconds: 10)
        #expect(HistoryWindow.visiblePoints(points, seconds: 300) == points)
        #expect(HistoryWindow.visiblePoints([], seconds: 300).isEmpty)
        #expect(HistoryWindow.visiblePoints([points[0]], seconds: 300) == [points[0]])
        #expect(HistoryWindow.visiblePoints(points, seconds: 0).first?.timestamp == 99)
    }

    @Test func retentionIsBoundedAndPreservesTheOldestVisibleSegment() {
        var history = (0...90000).map { HistoryPoint(timestamp: Double($0), primary: Double($0)) }
        HistoryWindow.trim(&history, at: 90000)
        #expect(history.count == 86402)
        #expect(history.first?.timestamp == 3599)
        #expect(history.last?.timestamp == 90000)
        #expect(HistoryWindow.visiblePoints(history, seconds: 100000).first?.timestamp == 3600)
        #expect(HistoryWindow.visiblePoints(history, seconds: 300).first?.timestamp == 89700)
        #expect(HistoryWindow.visiblePoints(history, seconds: 60).first?.timestamp == 89940)
    }

    @Test func hourInputsPreserveExistingDurationsAndRejectInvalidNumbers() throws {
        #expect(HistoryWindow.seconds(hours: 0.5) == 1800)
        #expect(HistoryWindow.seconds(hours: 2) == 7200)
        #expect(HistoryWindow.seconds(hours: 1000) == 86400)
        for invalid in [0, -1, Double.nan, .infinity] { #expect(HistoryWindow.seconds(hours: invalid) == nil) }
        for seconds in [1, 60, 300, 1800, 3600, 86400] {
            let hours = try #require(Double(HistoryWindow.hoursText(seconds: seconds)))
            #expect(HistoryWindow.seconds(hours: hours) == seconds)
        }
        #expect(HistoryWindow.hoursText(seconds: 1800) == "0.5")
        #expect(HistoryWindow.hoursText(seconds: 3600) == "1")
    }

    @Test func longChartsKeepBothDirectionalPeaksWithBoundedDrawingWork() {
        let samples = (0..<10000).map { index in
            HistoryPoint(timestamp: Double(index), primary: index == 3456 ? 1000 : 0,
                         secondary: index == 7890 ? 2000 : 0)
        }
        let plotted = HistoryWindow.plotPoints(samples, maximumCount: 720)
        #expect(plotted.count <= 720)
        #expect(plotted.first == samples.first)
        #expect(plotted.last == samples.last)
        #expect(plotted.contains(samples[3456]))
        #expect(plotted.contains(samples[7890]))
        #expect(plotted.map(\.timestamp) == plotted.map(\.timestamp).sorted())
        #expect(Set(plotted.map(\.timestamp)).count == plotted.count)
    }
}
