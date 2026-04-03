# Habit Tracker — Tickets

Story point scale: 1 = trivial, 2 = small, 3 = medium, 5 = large, 8 = very large

---

## EPIC 1: Project Foundation
**Branch**: `feature/HABIT-001-project-foundation`
**Total SP**: 13

| Ticket | Title | SP | Notes |
|---|---|---|---|
| HABIT-001 | Initialize Flutter project with proper folder structure | 3 | lib/core, lib/features, lib/shared, lib/config |
| HABIT-002 | Configure pubspec.yaml with all dependencies | 2 | sqflite, riverpod, go_router, local_notifications, firebase, lottie |
| HABIT-003 | Set up Riverpod with ProviderScope and global providers | 3 | AppState, ThemeProvider |
| HABIT-004 | Set up go_router with all named routes | 3 | home, habit-detail, add-habit, edit-habit, stats, settings, onboarding |
| HABIT-005 | Configure Android manifest (permissions, icons, splash) | 2 | Notification permissions, Firebase config |

---

## EPIC 2: Data Layer
**Branch**: `feature/HABIT-010-data-layer`
**Total SP**: 21
**Depends on**: EPIC 1

| Ticket | Title | SP | Notes |
|---|---|---|---|
| HABIT-010 | Define SQLite schema and migration system | 3 | tables: habits, check_ins, streak_freezes, settings |
| HABIT-011 | Implement Habit model + DAO (CRUD) | 3 | id, name, icon, color, frequency, check_in_type, reminder_time, archived |
| HABIT-012 | Implement CheckIn model + DAO (CRUD) | 3 | id, habit_id, timestamp, note, quantity |
| HABIT-013 | Implement Streak model + calculation engine | 5 | current streak, best streak, grace period logic, at-risk detection |
| HABIT-014 | Implement Repository layer (abstraction over DAOs) | 3 | HabitRepository, CheckInRepository, StreakRepository |
| HABIT-015 | Unit tests for streak calculation engine | 4 | edge cases: grace period, schedule gaps, freeze repair |

---

## EPIC 3: Theming System
**Branch**: `feature/HABIT-020-theming`
**Total SP**: 13
**Depends on**: EPIC 1

| Ticket | Title | SP | Notes |
|---|---|---|---|
| HABIT-020 | Define design tokens (colors, typography, spacing, radii) | 3 | AppColors, AppTextStyles, AppSpacing |
| HABIT-021 | Implement three color palettes (greens, oranges, purples) | 3 | Each palette: primary, secondary, accent, surface, streak-color |
| HABIT-022 | Implement light/dark ThemeData for each palette | 3 | 6 total ThemeData objects |
| HABIT-023 | ThemeProvider with Riverpod (palette + mode selection) | 2 | persisted to SharedPreferences |
| HABIT-024 | Theme persistence (save + reload on app start) | 2 | |

---

## EPIC 4: Core UI Components
**Branch**: `feature/HABIT-030-ui-components`
**Total SP**: 22
**Depends on**: EPIC 3

| Ticket | Title | SP | Notes |
|---|---|---|---|
| HABIT-030 | HabitCard component (name, icon, streak count, complete button) | 3 | Completed state: muted + checkmark |
| HABIT-031 | StreakCounterWidget (fire icon + number, animates on increment) | 2 | |
| HABIT-032 | CalendarHeatmapWidget (90-day grid, color intensity = streak) | 5 | No red Xs, empty = gray |
| HABIT-033 | ProgressRingWidget (circular, fills on completion, Apple Fitness style) | 3 | |
| HABIT-034 | HabitIconGridItem (icon + color fill on completion) | 2 | |
| HABIT-035 | CelebrationOverlay (confetti + haptic + sound) | 5 | Milestone-aware: scales with day count |
| HABIT-036 | EmptyStateWidget (no habits, no completions today) | 2 | |

---

## EPIC 5: Habit Management
**Branch**: `feature/HABIT-040-habit-management`
**Total SP**: 18
**Depends on**: EPIC 2, EPIC 4

| Ticket | Title | SP | Notes |
|---|---|---|---|
| HABIT-040 | Add Habit screen (name, icon, color, frequency, check-in type, reminder) | 5 | |
| HABIT-041 | Edit Habit screen (pre-filled form, save changes) | 2 | Reuse Add Habit form |
| HABIT-042 | Icon & color picker bottom sheet | 3 | Curated icon set + palette colors |
| HABIT-043 | Frequency selector (daily / days-of-week / X-per-week) | 3 | |
| HABIT-044 | Check-in type selector (tap-only / note / quantity with unit) | 3 | |
| HABIT-045 | Archive habit flow (swipe-to-archive, confirmation, history preserved) | 2 | |

