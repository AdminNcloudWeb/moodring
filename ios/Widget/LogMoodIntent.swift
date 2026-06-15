import AppIntents
import WidgetKit

/// Logs a mood straight from the home-screen widget — no app launch (iOS 17+).
/// Writes to the shared App Group store; the app reconciles + syncs to Supabase
/// on its next foreground.
struct LogMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Mood"
    static var isDiscoverable = false

    @Parameter(title: "Emoji") var emoji: String
    @Parameter(title: "Label") var label: String
    @Parameter(title: "Value") var value: Int

    init() {}
    init(emoji: String, label: String, value: Int) {
        self.emoji = emoji
        self.label = label
        self.value = value
    }

    func perform() async throws -> some IntentResult {
        SharedStore.shared.appendLog(emoji: emoji, label: label, value: value)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
