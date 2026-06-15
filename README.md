# Moodring 💍

A lightweight mood tracker built around radical simplicity. One tap logs how you
feel — no forms, no friction. Over time it surfaces patterns and gently suggests
things that help.

This repo is the **Phase 1 Web App (MVP)** from [`brief.md`](./brief.md).

---

## Status

**Phase 1 MVP — feature complete + optional accounts/sync.** Built as a
zero-dependency static web app (plain HTML/CSS/JS + `localStorage`). No build
step. Works fully offline/local; add Supabase credentials to enable accounts and
cloud sync across devices.

> **Deploy state:** code is committed locally on `main` and is push-ready.
> GitHub push + Vercel deploy still need your login — see
> [Ship it](#ship-it-github--vercel) for the exact commands.

### What's done ✅

| Brief requirement | Status |
|---|---|
| Emoji tap to log mood (scrollable, broad spectrum) | ✅ |
| Default emoji set (10 moods, crisis → peak + non-valence) | ✅ |
| Multiple logs per day, auto-timestamped | ✅ |
| Optional one-line note after selecting (never required) | ✅ |
| Today's logs preview + delete a log | ✅ |
| **Custom emojis** — add / remove / drag-reorder (2–12) | ✅ |
| Customisation lives in Settings, not the log view | ✅ |
| **Boosters** — user-editable list (add / remove) | ✅ |
| **Suggestions** — context-aware cards, save or dismiss | ✅ |
| **History** — last 7 days timeline grouped by day | ✅ |
| Gentle trend line (up / down / steady, no score, no streaks) | ✅ |
| Opt-in-style weekly summary (peaks, dips, most common) | ✅ |
| Minimal & warm design, soft background, rounded type | ✅ |
| **Dark mode from day one** (follows system, manual toggle) | ✅ |
| Data export — JSON + CSV | ✅ (bonus) |
| Reset all data | ✅ (bonus) |
| **Accounts** — Supabase email/password + magic link | ✅ (Phase 2 pulled forward) |
| **Cloud sync** — per-user state, local-first fallback | ✅ (Phase 2 pulled forward) |

### Not in this phase (per brief)

- Accounts / cloud sync (Phase 2)
- Native mobile app + home-screen widget (Phase 2–3)
- ML-based suggestions (currently rule-based)
- Journaling, clinical/crisis tools, gamification, social — explicitly out of scope

---

## Run it

It's a static site — no install needed.

```bash
# from the project root
python3 -m http.server 8000
# then open http://localhost:8000
```

Or just open `index.html` directly in a browser.

---

## Auth & cloud sync (Supabase)

Accounts are **optional**. With no config the app runs local-only (the original
anonymous MVP). Add credentials and it gains login + cross-device sync.

### Setup (≈3 minutes)

1. Create a project at [supabase.com](https://supabase.com).
2. In the dashboard → **SQL Editor**, paste and run [`supabase/schema.sql`](./supabase/schema.sql).
   This creates the `moodring_state` table with Row Level Security so each user
   only ever touches their own data.
3. Dashboard → **Project Settings → API**, copy your **Project URL** and **anon
   public key**.
4. Paste both into [`config.js`](./config.js).
5. (Optional) For magic links / email confirmation to work in production, add
   your deployed URL under **Authentication → URL Configuration → Redirect URLs**.

The anon key is **public by design** — RLS is what protects data — so it's safe
to commit `config.js` and ship it to a static host.

### How sync works

- State lives in `localStorage` first (instant, offline-capable).
- When signed in, every change is debounced and upserted to Supabase
  (`moodring_state`, one JSON row per user).
- On sign-in, the cloud copy is pulled and adopted (enabling multi-device). A
  brand-new account is seeded with whatever was logged locally.
- When Supabase is configured, an account is required — the overlay asks users
  to sign in or create one (no account-less mode). With no config, the app
  falls back to local-only and the overlay is skipped entirely.

---

## Ship it (GitHub + Vercel)

The repo is committed locally on `main`. These steps need **your** GitHub/Vercel
login, so run them yourself (in Claude Code you can prefix with `!`):

### Push to GitHub

```bash
# with the gh CLI:
gh repo create moodring --public --source=. --remote=origin --push

# or manually, after creating an empty repo on github.com:
git remote add origin https://github.com/<you>/moodring.git
git push -u origin main
```

### Deploy to Vercel

Easiest is the dashboard — no CLI needed:

1. [vercel.com/new](https://vercel.com/new) → **Import** your `moodring` repo.
2. Framework preset: **Other**. Build command: *(none)*. Output dir: *(root)*.
3. **Deploy.**

Or via CLI: `npm i -g vercel && vercel --prod`.

`vercel.json` is already configured for a static, no-build deploy. After
deploying, add the live URL to Supabase's redirect URLs (step 5 above) so magic
links resolve correctly.

---

## How it works

- **`index.html`** — markup for the four views (Log, History, Boosters, Settings)
  and the bottom tab bar.
- **`styles.css`** — theming via CSS custom properties; `[data-theme="dark"]`
  overrides drive dark mode.
- **`app.js`** — all logic in one IIFE. State is a single object persisted to
  `localStorage` under `moodring.v1`.

### Data model

```js
{
  emojis:  [{ id, emoji, label, value }],   // value = valence 1–10 for the trend
  logs:    [{ id, emoji, label, value, ts, note? }],
  boosters:[{ id, text }],
  dismissedSuggestions: [id],
  savedSuggestions:     [id],
  theme: 'dark' | 'light' | null            // null = follow system
}
```

### Suggestions logic

Rule-based for the MVP. Each suggestion has a `trigger`:
`always`, `lowRecent` (avg mood ≤ 4 in the last 6h), or `highRecent` (avg ≥ 8).
Dismissed and already-saved suggestions are filtered out; up to 3 show at once.

---

## Decisions made (open questions from the brief)

Since these blocked nothing, sensible defaults were chosen — easy to revisit:

1. **Custom emoji order** → free arrangement (drag-and-drop), not auto-sorted by valence.
2. **Suggestions** → rule-based triggers (ML deferred to a later phase).
3. **Data export** → both JSON and CSV provided.
4. **Notifications** → not in a static MVP (needs service worker / native).
5. **Dark mode** → follows system, with a manual override toggle.

---

## Project structure

```
moodring/
├── index.html          # views, tab bar, auth overlay
├── styles.css          # theming + layout
├── app.js              # state, logging, history, boosters, settings, auth/sync
├── config.js           # Supabase credentials (fill in to enable accounts)
├── vercel.json         # static, no-build deploy config
├── supabase/
│   └── schema.sql      # moodring_state table + RLS policies
├── brief.md            # product brief (source of truth)
└── README.md           # this file
```
