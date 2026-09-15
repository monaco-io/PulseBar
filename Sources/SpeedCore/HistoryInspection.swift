import Foundation

public struct HistorySummary: Equatable {
    public let primaryAverage: Double?
    public let secondaryAverage: Double?
    public let primaryPeak: Double?
    public let secondaryPeak: Double?
    public let coveredSeconds: TimeInterval

    public init(points: [HistoryPoint]) {
        var firstPeak: Double?, secondPeak: Double?
        for point in points {
            firstPeak = max(firstPeak ?? point.primary, point.primary)
            secondPeak = max(secondPeak ?? point.secondary, point.secondary)
        }
        primaryPeak = firstPeak
        secondaryPeak = secondPeak
        var primaryArea = 0.0, secondaryArea = 0.0, elapsed = 0.0
        for (first, second) in zip(points, points.dropFirst()) {
            let duration = second.timestamp - first.timestamp
            guard duration > 0 else { continue }
            primaryArea += (first.primary + second.primary) * 0.5 * duration
            secondaryArea += (first.secondary + second.secondary) * 0.5 * duration
            elapsed += duration
        }
        coveredSeconds = elapsed
        primaryAverage = elapsed > 0 ? primaryArea / elapsed : nil
        secondaryAverage = elapsed > 0 ? secondaryArea / elapsed : nil
    }
}

public enum HistoryInspection {
    /// Clip both ends against a shared chart clock. Interpolated boundary points
    /// are for drawing/statistics only; inspection uses the original samples.
    public static func window(_ points: [HistoryPoint], seconds: Int, endingAt end: TimeInterval) -> [HistoryPoint] {
        guard !points.isEmpty, end.isFinite else { return [] }
        let start = end - Double(HistoryWindow.normalized(seconds))
        let first = lowerBound(points, timestamp: start)
        let last = lowerBound(points, timestamp: end)
        var result: [HistoryPoint] = []
        if first > 0, first < points.count, points[first].timestamp > start {
            result.append(interpolate(points[first - 1], points[first], at: start))
        }
        if first < last { result += points[first..<last] }
        if last < points.count {
            if points[last].timestamp == end { result.append(points[last]) }
            else if last > 0, points[last - 1].timestamp < end {
                result.append(interpolate(points[last - 1], points[last], at: end))
            }
        }
        return result
    }

    public static func nearestSample(_ points: [HistoryPoint], at timestamp: TimeInterval) -> HistoryPoint? {
        guard let first = points.first, let last = points.last, timestamp.isFinite,
              timestamp >= first.timestamp, timestamp <= last.timestamp else { return nil }
        let index = lowerBound(points, timestamp: timestamp)
        guard index > 0 else { return first }
        guard index < points.count else { return last }
        return timestamp - points[index - 1].timestamp <= points[index].timestamp - timestamp ? points[index - 1] : points[index]
    }

    public static func sample(_ points: [HistoryPoint], at timestamp: TimeInterval) -> HistoryPoint? {
        let index = lowerBound(points, timestamp: timestamp - 0.0001)
        guard index < points.count, abs(points[index].timestamp - timestamp) < 0.001 else { return nil }
        return points[index]
    }

    private static func lowerBound(_ points: [HistoryPoint], timestamp: TimeInterval) -> Int {
        var lower = 0, upper = points.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if points[middle].timestamp < timestamp { lower = middle + 1 } else { upper = middle }
        }
        return lower
    }

    private static func interpolate(_ a: HistoryPoint, _ b: HistoryPoint, at time: TimeInterval) -> HistoryPoint {
        let fraction = (time - a.timestamp) / (b.timestamp - a.timestamp)
        return HistoryPoint(timestamp: time, primary: a.primary + (b.primary - a.primary) * fraction,
                            secondary: a.secondary + (b.secondary - a.secondary) * fraction)
    }
}
