# Moodring 💍

A lightweight mood tracker built around radical simplicity. One tap logs how you
feel — no forms, no friction. Over time it surfaces patterns and gently suggests
things that help.

This repo is the **Phase 1 Web App (MVP)** from [`brief.md`](./brief.md).

---

## Status

**Phase 1 MVP — feature complete.** Built as a zero-dependency static web app
(plain HTML/CSS/JS + `localStorage`). No build step, no login, single-device.

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

### Deploy

Drop the folder on any static host (Vercel / Netlify / GitHub Pages). No build
command, output directory is the repo root.

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
├── index.html    # views + tab bar
├── styles.css    # theming + layout
├── app.js        # state, logging, history, boosters, settings
├── brief.md      # product brief (source of truth)
└── README.md     # this file
```
