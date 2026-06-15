import WidgetKit
import SwiftUI

struct MoodEntry: TimelineEntry {
    let date: Date
    let emojis: [Emoji]
    let lastLog: MoodLog?
}

struct MoodProvider: TimelineProvider {
    private func snapshot() -> MoodEntry {
        let data = SharedStore.shared.load()
        let last = data.logs.max { $0.ts < $1.ts }
        return MoodEntry(date: Date(), emojis: data.emojis, lastLog: last)
    }

    func placeholder(in context: Context) -> MoodEntry {
        MoodEntry(date: Date(), emojis: Defaults.emojis, lastLog: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodEntry) -> Void) {
        completion(snapshot())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodEntry>) -> Void) {
        // Refresh hourly so "last logged" context stays reasonably current;
        // tapping a button reloads immediately via WidgetCenter.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [snapshot()], policy: .after(next)))
    }
}

struct MoodWidgetView: View {
    var entry: MoodEntry
    @Environment(\.widgetFamily) var family

    /// A spread across the spectrum so the widget isn't all one end.
    private var picks: [Emoji] {
        let count = family == .systemSmall ? 3 : 5
        guard entry.emojis.count > count else { return entry.emojis }
        let stride = Double(entry.emojis.count - 1) / Double(count - 1)
        return (0..<count).map { entry.emojis[Int((Double($0) * stride).rounded())] }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("How are you?").font(.caption).foregroundStyle(Palette.textSoft)
                Spacer()
                if let last = entry.lastLog { Text(last.emoji).font(.caption) }
            }
            HStack(spacing: family == .systemSmall ? 6 : 10) {
                ForEach(picks) { e in
                    Button(intent: LogMoodIntent(emoji: e.emoji, label: e.label, value: e.value)) {
                        Text(e.emoji).font(.system(size: family == .systemSmall ? 26 : 32))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .containerBackground(Palette.bg, for: .widget)
    }
}

struct MoodWidget: Widget {
    let kind = "MoodWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoodProvider()) { entry in
            MoodWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Log")
        .description("Tap an emoji to log your mood without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
