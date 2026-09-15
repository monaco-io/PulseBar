import Testing
@testable import SpeedCore

struct HistoryInspectionTests {
    private let points = [HistoryPoint(timestamp: 0, primary: 0, secondary: 100),
                          HistoryPoint(timestamp: 2, primary: 100, secondary: 0),
                          HistoryPoint(timestamp: 10, primary: 100, secondary: 0)]

    @Test func averagesAreTimeWeightedForUnevenSampling() {
        let summary = HistorySummary(points: points)
        #expect(summary.primaryAverage == 90)
        #expect(summary.secondaryAverage == 10)
        #expect(summary.primaryPeak == 100)
        #expect(summary.coveredSeconds == 10)
    }

    @Test func frozenWindowClipsBothEndsAndExcludesUncollectedTime() {
        let visible = HistoryInspection.window(points, seconds: 5, endingAt: 6)
        #expect(visible == [HistoryPoint(timestamp: 1, primary: 50, secondary: 50), points[1],
                            HistoryPoint(timestamp: 6, primary: 100)])
        #expect(HistorySummary(points: visible).primaryAverage == 95)
        let wider = HistoryInspection.window(points, seconds: 50, endingAt: 20)
        #expect(wider == points)
        #expect(HistorySummary(points: wider).coveredSeconds == 10)
        #expect(HistoryInspection.window(points, seconds: 2, endingAt: 20).isEmpty)
        #expect(HistoryInspection.window(points, seconds: 2, endingAt: -1).isEmpty)
    }

    @Test func inspectionUsesOriginalSamplesAndDoesNotInventPoints() {
        #expect(HistoryInspection.nearestSample(points, at: -1) == nil)
        #expect(HistoryInspection.nearestSample(points, at: 11) == nil)
        #expect(HistoryInspection.nearestSample(points, at: 8) == points[2])
        #expect(HistoryInspection.sample(points, at: 1) == nil)
        #expect(HistoryInspection.sample(points, at: 2) == points[1])
        #expect(HistoryInspection.sample([], at: 2) == nil)
    }

    @Test func emptyAndSinglePointDoNotClaimAnAverage() {
        #expect(HistorySummary(points: []).primaryAverage == nil)
        #expect(HistorySummary(points: [points[1]]).primaryAverage == nil)
        #expect(HistorySummary(points: [points[1]]).primaryPeak == 100)
    }
}
