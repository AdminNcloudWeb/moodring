import Foundation

/// Supabase project credentials — the SAME project the web app uses, so the
/// native app and web app share accounts and synced data.
///
/// The anon key is public by design: Row Level Security (see
/// `supabase/schema.sql`) is what protects user data, so it's safe to ship in
/// the app binary.
enum Config {
    static let supabaseURL = URL(string: "https://xulpqduijuisiuwkdrlm.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh1bHBxZHVpanVpc2l1d2tkcmxtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0Mzg2MjIsImV4cCI6MjA5NzAxNDYyMn0.pkxvmTBu00YfIp0-l3KuEoyUdBU_D5k5QFfuoP3_CgY"

    /// Custom URL scheme for magic-link / email-confirmation redirects.
    /// Add `moodring://login-callback` to Supabase → Authentication → URL
    /// Configuration → Redirect URLs for this to resolve back into the app.
    static let authRedirect = URL(string: "moodring://login-callback")!

    /// Public web app — the native app links out to these pages rather than
    /// duplicating the legal/support copy.
    static let webBaseURL = URL(string: "https://moodring-rho.vercel.app")!
    static let privacyURL = URL(string: "https://moodring-rho.vercel.app/privacy")!
    static let contactURL = URL(string: "https://moodring-rho.vercel.app/contact")!
}