---

## EPIC 6: Home Screen
**Branch**: `feature/HABIT-050-home-screen`
**Total SP**: 18
**Depends on**: EPIC 2, EPIC 4

| Ticket | Title | SP | Notes |
|---|---|---|---|
| HABIT-050 | Home screen scaffold (app bar, "X/Y done today", layout switcher) | 3 | |
| HABIT-051 | Card list layout (default, incomplete habits float to top) | 5 | |
| HABIT-052 | Icon grid layout (alternate view) | 3 | |
| HABIT-053 | Progress rings layout (alternate view) | 3 | |
| HABIT-054 | Layout switcher and persistence (user preference saved) | 2 | |
| HABIT-055 | "All habits done" full-screen celebratory state | 2 | Home screen transforms when 100% complete |

---

## EPIC 7: Check-in Flow
**Branch**: `feature/HABIT-060-checkin-flow`
**Total SP**: 13
**Depends on**: EPIC 2, EPIC 4

| Ticket | Title | SP | Notes |
|---|---|---|---|
| HABIT-060 | Simple tap check-in (mark complete, streak increments, animation fires) | 3 | |
| HABIT-061 | Note check-in bottom sheet (text field + confirm) | 3 | |
| HABIT-062 | Quantity check-in bottom sheet (numeric input + unit + confirm) | 3 | |
| HABIT-063 | Milestone detection engine (7, 14, 30, 60, 100 days) | 2 | Triggers celebration tier |
| HABIT-064 | "New personal best" detection and banner | 2 | |

---

## EPIC 8: Streak Engine & Grace Period
**Branch**: `feature/HABIT-070-streak-engine`
**Total SP**: 16
**Depends on**: EPIC 2

| Ticket | Title | SP | Notes |
|---|---|---|---|
| HABIT-070 | Grace period state machine (active → at-risk → broken → repaired) | 3 | |
| HABIT-071 | Streak at-risk UI (visual indicator on card/ring) | 2 | |
| HABIT-072 | Streak repair flow (token consumed, streak restored, confirmation) | 3 | |
| HABIT-073 | Streak freeze token earning logic (7d=1, 30d=2, 60d=3, max 3) | 3 | |
| HABIT-074 | Token balance display (home screen, settings) | 2 | |
| HABIT-075 | Best streak tracking + personal best detection | 2 | Fires banner when current = best |
| HABIT-076 | Streak stats summary (current / best / total completions / rate) | 1 | |

---

## EPIC 9: Notifications
**Branch**: `feature/HABIT-080-notifications`
**Total SP**: 18
**Depends on**: EPIC 2, EPIC 8

| Ticket | Title | SP | Notes |
|---|---|---|---|
| HABIT-080 | Set up flutter_local_notifications with Android channel config | 3 | |
| HABIT-081 | Streak-at-risk notification (2-3 hrs before midnight if incomplete) | 3 | Scheduled dynamically per habit |
| HABIT-082 | Streak repair reminder (next morning after a miss) | 3 | Deep-links to repair flow |
| HABIT-083 | Milestone celebration notification (sent after completion) | 2 | "You hit 30 days!" |
| HABIT-084 | Per-habit reminder at user-set time | 3 | Implementation intention: set during habit creation |
| HABIT-085 | Notification permission request (post first check-in) | 2 | |
| HABIT-086 | Notification deep-link routing (goes directly to habit) | 2 | |

---

## EPIC 10: Onboarding
**Branch**: `feature/HABIT-090-onboarding`
**Total SP**: 14
**Depends on**: EPIC 4, EPIC 5, EPIC 7

| Ticket | Title | SP | Notes |
|---|---|---|---|
| HABIT-090 | Welcome screen with value proposition | 2 | |
| HABIT-091 | First habit creation (name + icon, minimal form) | 3 | |
| HABIT-092 | Reminder time picker screen | 2 | |
| HABIT-093 | "How streaks work" explainer screen (skippable) | 2 | |
| HABIT-094 | First check-in + full celebration animation (streak = 1) | 3 | |
| HABIT-095 | Onboarding completion flag (never show again) + transition to home | 2 | |

---

## EPIC 11: Stats & Analytics
**Branch**: `feature/HABIT-100-stats`
**Total SP**: 16
**Depends on**: EPIC 2, EPIC 4

