# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter Android habit tracking app (`habit_tracker`). Tracks daily habits and streaks with visual reinforcement. Personal-use app, no backend required (local SQLite, optional Firebase sync not yet implemented).

## Commands

Flutter SDK is at `/home/aadeshnpn/Downloads/flutter/bin/flutter`. Add to PATH or prefix commands:
```bash
export PATH="$PATH:/home/aadeshnpn/Downloads/flutter/bin"
```

```bash
# Install dependencies
flutter pub get

# Run on connected device / emulator
flutter run

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Run all tests
flutter test

# Run a single test file
flutter test test/streak_calculator_test.dart

# Lint
flutter analyze

# Code generation (Riverpod generators, if used)
dart run build_runner build --delete-conflicting-outputs
```

> Flutter SDK: `/home/aadeshnpn/Downloads/flutter/bin/flutter`

## Architecture

### Folder structure
```
lib/
  main.dart               — ProviderScope + HabitTrackerApp
  app.dart                — MaterialApp.router, watches themeProvider + routerProvider
  config/
    routes.dart           — GoRouter + AppRoutes constants, onboarding redirect
    providers.dart        — (spare global providers)
  core/
    database/             — DatabaseService (sqflite singleton, schema v1)
    notifications/        — NotificationService, NotificationScheduler, providers
    constants/, errors/, utils/
  features/
    habits/               — Habit CRUD (model, DAO, repository, screens, providers)
    checkin/              — CheckIn recording (model, DAO, repository)
    streaks/              — Streak state machine (model, DAO, calculator, service)
    stats/                — StatsService, insight generation, StatsScreen
    onboarding/           — 5-page PageView flow
    settings/             — SettingsScreen, palette picker, theme mode selector
  shared/
    theme/                — AppPalette, AppColors, AppTheme, ThemeNotifier
    widgets/              — Reusable UI components
```

### State management (Riverpod)
All state flows through Riverpod providers. The dependency chain is:

```
databaseServiceProvider (DatabaseService singleton)
  └── habitDaoProvider / checkInDaoProvider / streakDaoProvider
        └── habitRepositoryProvider / checkInRepositoryProvider
              └── activeHabitsProvider (FutureProvider<List<Habit>>)
                    └── consumed by screens
```

Key providers to know:
- `activeHabitsProvider` — list of non-archived habits; invalidate after any CRUD
- `themeProvider` — `AsyncNotifier<ThemeState>`; persists palette + ThemeMode to SharedPreferences
- `layoutPreferenceProvider` — `AsyncNotifier<HomeLayout>`; persists home screen layout
- `routerProvider` — `GoRouter` instance (must be a Provider, not a global, because it lives in Riverpod)
- `notificationSchedulerProvider` — call `onCheckInCompleted()` after every check-in

### Data layer
- **SQLite** via `sqflite`, accessed through `DatabaseService.instance` (singleton).
- Tables: `habits`, `check_ins`, `streak_data`, `app_settings`.
- Dates stored as ISO 8601 strings. Lists (e.g. `daysOfWeek`) stored as JSON strings.
- DAOs handle raw SQL; Repositories add business logic and call DAOs.
- Schema migrations go in `DatabaseService._onUpgrade`. Bump `_dbVersion` when adding columns.

### Streak engine
`StreakCalculator` (`lib/features/streaks/domain/streak_calculator.dart`) is pure Dart — no Flutter, no async, no DB. All streak logic lives here and is fully unit-tested.

State machine: `active → atRisk (grace period) → broken`. Repair via freeze tokens (capped at 3, earned at 7/30/60-day milestones). Call `StreakCalculator.evaluateState()` on app open to transition stale streaks.

`StreakService` wraps the calculator with persistence (reads/writes `StreakDao`).

### Theming
Three palettes: `AppPalette.calmGreen`, `energeticOrange`, `premiumPurple`. Each supports light and dark mode via `AppTheme.buildTheme(palette:, brightness:)`. The active palette + ThemeMode are persisted to SharedPreferences by `ThemeNotifier` and read at startup — never hardcode theme colors; always use `Theme.of(context).colorScheme` or `AppPaletteExtension` getters.

### Navigation
`go_router` with named routes defined in `AppRoutes`. The router has an async `redirect` that gates first-time users to `/onboarding`. Navigate with `context.go('/habit/add')` or `context.goNamed('addHabit')`. The `routerProvider` must be watched in `app.dart` (not constructed inline) so Riverpod manages its lifecycle.

### Notifications
`NotificationService` (singleton) schedules via `flutter_local_notifications`. Notification ID ranges prevent collisions: daily=1000+index, at-risk=2000+index, repair=3000+index, milestone=4000+index. Always call `NotificationScheduler.onCheckInCompleted()` after recording a check-in so at-risk alerts are cancelled and milestones are detected.

### Onboarding
Controlled by `SharedPreferences` key `onboarding_complete`. The router's `redirect` checks this on every navigation. Mark complete with `markOnboardingComplete()` from `onboarding_provider.dart`. The flow ends with the user's first check-in during onboarding — `CelebrationOverlay` fires before navigating to `/home`.

## Git workflow

Branch from `develop`, not `main`. See `CONTRIBUTING.md` for full branching rules.

```
main      ← stable
develop   ← integration (default base for all feature branches)
feature/HABIT-{ticket}-{description}
```

Commit format: `feat(HABIT-XXX): description` — types: `feat`, `fix`, `test`, `refactor`, `chore`.

Remaining tickets are tracked in `TICKETS.md`. Outstanding epics: EPIC 7 (check-in flow polish), EPIC 12 (Firebase sync).
