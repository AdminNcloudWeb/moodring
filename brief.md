# Moodring — Product Brief

**Version:** 0.2 — Discovery  
**Date:** June 2026  
**Status:** Draft

-----

## Overview

Moodring is a lightweight mood tracking app built around radical simplicity. A single tap logs how you’re feeling. No forms, no friction. Over time, it surfaces patterns and gently suggests actions that actually help.

The initial release is a **web app**. The long-term target is a **native mobile app with a home screen widget** for one-tap logging without opening the app.

-----

## Problem

Most mood tracking apps are too heavy. They ask too much — long check-ins, forced journaling, clinical language. People drop off within days. The best tracker is one you actually use, and that means getting out of the way.

-----

## Core Experience

### 1. Mood Logging

- A scrollable row of emojis spanning a **broad emotional spectrum** — from crisis-level lows to peak states, plus non-valence moods like energised, anxious, or calm
- Tap one to log it — that’s the entire action
- **Multiple logs per day** are supported and encouraged; mood is not a once-a-day thing
- Each log is timestamped automatically
- Optional: a one-line text note after selecting an emoji (never required)

**Default emoji set:**

|Emoji|Label   |Category    |
|-----|--------|------------|
|😭    |Crying  |Extreme low |
|😔    |Low     |Low         |
|😟    |Anxious |Low         |
|😐    |Neutral |Mid         |
|😌    |Calm    |Mid         |
|🙂    |Okay    |Mid         |
|💪    |Healthy |Positive    |
|😊    |Good    |Positive    |
|😄    |Great   |High        |
|🤩    |Ecstatic|Extreme high|

The set covers valence (how positive/negative) and a few key non-valence states (anxious, calm, healthy/energised) that users commonly want to distinguish.

**Custom Emojis**

Users can fully personalise their emoji set:

- **Add** any emoji from the system picker with a custom label
- **Remove** any default emoji they don’t use
- **Reorder** emojis by drag-and-drop to arrange by personal meaning
- A minimum of 2 and maximum of 12 emojis can be active at once
- Custom emojis are saved to the user’s profile and persist across devices (Phase 2+)

The customisation screen lives in Settings — it doesn’t clutter the main logging view.

-----

### 2. Mood Boosters

A dedicated section for things that lift your mood. Two sources:

**a) User-defined entries**  
Custom items the user adds themselves — e.g. “go for a walk,” “call mom,” “make coffee,” “listen to my playlist.”

**b) App suggestions**  
Context-aware nudges surfaced by the app — e.g. if mood has been low for several hours, suggest a short walk or breathing exercise. Suggestions can be:

- General wellness (hydration, movement, sunlight)
- Personalised over time based on what the user has logged after good moods
- Dismissible / hideable so they never feel pushy

Users can **save a suggestion** to their personal list or dismiss it permanently.

-----

### 3. History & Patterns

- A simple timeline or calendar view showing emoji logs by time of day
- A gentle trend line — are things getting better, worse, or holding steady?
- **No score, no streak pressure** — the display is informational, not gamified
- Weekly summary (opt-in) that notes peaks, dips, and what was logged around them

-----

## Design Direction

- **Minimal and warm** — feels like a personal notebook, not a clinical dashboard
- Large, tappable emoji — the UI is essentially just the emojis and a log
- Soft background, no harsh grid lines
- System fonts or a single rounded typeface — nothing that adds weight
- Dark mode supported from day one

-----

## Technical Scope

### Phase 1 — Web App (MVP)

|Layer   |Approach                                 |
|--------|-----------------------------------------|
|Frontend|React (or plain HTML/CSS/JS for speed)   |
|Storage |`localStorage` for MVP; no login required|
|Hosting |Vercel / Netlify static deploy           |
|Auth    |None initially — single-device, anonymous|

**MVP feature set:**

- Emoji tap to log mood
- Timestamped log stored locally
- Simple log history (last 7 days)
- Mood booster list (user-editable)
- Basic suggestion cards

-----

### Phase 2 — Mobile App

|Layer    |Approach                                             |
|---------|-----------------------------------------------------|
|Framework|React Native or Flutter                              |
|Backend  |Lightweight API + user accounts (sync across devices)|
|Storage  |Cloud sync with local-first fallback                 |
|Auth     |Email magic link or Sign in with Apple/Google        |

-----

### Phase 3 — Widget

- **iOS:** WidgetKit (small widget, 1–2 emoji options + quick log)
- **Android:** App Widget with a single row of emojis
- Tapping an emoji from the widget logs directly — no app launch required
- Widget refreshes to show today’s last logged mood as context

-----

## Key User Flows

### Flow A — Quick Log

```
Open app → See emoji row → Tap emoji → Done (< 3 seconds)
```

### Flow B — Log with Note

```
Tap emoji → Optional note field appears → Type or skip → Confirm
```

### Flow C — Add a Booster

```
Tap "Boosters" → "+ Add your own" → Type item → Save
```

### Flow D — Accept a Suggestion

```
Suggestion card appears → Tap "Save to my list" → Added to Boosters
```

### Flow E — Review Week

```
Tap "History" → Emoji timeline by day → Tap any entry for detail
```

-----

## What This Is Not

- Not a journaling app — no pressure to write anything
- Not a mental health platform — no clinical framing, no crisis tools (out of scope for v1)
- Not gamified — no streaks, badges, or points
- Not a social app — all data is private by default

-----

## Open Questions

1. **Custom emoji order** — should the row always sort by valence (low → high), or let users arrange freely in any order?
1. **Booster suggestions** — rule-based triggers or lightweight ML over time?
1. **Widget tap-to-log** — does tapping an emoji in the widget need confirmation, or is it instant? (Widget can only show ~4–5 emojis max due to space)
1. **Data export** — do users need a CSV or JSON export of their history?
1. **Notifications** — optional check-in reminders? If so, how often and how smart?
1. **Offline-first** — for mobile, how long should logs queue locally before requiring sync?

-----

## Success Metrics (Phase 1)

|Metric                      |Target                              |
|----------------------------|------------------------------------|
|Time to first log           |< 10 seconds from app open          |
|Logs per active user per day|≥ 2                                 |
|7-day retention             |> 40%                               |
|Booster section engagement  |> 30% of users add at least one item|

-----

*This is a living document. Update as decisions are made.*
