import Foundation

/// History/trend computations over the last N days. Pure functions so views
/// and previews can use them directly. Mirrors the web app's history logic.
enum Analytics {
    struct DayAverage: Identifiable {
        let id = UUID()
        let dayStartMs: Double
        let average: Double?    // nil when nothing was logged that day
    }

    enum Trend { case up, down, steady, none }

    static func dailyAverages(_ logs: [MoodLog], days: Int) -> [DayAverage] {
        let todayStart = Clock.startOfTodayMs()
        return (0..<days).reversed().map { offset -> DayAverage in
            let dayStart = todayStart - Double(offset) * 86_400_000
            let dayEnd = dayStart + 86_400_000
            let vals = logs.filter { $0.ts >= dayStart && $0.ts < dayEnd }.map(\.value)
            let avg = vals.isEmpty ? nil : Double(vals.reduce(0, +)) / Double(vals.count)
            return DayAverage(dayStartMs: dayStart, average: avg)
        }
    }

    /// Compares the first vs. second half of the populated days.
    static func trend(_ logs: [MoodLog], days: Int = 7) -> Trend {
        let populated = dailyAverages(logs, days: days).compactMap(\.average)
        guard populated.count >= 2 else { return .none }
        let mid = populated.count / 2
        let firstHalf = populated.prefix(mid)
        let secondHalf = populated.suffix(populated.count - mid)
        let a = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let b = secondHalf.reduce(0, +) / Double(secondHalf.count)
        let delta = b - a
        if delta > 0.6 { return .up }
        if delta < -0.6 { return .down }
        return .steady
    }

    struct WeeklySummary {
        let count: Int
        let peak: MoodLog?
        let dip: MoodLog?
        let mostCommonLabel: String?
    }

    static func weeklySummary(_ logs: [MoodLog], days: Int = 7) -> WeeklySummary {
        let cutoff = Clock.startOfTodayMs() - Double(days - 1) * 86_400_000
        let recent = logs.filter { $0.ts >= cutoff }
        let peak = recent.max { $0.value < $1.value }
        let dip = recent.min { $0.value < $1.value }
        let counts = Dictionary(grouping: recent, by: { $0.label }).mapValues(\.count)
        let common = counts.max { $0.value < $1.value }?.key
        return WeeklySummary(count: recent.count, peak: peak, dip: dip, mostCommonLabel: common)
    }

    static func dayLabel(_ ms: Double) -> String {
        let today = Clock.startOfTodayMs()
        let diff = Int((today - ms) / 86_400_000)
        if diff == 0 { return "Today" }
        if diff == 1 { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date(timeIntervalSince1970: ms / 1000))
    }

    static func timeLabel(_ ms: Double) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: Date(timeIntervalSince1970: ms / 1000))
    }
}
