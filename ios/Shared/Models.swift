import Foundation

// The data model is wire-compatible with the web app. The Supabase
// `moodring_state.data` jsonb column holds exactly this `AppData` shape, with
// these (camelCase) keys, so both clients sync to the same row seamlessly.

struct Emoji: Codable, Identifiable, Hashable {
    var id: String
    var emoji: String
    var label: String
    var value: Int          // valence rank 1 (low) → 10 (high), drives the trend
}

struct MoodLog: Codable, Identifiable, Hashable {
    var id: String
    var emoji: String
    var label: String
    var value: Int
    var ts: Double          // epoch MILLISECONDS (matches JS Date.now())
    var note: String?

    var date: Date { Date(timeIntervalSince1970: ts / 1000) }
}

struct Booster: Codable, Identifiable, Hashable {
    var id: String
    var text: String
}

struct TodayBoost: Codable, Hashable {
    var date: Double        // start-of-day epoch ms
    var id: String          // booster id chosen for the day
    var done: Bool
}

/// The entire app state — one JSON object per user.
struct AppData: Codable, Hashable {
    var emojis: [Emoji]
    var logs: [MoodLog]
    var boosters: [Booster]
    var dismissedSuggestions: [String]
    var savedSuggestions: [String]
    var todayBoost: TodayBoost?
    var theme: String?      // "dark" | "light" | nil (follow system)

    /// A fresh account / first launch, seeded with the defaults from the brief.
    static var seeded: AppData {
        AppData(
            emojis: Defaults.emojis,
            logs: [],
            boosters: Defaults.boosters,
            dismissedSuggestions: [],
            savedSuggestions: [],
            todayBoost: nil,
            theme: nil
        )
    }

    /// Decoding tolerates missing keys (older rows) by falling back to seeded
    /// defaults, mirroring the web app's `Object.assign(defaultState(), parsed)`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let seed = AppData.seeded
        emojis = (try? c.decode([Emoji].self, forKey: .emojis)) ?? seed.emojis
        logs = (try? c.decode([MoodLog].self, forKey: .logs)) ?? []
        boosters = (try? c.decode([Booster].self, forKey: .boosters)) ?? seed.boosters
        dismissedSuggestions = (try? c.decode([String].self, forKey: .dismissedSuggestions)) ?? []
        savedSuggestions = (try? c.decode([String].self, forKey: .savedSuggestions)) ?? []
        todayBoost = try? c.decodeIfPresent(TodayBoost.self, forKey: .todayBoost)
        theme = try? c.decodeIfPresent(String.self, forKey: .theme)
    }

    init(emojis: [Emoji], logs: [MoodLog], boosters: [Booster],
         dismissedSuggestions: [String], savedSuggestions: [String],
         todayBoost: TodayBoost?, theme: String?) {
        self.emojis = emojis
        self.logs = logs
        self.boosters = boosters
        self.dismissedSuggestions = dismissedSuggestions
        self.savedSuggestions = savedSuggestions
        self.todayBoost = todayBoost
        self.theme = theme
    }
}

/// A context-aware nudge. `trigger` decides when it's eligible to show.
struct Suggestion: Identifiable, Hashable {
    let id: String
    let text: String
    let trigger: String     // "always" | "lowRecent" | "highRecent"
}
