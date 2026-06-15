import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var state: AppState

    private var averages: [Analytics.DayAverage] { Analytics.dailyAverages(state.data.logs, days: 7) }
    private var trend: Analytics.Trend { Analytics.trend(state.data.logs) }
    private var summary: Analytics.WeeklySummary { Analytics.weeklySummary(state.data.logs) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    trendCard
                    summaryCard
                    Text("TIMELINE").sectionTitle()
                    timeline
                }
                .padding(16)
            }
            .background(Palette.bg)
            .navigationTitle("Last 7 days")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Trend

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trend").font(.headline)
                Spacer()
                Text(trendLabel).font(.subheadline).foregroundStyle(Palette.accent)
            }
            Chart(averages) { day in
                if let avg = day.average {
                    LineMark(x: .value("Day", day.dayStartMs), y: .value("Mood", avg))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Palette.accent)
                    PointMark(x: .value("Day", day.dayStartMs), y: .value("Mood", avg))
                        .foregroundStyle(Palette.accent)
                }
            }
            .chartYScale(domain: 1...10)
            .chartXAxis(.hidden)
            .frame(height: 120)
        }
        .card()
    }

    private var trendLabel: String {
        switch trend {
        case .up: return "Trending up ↗"
        case .down: return "Trending down ↘"
        case .steady: return "Holding steady →"
        case .none: return "Not enough data yet"
        }
    }

    // MARK: Weekly summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week").font(.headline)
            if summary.count == 0 {
                Text("Nothing logged in the last 7 days.")
                    .font(.subheadline).foregroundStyle(Palette.textSoft)
            } else {
                row("Logs", "\(summary.count)")
                if let peak = summary.peak { row("Peak", "\(peak.emoji) \(peak.label)") }
                if let dip = summary.dip { row("Dip", "\(dip.emoji) \(dip.label)") }
                if let common = summary.mostCommonLabel { row("Most common", common) }
            }
        }
        .card()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Palette.textSoft)
            Spacer()
            Text(value)
        }.font(.subheadline)
    }

    // MARK: Timeline

    @ViewBuilder private var timeline: some View {
        let byDay = Dictionary(grouping: state.data.logs.filter {
            $0.ts >= Clock.startOfTodayMs() - 6 * 86_400_000
        }) { Clock.startOfDayMs($0.ts) }

        if byDay.isEmpty {
            Text("No history yet.").font(.subheadline).foregroundStyle(Palette.textSoft)
        } else {
            ForEach(byDay.keys.sorted(by: >), id: \.self) { day in
                VStack(alignment: .leading, spacing: 6) {
                    Text(Analytics.dayLabel(day)).font(.subheadline.weight(.semibold))
                    HStack {
                        ForEach(byDay[day]!.sorted { $0.ts < $1.ts }) { log in
                            Text(log.emoji).font(.title3)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 12)
            }
        }
    }
}
