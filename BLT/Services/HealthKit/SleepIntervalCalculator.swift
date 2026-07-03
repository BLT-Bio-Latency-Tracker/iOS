import Foundation

enum SleepIntervalCalculator {
    static func minutesAfterMerging(_ intervals: [DateInterval]) -> Int {
        let totalSeconds = mergedIntervals(intervals).reduce(0) { result, interval in
            result + interval.duration
        }

        return Int((totalSeconds / 60).rounded())
    }

    static func mergedIntervals(_ intervals: [DateInterval]) -> [DateInterval] {
        let sortedIntervals = intervals
            .filter { $0.duration > 0 }
            .sorted { $0.start < $1.start }

        guard var current = sortedIntervals.first else { return [] }

        var merged: [DateInterval] = []

        for interval in sortedIntervals.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(
                    start: current.start,
                    end: max(current.end, interval.end)
                )
            } else {
                merged.append(current)
                current = interval
            }
        }

        merged.append(current)
        return merged
    }
}
