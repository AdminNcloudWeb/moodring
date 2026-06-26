import Foundation
import SwiftUI
import WidgetKit

enum AuthStatus { case unknown, signedOut, signedIn }

/// Single source of truth for the app. Holds `AppData`, drives Supabase sync,
/// and exposes the same actions the web app has (log, boosters, emoji editing,
/// suggestions, theme, export).
@MainActor
final class AppState: ObservableObject {
    @Published var data: AppData
    @Published var auth: AuthStatus = .unknown
    @Published var userEmail: String?
    @Published var syncing = false

    /// Device-local app-lock preference (Face ID / Touch ID / passcode). Stored
    /// per device, not synced — a lock only makes sense where it can be unlocked.
    @Published var appLockEnabled: Bool {
        didSet { AppGroup.defaults.set(appLockEnabled, forKey: Self.appLockKey) }
    }
    /// Whether the app is currently locked and waiting to be unlocked.
    @Published var locked: Bool

    private static let appLockKey = "moodring.appLockEnabled"

    private let store = SharedStore.shared
    private let service = SupabaseService.shared
    private var pushTask: Task<Void, Never>?
    private var unlocking = false

    init() {
        data = store.load()
        let lockPref = AppGroup.defaults.bool(forKey: Self.appLockKey)
        appLockEnabled = lockPref
        // Start locked when the preference is on, so a restored session never
        // flashes content before the unlock prompt. Resolved by `observeAuth`.
        locked = lockPref
        observeAuth()
    }

    // MARK: Persistence + debounced cloud push

