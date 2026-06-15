import Foundation

/// Identifiers shared between the app and the widget extension.
///
/// The App Group lets both processes read/write the same on-disk state, so a
/// mood logged from the widget shows up in the app (and syncs to Supabase on
/// the app's next foreground). This MUST match the App Group capability id you
/// configure in Xcode / the developer portal for both targets.
enum AppGroup {
    static let id = "group.co.willpickles.moodring"

    /// UserDefaults suite backed by the shared App Group container.
    static let defaults = UserDefaults(suiteName: id) ?? .standard

    /// Key under which the whole `AppData` blob is persisted (mirrors the web
    /// app's `localStorage["moodring.v1"]`).
    static let stateKey = "moodring.v1"
}
