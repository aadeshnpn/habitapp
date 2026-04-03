# Habit Tracker App — Plan

## Vision

A visually compelling Flutter Android app for personal habit tracking built around streak psychology. The app should feel premium and motivating — making users *want* to open it daily and feel genuinely rewarded when they complete their habits.

---

## Core Design Philosophy

Grounded in behavioral science research:

- **BJ Fogg's Tiny Habits**: Habits must be easy to start. The app never overwhelms. One tap = done.
- **Seinfeld's "Don't Break the Chain"**: The streak is the product. Every design decision protects streak motivation.
- **Loss aversion over guilt**: Remind users *before* they lose a streak, and offer repair *after* — but never punish them with red Xs or shame language.
- **Immediate reward**: The completion animation *is* the habit reward. It must feel genuinely satisfying.
- **Identity-level change**: The app should help users feel like "someone who does X" — not just someone who checks a box.

---

## Feature Spec

### Habits

- Users can create any habit with a name, optional description, and icon
- **Default frequency**: daily
- **Custom schedules**: specific days of week (e.g. Mon/Wed/Fri), X times per week, or custom interval
- **Default check-in**: single tap to mark complete
- **Custom check-in**: optional notes field and/or quantity tracking (e.g. "ran 2.5 miles", "drank 6 glasses")
- Habits can be archived (not deleted — history is preserved)
- Optional habit categories/tags for grouping

### Streaks

- Streak = consecutive days (or schedule intervals) with at least one check-in
- **Grace period**: one missed day does not immediately break the streak — it enters a "at risk" state
- **Streak notifications**:
  - "Streak at risk" alert sent 2–3 hours before midnight if habit not yet completed
  - If day is missed, a "Repair your streak" prompt is sent the next morning — user must consciously choose to repair, it is never automatic
- Streak repair costs a "streak freeze token" (earned through consistency milestones)
- Always display **current streak** and **best streak** side by side
- When current streak = best streak: celebrate with a "New personal best!" banner

### Home Screen

- **Default view**: Card list
  - Each habit is a card showing: name, icon, current streak (with fire/flame), and a completion button
  - Completed cards visually shift (muted, checkmark, streak increments with animation)
  - Cards reorder: incomplete habits float to top, completed sink to bottom
- **Alternate views** (user-selectable in settings):
  - **Icon grid**: large icons in a grid (like Streaks app), tap to complete, color fills on completion
  - **Progress rings**: Apple Fitness-style circular rings, one per habit
- A simple "X / Y done today" count at the top of the home screen
- When all habits are complete: the home screen transforms into a full "all done" celebratory state

### Streaks & Stats Detail (per habit)

- Calendar heatmap (last 90 days) — completed days filled with theme color, missed days empty (no red X)
- Current streak / best streak
- Total completions (all time)
- Completion rate (last 30 days, shown as %)
- Day-of-week breakdown ("You complete this 90% on weekdays")
- Check-in history log (with notes/quantities if applicable)

### Global Stats Screen

- Overall completion rate (all habits, last 30 days)
- Longest active streak across all habits
- "Insight" cards (e.g. "You've never missed a Monday", "3 days away from your longest streak ever")

### Notifications

- **Streak at risk**: sent 2–3 hours before midnight if habit incomplete
- **Streak repair reminder**: sent next morning after a miss — prompts user to use a freeze token
- **Milestone celebrations**: "You're on a 7-day streak!", "30 days — new personal best!"
- **Implementation intention**: during habit creation, user sets their preferred reminder time
- Notifications deep-link directly to the relevant habit
- All notification types individually toggleable

### Theming

- Supports **light and dark mode** (follows system default, overridable)
- **Three user-selectable color palettes**:
  - **Calm Greens**: nature-inspired, health/wellness feel — sage greens, soft teals
  - **Energetic Oranges**: momentum and urgency — warm oranges, amber, gold
  - **Premium Purples**: aspirational, lifestyle coach feel — deep purples, violets, gradient accents
- Streak fire icon color adapts to theme palette
- Completion animations use palette accent colors

### Data & Sync

- **Primary storage**: local SQLite database (works fully offline, no account required)
- **Optional sync**: periodic backup/sync to Firebase Firestore
  - User must explicitly enable sync and sign in (Google Auth)
  - Sync is manual-trigger or scheduled (daily background sync)
  - Conflict resolution: local data wins (device is source of truth)
- All data stays functional without sync enabled

---

## Technical Stack

| Concern | Choice |
|---|---|
| Framework | Flutter (Android target, with iOS-ready structure) |
| Language | Dart |
| Local DB | SQLite via `sqflite` package |
| Cloud sync | Firebase Firestore + Firebase Auth (Google Sign-In) |
| State management | Riverpod |
| Notifications | `flutter_local_notifications` |
| Navigation | `go_router` |
| Animations | Flutter built-in (`AnimationController`) + `lottie` for milestone moments |

---

## Screen Map

```
App
├── Onboarding (first launch only)
│   ├── Welcome screen
│   ├── Pick first habit (name + icon)
│   ├── Set reminder time
│   └── First completion → celebration
│
├── Home (habit list / grid / rings)
│   ├── Tap habit → check-in (with optional note/quantity)
│   └── Long press habit → quick actions (edit, archive, view stats)
│
├── Habit Detail
│   ├── Calendar heatmap
│   ├── Streak stats
│   └── Check-in history
│
├── Add / Edit Habit
│   ├── Name, icon, color
│   ├── Frequency (daily / custom)
│   ├── Check-in type (tap / note / quantity)
│   └── Reminder time
│
├── Stats (global)
│   └── Insight cards + aggregate metrics
│
└── Settings
    ├── Theme (light/dark + palette)
    ├── Home screen layout (card / grid / rings)
    ├── Notification preferences
    └── Firebase sync (enable/configure)
```

---

## Onboarding Flow

Designed to deliver **first successful completion during onboarding**:

1. Welcome screen — "Build habits that stick"
2. Ask: "What's one habit you want to build?" → name + icon picker
3. Ask: "When do you want a reminder?" → time picker
4. Brief explanation of how streaks work (one screen, skippable)
5. "Start your streak right now" → immediate check-in prompt
6. **First completion animation fires** — confetti, streak = 1
7. Request notification permission *after* first completion (user is motivated)
8. Enter home screen with streak already started

---

## Celebration & Animation Plan

| Moment | Animation |
|---|---|
| Single habit completed | Ring fill / card flip + haptic + soft chime |
| All habits done today | Full-screen glow + particle burst |
| 7-day milestone | Confetti + "One week strong!" banner |
| 30-day milestone | Full-screen animation + badge unlock |
| New personal best | Gold shimmer banner: "New personal best!" |
| Streak repair used | Warm pulse animation + "Back on track" |

---

## Streak Freeze Token System

- Earned at milestones: 7 days = 1 token, 30 days = 2 tokens, 60 days = 3 tokens
- Tokens displayed as a small count on the home screen
- When a streak is missed and user gets the repair notification, they tap "Repair" → token consumed → streak restored
- Max 3 tokens held at any time (prevents stockpiling and removes urgency)

---

## Open Questions / Future Scope

- **Widget**: home screen Android widget showing today's habits
- **Wear OS**: glanceable streak status + quick check-in from watch
- **Social sharing**: "I hit 30 days!" shareable card (image export)
- **Habit templates**: curated starter habits (Morning routine, Fitness, Sleep)
- **iOS build**: Flutter makes this straightforward once Android is stable
