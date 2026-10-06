// health_sync_sqlite_test.dart
//
// TDD for SQLite duplicate bugs that surface when health data
// (Health Connect / Garmin) is fetched and persisted to the local DB.
//
// ── BUG 4 — Multi-type id collision (one run → 4 processed_activities rows) ─
// GarminActivityFetcher builds:  'hc_${dateFrom.ms}_${type.name}'
// A 30-min run returns WORKOUT + STEPS + DISTANCE_DELTA + ACTIVE_ENERGY_BURNED,
// all with the same dateFrom → 4 distinct ids → 4 DB inserts → 4 check-ins.
// Fix: key on session window 'hc_${startMs}_${endMs}', collapse per-type ids.
//
// ── BUG 5 — STEPS buckets share dateFrom → UNIQUE constraint crash ───────────
// Health Connect batches steps into 30-min windows.  Two adjacent windows can
// share the same dateFrom millisecond value, producing identical buggy ids.
// Fix: dedup fetched list by id BEFORE DB lookup and AI classification.
//
// ── BUG 6 — check-in fires BEFORE processed_activities guard row ─────────────
// Current order: completeHabit() → db.insert('processed_activities').
// Race: two syncs both read empty processed_activities, both call completeHabit,
// then both try to insert the guard — ConflictAlgorithm.ignore stops the crash
// but TWO check-ins already landed.
// Fix: insert the guard row FIRST (ConflictAlgorithm.ignore), only call
// completeHabit if the insert returned a non-zero rowId (won the claim).

import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

// ── SQLite factory setup (Linux versioned-library workaround) ────────────────

void _linuxFfiInit() {
  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, () {
      try {
        return DynamicLibrary.open('libsqlite3.so');
      } catch (_) {
        return DynamicLibrary.open('libsqlite3.so.0');
      }
    });
  }
}

DatabaseFactory get _dbFactory =>
    createDatabaseFactoryFfi(ffiInit: _linuxFfiInit);