    private func persist() {
        store.save(data)
        WidgetCenter.shared.reloadAllTimelines()
        guard auth == .signedIn else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let self, !Task.isCancelled else { return }
            try? await self.service.push(self.data)
        }
    }

    // MARK: Auth lifecycle

    private func observeAuth() {
        Task {
            for await change in service.client.auth.authStateChanges {
                let session = change.session
                userEmail = session?.user.email
                let signedIn = session != nil
                let wasSignedIn = auth == .signedIn
                auth = signedIn ? .signedIn : .signedOut

                switch change.event {
                case .signedIn:
                    // Fresh interactive sign-in: the user just proved who they
                    // are, so don't immediately demand a second unlock.
                    locked = false
                case .initialSession:
                    // Session restored at launch: lock if the preference is on.
                    locked = signedIn && appLockEnabled
                case .signedOut:
                    locked = false
                default:
                    break
                }

                if signedIn && !wasSignedIn { await pullRemote() }
            }
        }
    }

    // MARK: App lock

    /// Turn app lock on/off. Enabling first requires a successful authentication
    /// so we never lock the user out of a device they can't unlock.
    func setAppLock(enabled: Bool) {
        if enabled {
            Task {
                let ok = await BiometricAuth.authenticate(reason: "Enable app lock for Moodring")
                if ok { appLockEnabled = true }
            }
        } else {
            appLockEnabled = false
            locked = false
        }
    }

    /// Prompt for Face ID / Touch ID / passcode. Single-flight so overlapping
    /// triggers (lock screen appearing + app returning to foreground) don't
    /// stack multiple system prompts.
    func unlock() async {
        guard locked, !unlocking else { return }
        unlocking = true
        defer { unlocking = false }
        if await BiometricAuth.authenticate(reason: "Unlock Moodring") {
            locked = false
        }
    }

    /// Re-lock when the app is sent to the background (if lock is enabled and
    /// the user is signed in). Triggered from `.background`, not `.inactive`, so
    /// the system biometric sheet doesn't cause a re-lock mid-unlock.
    func lockOnBackground() {
        if appLockEnabled && auth == .signedIn { locked = true }
    }

    /// Called when the app is reopened from the background — auto-prompt if it
    /// came back locked.
    func requestUnlockIfNeeded() {
        guard appLockEnabled, auth == .signedIn, locked else { return }
        Task { await unlock() }
    }

    /// Adopt the cloud copy on sign-in (multi-device), or seed the cloud from
    /// local on a brand-new account — same as the web app.
    func pullRemote() async {
        syncing = true
        defer { syncing = false }
        do {
            if let remote = try await service.pull() {
                data = remote
                store.save(data)
                WidgetCenter.shared.reloadAllTimelines()
            } else {
                try await service.push(data)
            }
        } catch {
            print("Moodring pullRemote:", error.localizedDescription)
        }
    }

    func signOut() {
        Task {
            try? await service.signOut()
            // authStateChanges flips `auth` to .signedOut, which re-presents the
            // auth screen (an account is required, matching the web app).
        }
    }

    /// Reconcile any logs the widget appended while the app was suspended.
    func reconcileFromSharedStore() {
        let disk = store.load()
        let known = Set(data.logs.map(\.id))
        let extra = disk.logs.filter { !known.contains($0.id) }
        guard !extra.isEmpty else { return }
        data.logs.append(contentsOf: extra)
        persist()
    }

    // MARK: Logging

    func log(_ emoji: Emoji, note: String? = nil) {
        let entry = MoodLog(id: Clock.newId(), emoji: emoji.emoji, label: emoji.label,
                            value: emoji.value, ts: Clock.nowMs(),
                            note: (note?.isEmpty == false) ? note : nil)
        data.logs.append(entry)
        persist()
    }

    func deleteLog(_ id: String) {
        data.logs.removeAll { $0.id == id }
        persist()
    }

    var todaysLogs: [MoodLog] {
        let today = Clock.startOfTodayMs()
        return data.logs
            .filter { Clock.startOfDayMs($0.ts) == today }
            .sorted { $0.ts > $1.ts }
    }

    // MARK: Today's boost

    /// Read-only: the valid boost for today, or nil. Safe to call from `body`.
    var currentBoost: TodayBoost? {
        let today = Clock.startOfTodayMs()
        guard let tb = data.todayBoost, tb.date == today,
              data.boosters.contains(where: { $0.id == tb.id }) else { return nil }
        return tb
    }

    /// Mutating: pick today's boost if needed. Call from `.onAppear`/`.task`,
    /// never from within a view body.
    func ensureTodayBoost() {
        let today = Clock.startOfTodayMs()
        if currentBoost != nil { return }
        guard let pick = data.boosters.randomElement() else {
            if data.todayBoost != nil { data.todayBoost = nil; persist() }
            return
        }
        data.todayBoost = TodayBoost(date: today, id: pick.id, done: false)
        persist()
    }

    func boosterText(id: String) -> String? { data.boosters.first { $0.id == id }?.text }

    func shuffleBoost() {
        guard data.boosters.count >= 2 else { return }
        let currentID = data.todayBoost?.id
        let pick = data.boosters.filter { $0.id != currentID }.randomElement()
        guard let pick else { return }
        data.todayBoost = TodayBoost(date: Clock.startOfTodayMs(), id: pick.id, done: false)
        persist()
    }

    func toggleBoostDone() {
        ensureTodayBoost()
        guard var tb = currentBoost else { return }
        tb.done.toggle()
        data.todayBoost = tb
        persist()
    }

    // MARK: Boosters

    func addBooster(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        data.boosters.append(Booster(id: Clock.newId(), text: t))
        persist()
    }

    func removeBooster(_ id: String) {
        data.boosters.removeAll { $0.id == id }
        persist()
    }

    // MARK: Suggestions

    var activeSuggestions: [Suggestion] {
        let recent = recentAverage(hours: 6)
        return Defaults.suggestions.filter { s in
            if data.dismissedSuggestions.contains(s.id) { return false }
            if data.savedSuggestions.contains(s.id) { return false }
            switch s.trigger {
            case "lowRecent":  return (recent ?? 99) <= 4
            case "highRecent": return (recent ?? 0) >= 8
            default:           return true
            }
        }.prefix(3).map { $0 }
    }

    func saveSuggestion(_ s: Suggestion) {
        data.boosters.append(Booster(id: Clock.newId(), text: s.text))
        data.savedSuggestions.append(s.id)
        persist()
    }

    func dismissSuggestion(_ s: Suggestion) {
        data.dismissedSuggestions.append(s.id)
        persist()
    }

    private func recentAverage(hours: Double) -> Double? {
        let cutoff = Clock.nowMs() - hours * 3_600_000
        let recent = data.logs.filter { $0.ts >= cutoff }
        guard !recent.isEmpty else { return nil }
        return Double(recent.map(\.value).reduce(0, +)) / Double(recent.count)
    }

    // MARK: Emoji editing

    func addEmoji(_ emoji: String, label: String, value: Int) {
        guard data.emojis.count < Defaults.maxEmoji else { return }
        data.emojis.append(Emoji(id: Clock.newId(), emoji: emoji, label: label, value: value))
        persist()
    }

    func removeEmoji(_ id: String) {
        guard data.emojis.count > Defaults.minEmoji else { return }
        data.emojis.removeAll { $0.id == id }
        persist()
    }

    func moveEmoji(from: IndexSet, to: Int) {
        data.emojis.move(fromOffsets: from, toOffset: to)
        persist()
    }

    // MARK: Theme

    var preferredColorScheme: ColorScheme? {
        switch data.theme {
        case "dark":  return .dark
        case "light": return .light
        default:      return nil    // follow system
        }
    }

    func setTheme(_ theme: String?) {
        data.theme = theme
        persist()
    }

    // MARK: Export

    func exportJSON() -> String {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? e.encode(data)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    func exportCSV() -> String {
        var rows = ["timestamp,emoji,label,value,note"]
        for l in data.logs.sorted(by: { $0.ts < $1.ts }) {
            let iso = ISO8601DateFormatter().string(from: l.date)
            let note = (l.note ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            rows.append("\(iso),\(l.emoji),\(l.label),\(l.value),\"\(note)\"")
        }
        return rows.joined(separator: "\n")
    }

    func resetAll() {
        data = .seeded
        persist()
    }
}
