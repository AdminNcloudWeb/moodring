import Foundation

/// Local persistence in the App Group container, shared by the app and widget.
///
/// This is the equivalent of the web app's `localStorage` layer. The app owns
/// the full read/modify/sync cycle; the widget only ever *appends* a log via
/// `appendLog`, which the app reconciles on its next foreground.
struct SharedStore {
    static let shared = SharedStore()

    private var defaults: UserDefaults { AppGroup.defaults }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        // Keep camelCase keys to stay wire-compatible with the web app + Supabase.
        e.keyEncodingStrategy = .useDefaultKeys
        return e
    }
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }

    func load() -> AppData {
        guard let raw = defaults.data(forKey: AppGroup.stateKey),
              let data = try? decoder.decode(AppData.self, from: raw)
        else { return .seeded }
        return data
    }

    func save(_ data: AppData) {
        guard let raw = try? encoder.encode(data) else { return }
        defaults.set(raw, forKey: AppGroup.stateKey)
    }

    /// Append a mood log to the shared state. Called from the widget intent.
    /// Safe to call from either process — it reloads, mutates, and rewrites.
    func appendLog(emoji: String, label: String, value: Int, note: String? = nil) {
        var data = load()
        data.logs.append(
            MoodLog(id: Clock.newId(), emoji: emoji, label: label,
                    value: value, ts: Clock.nowMs(), note: note)
        )
        save(data)
    }
}
