import Foundation
import Supabase

/// Thin wrapper over the Supabase client: auth + the single `moodring_state`
/// row read/write. Mirrors the web app's pullRemote / pushRemote contract.
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: Config.supabaseURL,
            supabaseKey: Config.supabaseAnonKey
        )
    }

    // MARK: Auth

    var currentUserID: UUID? { client.auth.currentUser?.id }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    /// Returns true if a session was created immediately (email confirmation
    /// off); false means "check your email to confirm".
    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await client.auth.signUp(email: email, password: password)
        return response.session != nil
    }

    func sendMagicLink(email: String) async throws {
        try await client.auth.signInWithOTP(email: email, redirectTo: Config.authRedirect)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Complete a magic-link / OAuth redirect opened into the app.
    func handle(url: URL) async {
        try? await client.auth.session(from: url)
    }

    // MARK: State sync

    /// Row shape for the `moodring_state` table. Property names match the
    /// column names exactly (snake_case) so no key conversion is needed.
    private struct StateRow: Codable {
        let user_id: String
        let data: AppData
        let updated_at: String
    }

    private struct DataOnly: Codable { let data: AppData }

    /// Pull the cloud copy. Returns nil if the user has no row yet.
    func pull() async throws -> AppData? {
        guard let uid = currentUserID else { return nil }
        let rows: [DataOnly] = try await client
            .from("moodring_state")
            .select("data")
            .eq("user_id", value: uid.uuidString.lowercased())
            .limit(1)
            .execute()
            .value
        return rows.first?.data
    }

    /// Upsert the full state for the signed-in user.
    func push(_ data: AppData) async throws {
        guard let uid = currentUserID else { return }
        let iso = ISO8601DateFormatter().string(from: Date())
        let row = StateRow(user_id: uid.uuidString.lowercased(), data: data, updated_at: iso)
        try await client
            .from("moodring_state")
            .upsert(row, onConflict: "user_id")
            .execute()
    }
}
