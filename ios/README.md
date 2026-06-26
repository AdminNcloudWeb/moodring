# Moodring — iOS (SwiftUI) app + widget

A native SwiftUI client for Moodring that shares the **same Supabase backend**
as the web app, plus a **home-screen widget** for one-tap logging (the brief's
Phase 2–3). Accounts and synced data are identical across web and iOS.

> You need a **Mac with Xcode 15+** and (to ship) an **Apple Developer Program**
> membership ($99/yr). None of this can be built on Linux — these are source
> files for you to open on your Mac.

---

## What's here

```
ios/
├── project.yml              # XcodeGen spec → generates Moodring.xcodeproj
├── Shared/                  # compiled into BOTH the app and the widget
│   ├── AppGroup.swift        # App Group id + shared UserDefaults
│   ├── Models.swift          # Emoji / MoodLog / Booster / TodayBoost / AppData
│   ├── Defaults.swift        # default emojis, boosters, suggestions, date helpers
│   ├── SharedStore.swift     # local persistence in the App Group container
│   └── Theme.swift           # warm palette (light/dark), card styling
├── App/                     # app target
│   ├── Config.swift          # Supabase URL + anon key (public) + auth redirect
│   ├── SupabaseService.swift # auth + moodring_state read/write
│   ├── AppState.swift        # ObservableObject: state, sync, all actions
│   ├── Analytics.swift       # trend / weekly summary / day bucketing
│   ├── MoodringApp.swift     # @main
│   ├── ContentView.swift     # tab bar + auth gating + app-lock overlay
│   ├── AuthView.swift        # sign-in / create-account screens + magic link
│   ├── BiometricAuth.swift   # Face ID / Touch ID / passcode wrapper
│   ├── LockView.swift        # app-lock screen (biometric unlock)
│   ├── LogView.swift         # emoji grid, today's boost, today's logs
│   ├── HistoryView.swift     # 7-day trend chart + weekly summary + timeline
│   ├── BoostersView.swift    # boosters list + suggestion cards
│   ├── SettingsView.swift    # emoji editor, theme, app lock, export, sign out, reset
│   └── Assets.xcassets       # AppIcon (the smiley, 1024px)
└── Widget/                  # widget extension
    ├── MoodringWidgetBundle.swift
    ├── MoodWidget.swift      # timeline + interactive emoji buttons
    └── LogMoodIntent.swift   # App Intent: tap emoji → log (no app launch)
```

---

## Quick start

### 1. Generate the Xcode project
The fastest path uses [XcodeGen](https://github.com/yonyz/XcodeGen) so you don't
hand-build the project file:

```bash
brew install xcodegen
cd ios
xcodegen generate
open Moodring.xcodeproj
```

> **No XcodeGen?** Create a new App project in Xcode (iOS, SwiftUI), add a
> Widget Extension target, then drag in the `Shared/`, `App/`, and `Widget/`
> folders — add `Shared/*` to **both** targets. The steps below (capabilities,
> package, App Group) are the same either way.

### 2. Add the Supabase Swift package
If it didn't resolve automatically: **File → Add Package Dependencies →**
`https://github.com/supabase/supabase-swift` → add **Supabase** to the
**Moodring** app target (the widget doesn't need it).

### 3. Signing & capabilities (both targets)
1. Select each target → **Signing & Capabilities** → set your **Team**.
2. Give each a unique **Bundle Identifier** (the defaults are
   `co.willpickles.moodring` and `…​.widget` — change the prefix to yours).
3. Add the **App Groups** capability to **both** targets and enable the *same*
   group id. It must match `AppGroup.id` in `Shared/AppGroup.swift`
   (default `group.co.willpickles.moodring`). Update the string if you use your
   own group.
4. App lock uses Face ID, so the app target needs an **`NSFaceIDUsageDescription`**
   Info.plist string (XcodeGen adds it from `project.yml`; add it by hand if you
   built the project manually). Touch ID and passcode need no extra key.

### 4. Supabase redirect (for magic links)
In the Supabase dashboard → **Authentication → URL Configuration → Redirect
URLs**, add `moodring://login-callback`. The custom URL scheme is already
declared in the app's Info via `project.yml`.

### 5. Run
Pick an **iOS 17+** simulator or device and run. Create an account (or sign in
with one you made on the web) — your logs, boosters and emojis sync straight in.
Long-press the home screen → add the **Moodring** widget → tap an emoji to log.

---

## How it fits together

- **Same data, same row.** The app reads/writes `moodring_state.data` (one jsonb
  blob per user) exactly like the web app. `AppData`'s JSON keys are camelCase
  to match. RLS still protects every row.
- **Local-first.** State lives in the App Group container (`SharedStore`); the
  cloud push is debounced (800 ms) just like the web app, and the cloud copy is
  adopted on sign-in.
- **Widget logging.** `LogMoodIntent` appends a log to the shared container and
  reloads the widget. The app calls `reconcileFromSharedStore()` on foreground
  to pick up widget-added logs and sync them up.

---

## Known scaffolding gaps (deliberate, easy follow-ups)

- **Widget → cloud is indirect.** The widget writes locally; the app syncs on
  next launch. Direct upload from the intent would need the Supabase SDK + a
  shared Keychain session in the extension. Fine to add later.
- **Conflict resolution is last-writer-wins** (same as the web app). For heavy
  multi-device use you'd want per-field merge or `updated_at` comparison.
- **Sign in with Apple** isn't wired (email/password + magic link only, matching
  web). Supabase supports Apple as an OAuth provider; add the capability +
  `signInWithIdToken` when you want it. Note Apple *requires* it if you add other
  social logins.
- **Emoji drag-reorder** uses the standard List `EditMode`; tap **Edit** in the
  Moods section.

---

## App Store checklist

- [ ] Unique bundle IDs registered under your team
- [ ] App Group created in the developer portal, enabled on both targets
- [ ] `moodring://login-callback` added to Supabase redirect URLs
- [ ] App icon present (included) + launch screen (generated)
- [ ] Privacy nutrition label: you collect mood logs tied to an account (email)
- [ ] TestFlight build for beta, then submit for review
