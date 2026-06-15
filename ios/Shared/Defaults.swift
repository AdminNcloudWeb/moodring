import Foundation

/// Default content from the product brief — kept identical to the web app's
/// DEFAULT_EMOJIS / DEFAULT_BOOSTERS / SUGGESTIONS so both clients agree.
enum Defaults {
    static let minEmoji = 2
    static let maxEmoji = 12

    static let emojis: [Emoji] = [
        Emoji(id: "e1", emoji: "😭", label: "Crying", value: 1),
        Emoji(id: "e2", emoji: "😔", label: "Low", value: 2),
        Emoji(id: "e3", emoji: "😟", label: "Anxious", value: 3),
        Emoji(id: "e4", emoji: "😐", label: "Neutral", value: 5),
        Emoji(id: "e5", emoji: "😌", label: "Calm", value: 6),
        Emoji(id: "e6", emoji: "🙂", label: "Okay", value: 6),
        Emoji(id: "e7", emoji: "💪", label: "Healthy", value: 8),
        Emoji(id: "e8", emoji: "😊", label: "Good", value: 8),
        Emoji(id: "e9", emoji: "😄", label: "Great", value: 9),
        Emoji(id: "e10", emoji: "🤩", label: "Ecstatic", value: 10),
    ]

    static let boosters: [Booster] = [
        Booster(id: "b0", text: "Go for a short walk"),
        Booster(id: "b1", text: "Drink a glass of water"),
    ]

    static let suggestions: [Suggestion] = [
        Suggestion(id: "s_walk", text: "Mood has been low for a while — a 5-minute walk outside can help reset.", trigger: "lowRecent"),
        Suggestion(id: "s_breathe", text: "Try a slow breathing exercise: inhale 4s, hold 4s, exhale 6s.", trigger: "lowRecent"),
        Suggestion(id: "s_water", text: "Have you had water recently? Hydration affects mood more than we think.", trigger: "always"),
        Suggestion(id: "s_sun", text: "Step into some sunlight for a few minutes if you can.", trigger: "always"),
        Suggestion(id: "s_reach", text: "Reach out to someone you like — a quick message counts.", trigger: "lowRecent"),
        Suggestion(id: "s_log", text: "You logged a great mood! What did you do today? Add it as a booster.", trigger: "highRecent"),
        Suggestion(id: "s_stretch", text: "A quick stretch can lift your energy. Reach for the ceiling.", trigger: "always"),
    ]
}

// MARK: - Shared date helpers (match the web app's day bucketing)

enum Clock {
    static func nowMs() -> Double { Date().timeIntervalSince1970 * 1000 }

    /// Local midnight (ms) for the day containing `ms`.
    static func startOfDayMs(_ ms: Double) -> Double {
        let date = Date(timeIntervalSince1970: ms / 1000)
        let start = Calendar.current.startOfDay(for: date)
        return start.timeIntervalSince1970 * 1000
    }

    static func startOfTodayMs() -> Double { startOfDayMs(nowMs()) }

    static func newId() -> String { UUID().uuidString }
}
