# Habit Tracker

Flutter habit tracking app (`habit_tracker`) for daily habits, check-ins, and streaks. Local SQLite persistence; optional Firebase sync, health sync, reminders, and mindfulness bell.

## Stack

- Flutter / Dart, Riverpod, go_router
- SQLite (`sqflite`; web uses `sqflite_common_ffi_web`)
- flutter_local_notifications, Firebase Auth/Firestore (optional)

## Features (already on `develop`)

- Add / edit / archive habits
- Check in today (tap, note, or quantity)
- Streak engine with grace period + freeze tokens
- Home layouts: card list, icon grid, progress rings
- Onboarding, labels, stats, settings, reminders, mindfulness bell

## Toolchain (this machine)

A project-local Flutter SDK lives under `.toolchain/`:

```bash
export PATH="$PWD/.toolchain/flutter/bin:$PATH"
```

## Run

```bash
export PATH="$PWD/.toolchain/flutter/bin:$PATH"
flutter pub get

# Web (debug server — good for quick UI checks)
flutter run -d web-server --web-port=43123 --web-hostname=127.0.0.1
# then open http://127.0.0.1:43123

# Chrome
flutter run -d chrome --web-port=43123

# Linux desktop
flutter run -d linux

# Android (device/emulator + Android SDK under .toolchain/android-sdk)
flutter run -d android
```

## Test / analyze

```bash
export PATH="$PWD/.toolchain/flutter/bin:$PATH"
flutter test
flutter analyze
```

## Docs

- Architecture & commands: [CLAUDE.md](CLAUDE.md)
- Tickets / epics: [TICKETS.md](TICKETS.md)
- Screen map: [docs/APP_SCREENS.md](docs/APP_SCREENS.md)
- Branching: [CONTRIBUTING.md](CONTRIBUTING.md)
