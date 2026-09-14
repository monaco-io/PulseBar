import Foundation

public struct HistoryPoint: Identifiable, Equatable {
    public let timestamp: TimeInterval
    public let primary: Double
    public var secondary: Double
    public var id: TimeInterval { timestamp }

    public init(timestamp: TimeInterval, primary: Double, secondary: Double = 0) {
        self.timestamp = timestamp
        self.primary = primary
        self.secondary = secondary
    }
}

public enum HistoryWindow {
    public static let range = 1...86400
    public static let defaultSeconds = 3600
    public static func normalized(_ seconds: Int) -> Int { min(range.upperBound, max(range.lowerBound, seconds)) }
    public static let hourRange = (1.0 / 3600)...24.0

    public static func seconds(hours: Double) -> Int? {
        guard hours.isFinite, hours > 0 else { return nil }
        return Int((min(hourRange.upperBound, max(hourRange.lowerBound, hours)) * 3600).rounded())
    }

    public static func hoursText(seconds: Int) -> String {
        var text = String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), Double(normalized(seconds)) / 3600)
        while text.last == "0" { text.removeLast() }
        if text.last == "." { text.removeLast() }
        return text
    }

    /// Keep at most 24 hours, plus one point before its boundary. Changing the
    /// visible window can then reuse samples already collected in this session.
    public static func trim(_ points: inout [HistoryPoint], at timestamp: TimeInterval) {
        let boundary = timestamp - Double(range.upperBound)
        var removeCount = 0
        while removeCount + 1 < points.count && points[removeCount + 1].timestamp < boundary { removeCount += 1 }
        if removeCount > 0 { points.removeFirst(removeCount) }
    }

    public static func visiblePoints(_ points: [HistoryPoint], seconds: Int) -> [HistoryPoint] {
        guard points.count > 1, let last = points.last else { return points }
        let boundary = last.timestamp - Double(normalized(seconds))
        var lower = 0
        var upper = points.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if points[middle].timestamp < boundary { lower = middle + 1 }
            else { upper = middle }
        }
        guard lower > 0 else { return points }
        var visible = Array(points[(lower - 1)...])
        let before = visible[0]
        let after = visible[1]
        if after.timestamp == boundary { visible.removeFirst() }
        else {
            let fraction = (boundary - before.timestamp) / (after.timestamp - before.timestamp)
            visible[0] = HistoryPoint(timestamp: boundary,
                                      primary: before.primary + (after.primary - before.primary) * fraction,
                                      secondary: before.secondary + (after.secondary - before.secondary) * fraction)
        }
        return visible
    }

    /// Keep both series' peaks while limiting the number of drawn vertices.
    /// The original samples remain available when the user changes the window.
    public static func plotPoints(_ points: [HistoryPoint], maximumCount: Int) -> [HistoryPoint] {
        guard maximumCount >= 6, points.count > maximumCount else { return points }
        let buckets = (maximumCount - 2) / 4
        let interiorCount = points.count - 2
        var result = [points[0]]
        for bucket in 0..<buckets {
            let start = 1 + bucket * interiorCount / buckets
            let end = 1 + (bucket + 1) * interiorCount / buckets
            var minPrimary = start, maxPrimary = start, minSecondary = start, maxSecondary = start
            for index in start..<end {
                if points[index].primary < points[minPrimary].primary { minPrimary = index }
                if points[index].primary > points[maxPrimary].primary { maxPrimary = index }
                if points[index].secondary < points[minSecondary].secondary { minSecondary = index }
                if points[index].secondary > points[maxSecondary].secondary { maxSecondary = index }
            }
            for index in Set([minPrimary, maxPrimary, minSecondary, maxSecondary]).sorted() { result.append(points[index]) }
        }
        result.append(points[points.count - 1])
        return result
    }
}
