# Habit Tracker — Bug Hunt & Test Plan

## Scope
Multi-agent exploratory testing of the running web app (http://localhost:8081) and codebase.
5 agents ran in parallel across: streak engine, data layer, navigation, UI layout, Riverpod state.

## App State
- Web server: Python SPA server on port 8081 (`/tmp/serve_web.py`)
- Build: `flutter build web --release` (last built after all fixes applied)
- `flutter analyze`: ✅ 0 errors, 0 warnings

---

## Consolidated Fix Log

All bugs fixed in this session. `flutter analyze` clean. `flutter build web` succeeds.

| # | Agent | File | Line(s) | Bug | Severity | Fix Applied |
|---|-------|------|---------|-----|----------|-------------|
| 1 | A | `streak_calculator.dart` | 252 | Clock skew (negative daysDiff) breaks streak | HIGH | Guard `if (daysDiff < 0) return current` |
| 2 | A | `streak_model.dart` | 68,81 | Dates stored in local time, not UTC | MEDIUM | `toUtc().toIso8601String()` + `.toLocal()` on parse |
| 3 | B | `habit_model.dart` | 90 | `jsonDecode(daysOfWeek)` crashes on malformed JSON | MEDIUM | Wrapped in try-catch with `[]` fallback |
| 4 | B | `database_service.dart` | — | No indexes on `habit_id` / `timestamp` columns | HIGH (perf) | Added 4 indexes in `_createIndexes()`, bumped `_dbVersion` to 3 |
| 5 | C | `routes.dart` | 33 | `SharedPreferences` in redirect not caught — crash on failure | HIGH | Wrapped in try-catch, returns null on error |
| 6 | C | `habit_detail_screen.dart` | 97 | `context.pop()` without `canPop()` check after archive | LOW | `canPop() ? pop() : go('/home')` |
| 7 | D | `label_card.dart` | 69 | Label name text missing `maxLines`/`overflow` | HIGH | `maxLines: 1, overflow: TextOverflow.ellipsis` |
| 8 | D | `checkin_bottom_sheet.dart` | 172 | Habit name missing `maxLines`/`overflow` | MEDIUM | `maxLines: 2, overflow: TextOverflow.ellipsis` |
| 9 | D | `stats_screen.dart` | 371 | Insight card subtitle missing `maxLines`/`overflow` | MEDIUM | `maxLines: 3, overflow: TextOverflow.ellipsis` |
| 10 | D | `frequency_selector.dart` | 153 | "Times per week:" label not constrained in Row | MEDIUM | Wrapped in `Flexible` with `overflow: ellipsis` |
| 11 | E | `add_habit_screen.dart` | 123 | Missing label-family provider invalidations on create | HIGH | `ref.invalidate(labelStreakProvider/completionMap/habitIds)` |
| 12 | E | `edit_habit_screen.dart` | 167 | Missing label-family provider invalidations on edit | HIGH | Same as #11 |
| 13 | E | `onboarding_screen.dart` | 119 | `markOnboardingComplete()` not in try-catch — user stuck | MEDIUM | Wrapped in try-catch, navigate regardless |
| 14 | — | Various | — | Unused imports / variables (6 warnings) | LOW | All removed |

## Known Issues (Not Fixed — Low Risk / Large Refactor)
- **Non-atomic habit creation**: `_habitDao.insert()` + `_streakDao.initForHabit()` are separate writes. Risk is minimal since `initForHabit` handles lazy init.
- **Non-atomic check-in + streak update**: Same pattern in `CheckInRepository`. Low crash probability; streak recalculates on next `evaluateState()`.
- **Non-idempotent milestone token award**: Double-calling `checkMilestoneTokenEarn` on same streak value awards 2 tokens. Requires adding milestone tracking to `StreakData` model — breaking schema change.
- **N+1 queries in StatsService**: Performance concern for large habit counts. Acceptable for personal-use app scale.
- **GoRouter push vs go inconsistency** (Stats → habit detail): UX difference; not a crash.
- **NavBar index magic numbers**: Tech debt; no enum — fragile to reordering.

---

## Regression Checklist (post-fix)
- [x] `flutter analyze` — zero errors, zero warnings
- [x] `flutter build web --release` — succeeds
- [ ] Home screen loads, habits visible
- [ ] Check-in records, streak increments, label providers refresh
- [ ] Stats screen — no overflow on any habit name length
- [ ] Labels tab — create label, assign habit, view detail (label providers invalidated)
- [ ] Settings — theme change persists on reload
- [ ] Onboarding — fresh user sees flow, completes it, lands on home
- [ ] Archive habit — navigates to /home if no back route

---

## Agent Coverage Summary
- **Agent A (Streak)**: 28/28 streak tests pass. Found clock skew, UTC date, and non-idempotent milestone bugs.
- **Agent B (Data Layer)**: Found missing indexes, unsafe jsonDecode, non-atomic writes, N+1 queries.
- **Agent C (Navigation)**: Found 15 issues; 2 HIGH fixed (SharedPreferences try-catch, canPop guard).
- **Agent D (UI Layout)**: Found 7 overflow risks; all HIGH/MEDIUM fixed.
- **Agent E (Riverpod)**: Found missing label-family invalidations (HIGH) and onboarding try-catch (MEDIUM); both fixed.