| Ticket | Title | SP | Notes |
|---|---|---|---|
| HABIT-100 | Habit detail screen (heatmap + streak stats + check-in history) | 5 | |
| HABIT-101 | Global stats screen (aggregate completion rate, longest active streak) | 3 | |
| HABIT-102 | Day-of-week completion breakdown (per habit) | 3 | "You complete this 90% on weekdays" |
| HABIT-103 | Insight card engine ("You've never missed a Monday", "3 days from best") | 5 | |

---

## EPIC 12: Firebase Sync
**Branch**: `feature/HABIT-110-firebase-sync`
**Total SP**: 18
**Depends on**: EPIC 2

| Ticket | Title | SP | Notes |
|---|---|---|---|
| HABIT-110 | Firebase project config + google-services.json integration | 3 | |
| HABIT-111 | Google Sign-In authentication flow | 3 | |
| HABIT-112 | Firestore data schema mirroring SQLite schema | 3 | |
| HABIT-113 | Sync service (SQLite → Firestore, local wins conflict resolution) | 5 | |
| HABIT-114 | Manual sync trigger (Settings screen button) | 2 | |
| HABIT-115 | Scheduled background sync (daily) | 2 | |

---

## EPIC 13: Settings
**Branch**: `feature/HABIT-120-settings`
**Total SP**: 9
**Depends on**: EPIC 3, EPIC 9, EPIC 12

| Ticket | Title | SP | Notes |
|---|---|---|---|
| HABIT-120 | Settings screen scaffold and navigation | 2 | |
| HABIT-121 | Theme + palette preference settings | 2 | Live preview |
| HABIT-122 | Home layout preference setting | 1 | |
| HABIT-123 | Per-notification-type toggles | 2 | |
| HABIT-124 | Firebase sync settings (enable, sign in, last sync time) | 2 | |

---

## Summary

| Epic | SP | Branch |
|---|---|---|
| EPIC 1: Project Foundation | 13 | `feature/HABIT-001-project-foundation` |
| EPIC 2: Data Layer | 21 | `feature/HABIT-010-data-layer` |
| EPIC 3: Theming System | 13 | `feature/HABIT-020-theming` |
| EPIC 4: Core UI Components | 22 | `feature/HABIT-030-ui-components` |
| EPIC 5: Habit Management | 18 | `feature/HABIT-040-habit-management` |
| EPIC 6: Home Screen | 18 | `feature/HABIT-050-home-screen` |
| EPIC 7: Check-in Flow | 13 | `feature/HABIT-060-checkin-flow` |
| EPIC 8: Streak Engine | 16 | `feature/HABIT-070-streak-engine` |
| EPIC 9: Notifications | 18 | `feature/HABIT-080-notifications` |
| EPIC 10: Onboarding | 14 | `feature/HABIT-090-onboarding` |
| EPIC 11: Stats & Analytics | 16 | `feature/HABIT-100-stats` |
| EPIC 12: Firebase Sync | 18 | `feature/HABIT-110-firebase-sync` |
| EPIC 13: Settings | 9 | `feature/HABIT-120-settings` |
| **TOTAL** | **209 SP** | |

---

## Dependency Graph

```
EPIC 1 (Foundation)
├── EPIC 2 (Data Layer)
│   ├── EPIC 8 (Streak Engine)
│   │   └── EPIC 9 (Notifications)
│   ├── EPIC 11 (Stats)
│   └── EPIC 12 (Firebase Sync)
├── EPIC 3 (Theming)
│   ├── EPIC 4 (UI Components)
│   │   ├── EPIC 5 (Habit Management)
│   │   │   └── EPIC 10 (Onboarding)
│   │   ├── EPIC 6 (Home Screen)
│   │   └── EPIC 7 (Check-in Flow)
│   └── EPIC 13 (Settings) ← also needs EPIC 9, 12
└── (all epics depend on EPIC 1)
```

## Parallel Workstreams (Post-Foundation)

Once EPIC 1 is merged to `develop`:

| Workstream | Epics | Sequence |
|---|---|---|
| **A — Data** | 2 → 8 → 9 | Sequential within stream |
| **B — Theme & UI** | 3 → 4 → 6 | Sequential within stream |
| **C — Features** | 5 → 7 → 10 | Needs A + B done first |
| **D — Stats** | 11 | Needs A done |
| **E — Sync** | 12 → 13 | Needs A done |