Future<Database> _openDb() async {
  return _dbFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 6,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE habits (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, icon TEXT NOT NULL,
            color INTEGER NOT NULL, frequency_type TEXT NOT NULL,
            days_of_week TEXT NOT NULL DEFAULT "[]",
            times_per_week INTEGER NOT NULL DEFAULT 0,
            check_in_type TEXT NOT NULL DEFAULT "tap",
            quantity_unit TEXT, reminder_time TEXT,
            is_archived INTEGER NOT NULL DEFAULT 0,
            health_metric_type TEXT NOT NULL DEFAULT "none",
            health_target_value REAL NOT NULL DEFAULT 0.0,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE check_ins (
            id TEXT PRIMARY KEY, habit_id TEXT NOT NULL,
            timestamp TEXT NOT NULL, note TEXT, quantity REAL,
            FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE processed_activities (
            activity_id  TEXT PRIMARY KEY,
            habit_id     TEXT NOT NULL,
            activity_title TEXT NOT NULL DEFAULT "",
            confidence   TEXT NOT NULL,
            note         TEXT NOT NULL DEFAULT "",
            processed_at TEXT NOT NULL
          )
        ''');
      },
    ),
  );
}

Future<void> _insertHabit(Database db, String id) async {
  await db.insert('habits', {
    'id': id, 'name': 'Running', 'icon': '🏃',
    'color': 0xFF4CAF50, 'frequency_type': 'daily',
    'days_of_week': '[]', 'times_per_week': 0,
    'check_in_type': 'tap', 'is_archived': 0,
    'health_metric_type': 'runningDistance',
    'health_target_value': 5.0,
    'created_at': DateTime.now().toIso8601String(),
  });
}

// ── Id-scheme helpers ────────────────────────────────────────────────────────

/// BUGGY: type-scoped id (current implementation in garmin_activity_fetcher.dart)
String buggyId(DateTime dateFrom, String typeName) =>
    'hc_${dateFrom.millisecondsSinceEpoch}_$typeName';

/// FIXED: session-window id (start+end, type-agnostic)
String fixedId(DateTime dateFrom, DateTime dateTo) =>
    'hc_${dateFrom.millisecondsSinceEpoch}_${dateTo.millisecondsSinceEpoch}';

// ── Claim helper (implements the BUG-6 fix pattern) ─────────────────────────

/// Atomically claim an activity. Returns true if this call was the winner.
Future<bool> _claimActivity(Database db, {
  required String activityId, required String habitId,
  required String title, required String confidence, required String note,
}) async {
  final rowId = await db.insert(
    'processed_activities',
    {
      'activity_id': activityId, 'habit_id': habitId,
      'activity_title': title, 'confidence': confidence,
      'note': note, 'processed_at': DateTime.now().toIso8601String(),
    },
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );
  return rowId != 0; // 0 == ignored (already existed)
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {

  // ── BUG 4 ─────────────────────────────────────────────────────────────────
  group('BUG 4 — multi-type id scheme produces separate ids for the same activity', () {
    final sessionStart = DateTime(2024, 7, 1, 8, 0);
    final sessionEnd   = DateTime(2024, 7, 1, 8, 30);

    test(
        'buggy scheme: WORKOUT + STEPS + DISTANCE_DELTA all get DIFFERENT ids '
        '(one run → 4 unprocessed activities — reproduces the bug)', () {
      final ids = {
        buggyId(sessionStart, 'WORKOUT'),
        buggyId(sessionStart, 'STEPS'),
        buggyId(sessionStart, 'DISTANCE_DELTA'),
        buggyId(sessionStart, 'ACTIVE_ENERGY_BURNED'),
      };
      expect(ids.length, equals(4),
          reason: 'Buggy scheme gives 4 unique ids for one 30-min run');
    });

    test(
        'fixed scheme: all types from the same session window share ONE id', () {
      final ids = {
        fixedId(sessionStart, sessionEnd), // WORKOUT
        fixedId(sessionStart, sessionEnd), // STEPS
        fixedId(sessionStart, sessionEnd), // DISTANCE_DELTA
        fixedId(sessionStart, sessionEnd), // ACTIVE_ENERGY_BURNED
      };
      expect(ids.length, equals(1),
          reason: 'Fixed scheme collapses one run to a single id');
    });

    test('fixed scheme: two different sessions on same day stay distinct', () {
      final morningId = fixedId(
          DateTime(2024, 7, 1, 8, 0), DateTime(2024, 7, 1, 8, 30));
      final eveningId = fixedId(
          DateTime(2024, 7, 1, 18, 0), DateTime(2024, 7, 1, 18, 45));
      expect(morningId, isNot(equals(eveningId)));
    });

    test('deduplication before DB insert: same-session ids collapse to one row',
        () async {
      final db = await _openDb();
      addTearDown(db.close);
      await _insertHabit(db, 'habit-1');

      // Three data-type variants of the same run → same fixed id.
      final ids = [
        fixedId(sessionStart, sessionEnd),
        fixedId(sessionStart, sessionEnd),
        fixedId(sessionStart, sessionEnd),
      ].toSet().toList(); // deduplicate

      expect(ids.length, equals(1));
      for (final id in ids) {
        await db.insert('processed_activities', {
          'activity_id': id, 'habit_id': 'habit-1',
          'activity_title': 'Morning Run', 'confidence': 'high',
          'note': '', 'processed_at': DateTime.now().toIso8601String(),
        });
      }
      final rows = await db.query('processed_activities');
      expect(rows.length, equals(1));
    });
  });

  // ── BUG 5 ─────────────────────────────────────────────────────────────────
  group('BUG 5 — STEPS buckets with identical dateFrom produce duplicate ids', () {
    test('buggy scheme: two STEPS buckets with same dateFrom collide', () {
      final ts = DateTime(2024, 7, 1, 8, 0, 0);
      final id1 = buggyId(ts, 'STEPS');
      final id2 = buggyId(ts, 'STEPS');
      expect(id1, equals(id2),
          reason: 'Same dateFrom+type → identical ids → UNIQUE constraint crash');
    });

    test('fixed scheme: STEPS buckets with different endTimes get different ids',
        () {
      final start = DateTime(2024, 7, 1, 8, 0, 0);
      final id1 = fixedId(start, DateTime(2024, 7, 1, 8, 30, 0));
      final id2 = fixedId(start, DateTime(2024, 7, 1, 8, 30, 1));
      expect(id1, isNot(equals(id2)));
    });

    test('deduplication of fetched list removes same-id entries before processing',
        () {
      const id = 'hc_1720000000000_1720001800000';
      final raw = [id, id, id]; // three duplicates from Health Connect
      expect(raw.toSet().length, equals(1),
          reason: 'Dedup collapses repeated ids');
    });

    test(
        'raw insert of duplicate id throws UNIQUE error (without ConflictAlgorithm)',
        () async {
      final db = await _openDb();
      addTearDown(db.close);
      await _insertHabit(db, 'habit-1');

      const dupId = 'hc_1720000000000_1720001800000';
      final row = {
        'activity_id': dupId, 'habit_id': 'habit-1',
        'activity_title': 'Steps', 'confidence': 'high',
        'note': '', 'processed_at': DateTime.now().toIso8601String(),
      };

      await db.insert('processed_activities', row);
      expect(
        () => db.insert('processed_activities', row),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('ConflictAlgorithm.ignore makes duplicate id insert a safe no-op',
        () async {
      final db = await _openDb();
      addTearDown(db.close);
      await _insertHabit(db, 'habit-1');

      const dupId = 'hc_1720000000000_1720001800000';
      final row = {
        'activity_id': dupId, 'habit_id': 'habit-1',
        'activity_title': 'Steps', 'confidence': 'high',
        'note': '', 'processed_at': DateTime.now().toIso8601String(),
      };

      await db.insert('processed_activities', row,
          conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('processed_activities', row,
          conflictAlgorithm: ConflictAlgorithm.ignore);

      final rows = await db.query('processed_activities');
      expect(rows.length, equals(1));
    });
  });

  // ── BUG 6 ─────────────────────────────────────────────────────────────────
  group('BUG 6 — check-in fires BEFORE processed_activities guard → double check-in', () {
    test(
        'buggy ordering: two concurrent syncs both complete check-in before guard is written',
        () async {
      final db = await _openDb();
      addTearDown(db.close);
      await _insertHabit(db, 'habit-1');

      const actId = 'hc_1720000000000_1720001800000';
      int checkInCount = 0;

      Future<void> buggySync() async {
        final processedIds = (await db.query('processed_activities',
                columns: ['activity_id']))
            .map((r) => r['activity_id'] as String)
            .toSet();

        if (!processedIds.contains(actId)) {
          // BUG: check-in happens BEFORE guard row is inserted.
          checkInCount++;
          await db.insert('check_ins', {
            'id': 'ci-$checkInCount',
            'habit_id': 'habit-1',
            'timestamp': DateTime.now().toIso8601String(),
          });
          await db.insert(
            'processed_activities',
            {
              'activity_id': actId, 'habit_id': 'habit-1',
              'activity_title': 'Run', 'confidence': 'high',
              'note': '', 'processed_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }

      // Simulate race: both reads happen before either write.
      // We replicate by deleting the guard between two calls.
      await buggySync();
      await db.delete('processed_activities'); // simulate race: guard gone
      await buggySync();

      final checkIns = await db.query('check_ins');
      expect(checkIns.length, equals(2),
          reason: 'Buggy order: two check-ins for one activity');
    });

    test(
        'fixed ordering: claim guard row first → only one check-in regardless of sync count',
        () async {
      final db = await _openDb();
      addTearDown(db.close);
      await _insertHabit(db, 'habit-1');

      const actId = 'hc_1720000000000_1720001800000';
      int checkInCount = 0;

      Future<void> fixedSync() async {
        final claimed = await _claimActivity(db,
            activityId: actId, habitId: 'habit-1',
            title: 'Run', confidence: 'high', note: '');
        if (claimed) {
          checkInCount++;
          await db.insert('check_ins', {
            'id': 'ci-$checkInCount',
            'habit_id': 'habit-1',
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      }

      await fixedSync();
      await fixedSync(); // second call: claim fails → no check-in

      expect(checkInCount, equals(1));
      expect((await db.query('check_ins')).length, equals(1));
      expect((await db.query('processed_activities')).length, equals(1));
    });

    test('_claimActivity returns true for new, false for already-processed', () async {
      final db = await _openDb();
      addTearDown(db.close);
      await _insertHabit(db, 'habit-1');

      const actId = 'hc_CLAIM_TEST';
      expect(
        await _claimActivity(db, activityId: actId, habitId: 'habit-1',
            title: 'Run', confidence: 'high', note: ''),
        isTrue,
      );
      expect(
        await _claimActivity(db, activityId: actId, habitId: 'habit-1',
            title: 'Run', confidence: 'high', note: ''),
        isFalse,
      );
    });

    test('three parallel-like syncs produce exactly one check-in', () async {
      final db = await _openDb();
      addTearDown(db.close);
      await _insertHabit(db, 'habit-1');

      const actId = 'hc_PARALLEL_ACTIVITY';
      int checkInCount = 0;

      Future<void> fixedSync() async {
        final claimed = await _claimActivity(db,
            activityId: actId, habitId: 'habit-1',
            title: 'Run', confidence: 'high', note: '');
        if (claimed) checkInCount++;
      }

      await Future.wait([fixedSync(), fixedSync(), fixedSync()]);
      expect(checkInCount, equals(1));
    });
  });
}
