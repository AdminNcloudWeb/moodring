/* ===== Moodring configuration =====
 *
 * Paste your Supabase project credentials below to enable accounts + cloud sync.
 * Find them in your Supabase dashboard → Project Settings → API.
 *
 * The anon (public) key is SAFE to expose in client-side code — Row Level
 * Security (see supabase/schema.sql) is what actually protects user data.
 *
 * Leave these blank to run Moodring in local-only mode (no login required).
 */
window.MOODRING_CONFIG = {
  SUPABASE_URL: "",       // e.g. "https://abcdefgh.supabase.co"
  SUPABASE_ANON_KEY: "",  // e.g. "eyJhbGciOi..."
};
