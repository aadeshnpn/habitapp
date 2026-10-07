// sqlite_sync_test.dart
//
// Test-Driven Development for three SQLite bugs found in the sync path:
//
// BUG 1 — Duplicate activity insert crash
//   GarminAiSyncService.syncWorkoutsWithAi() calls db.insert() on
//   processed_activities WITHOUT a ConflictAlgorithm. When the same workout
//   is encountered on a second sync run (e.g. background + manual overlap),
//   SQLite throws "UNIQUE constraint failed: processed_activities.activity_id".
//   Fix: use ConflictAlgorithm.ignore so second-insert is a no-op.
//
// BUG 2 — Missing streak row causes silent data loss
//   CheckInRepository.recordCheckIn() checks for an existing streak row and
//   only updates it if it exists. If the row was never created (e.g. the habit
//   was synced from Firestore without an accompanying streak_data row), the
//   streak counter is never incremented — no error, just lost data.
//   Fix: auto-init (upsert) a zero-row when none exists before applying the
//   check-in delta.
//
// BUG 3 — v5→v6 upgrade adds columns that already exist
//   The v6 upgrade block tries ALTER TABLE processed_activities ADD COLUMN for
//   activity_title and note. Those columns were already part of the v5 CREATE
//   TABLE. A user upgrading from v4 directly (or schema v5 was applied) gets
//   a SQLite error. The silent try/catch hides it but the pattern is fragile.
//   Fix: guard each ALTER with a PRAGMA table_info check first.

import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

// ---------------------------------------------------------------------------
// Minimal in-process DatabaseService backed by sqflite_common_ffi
// (avoids needing a real device / emulator).
//
// On Linux the system SQLite library is versioned (libsqlite3.so.0) rather
// than the bare libsqlite3.so that sqlite3 looks for by default. We use
// createDatabaseFactoryFfi with a custom ffiInit so tests run on Ubuntu
// without needing the libsqlite3-dev package.
// ---------------------------------------------------------------------------

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
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE habits (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icon TEXT NOT NULL,
            color INTEGER NOT NULL,
            frequency_type TEXT NOT NULL,
            days_of_week TEXT NOT NULL DEFAULT "[]",
            times_per_week INTEGER NOT NULL DEFAULT 0,
            check_in_type TEXT NOT NULL DEFAULT "tap",
            quantity_unit TEXT,
            reminder_time TEXT,
            is_archived INTEGER NOT NULL DEFAULT 0,
            health_metric_type TEXT NOT NULL DEFAULT "none",
            health_target_value REAL NOT NULL DEFAULT 0.0,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE check_ins (
            id TEXT PRIMARY KEY,
            habit_id TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            note TEXT,
            quantity REAL,
            FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE streak_data (
            habit_id TEXT PRIMARY KEY,
            current_streak INTEGER NOT NULL DEFAULT 0,
            best_streak INTEGER NOT NULL DEFAULT 0,
            total_check_ins INTEGER NOT NULL DEFAULT 0,
            state TEXT NOT NULL DEFAULT "active",
            last_check_in TEXT,
            freeze_tokens INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
          )
        ''');
        // v5+ schema for processed_activities (already has activity_title + note)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS processed_activities (
            activity_id TEXT PRIMARY KEY,
            habit_id TEXT NOT NULL,
            activity_title TEXT NOT NULL DEFAULT "",
            confidence TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT "",
            processed_at TEXT NOT NULL
          )
        ''');
      },
    ),
  );
}

/// Insert a minimal habit row so FK constraints pass.
Future<void> _insertHabit(Database db, String id) async {
  await db.insert('habits', {
    'id': id,
    'name': 'Test Habit',
    'icon': '🏃',
    'color': 0xFF4CAF50,
    'frequency_type': 'daily',
    'days_of_week': '[]',
    'times_per_week': 0,
    'check_in_type': 'tap',
    'is_archived': 0,
    'health_metric_type': 'none',
    'health_target_value': 0.0,
    'created_at': DateTime.now().toIso8601String(),
  });
}

// ---------------------------------------------------------------------------
// BUG 1 — Duplicate activity insert
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Group 1 — processed_activities: duplicate insert must not throw
  // -------------------------------------------------------------------------
  group('BUG 1 — processed_activities duplicate insert', () {
    late Database db;

    setUp(() async {
      db = await _openDb();
      await _insertHabit(db, 'h1');
    });

    tearDown(() async => db.close());

    /// Captures the BROKEN behaviour: raw insert without a conflict algorithm
    /// throws on duplicate primary keys.
    test('raw insert throws on duplicate activity_id (reproduces the bug)', () async {
      final row = {
        'activity_id': 'act-001',
        'habit_id': 'h1',
        'activity_title': 'Morning Run',
        'confidence': 'high',
        'note': 'Auto-logged',
        'processed_at': DateTime.now().toIso8601String(),
      };

      await db.insert('processed_activities', row);

      // Second insert of the same activity_id — this is the bug scenario
      // (overlap of background + manual sync). Without ConflictAlgorithm.ignore
      // this throws.
      expect(
        () => db.insert('processed_activities', row),
        throwsA(isA<DatabaseException>()),
        reason: 'Without ConflictAlgorithm.ignore, duplicate PKs throw',
      );
    });

    /// Verifies the FIX: using ConflictAlgorithm.ignore makes the
    /// second insert a silent no-op.
    test('insert with ConflictAlgorithm.ignore is idempotent (the fix)', () async {
      const row = {
        'activity_id': 'act-001',
        'habit_id': 'h1',
        'activity_title': 'Morning Run',
        'confidence': 'high',
        'note': 'Auto-logged',
        'processed_at': '2026-07-26T10:00:00.000Z',
      };

      // First insert — succeeds normally.
      await db.insert(
        'processed_activities',
        row,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // Second insert of same row — must NOT throw.
      await expectLater(
        db.insert(
          'processed_activities',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        ),
        completes,
      );

      // Only one row exists.
      final rows = await db.query('processed_activities');
      expect(rows.length, 1, reason: 'Idempotent insert: only one row should exist');
    });

    test('two different activity_ids are both stored correctly', () async {
      final now = DateTime.now().toIso8601String();
      await db.insert('processed_activities', {
        'activity_id': 'act-001',
        'habit_id': 'h1',
        'activity_title': 'Morning Run',
        'confidence': 'high',
        'note': '',
        'processed_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await db.insert('processed_activities', {
        'activity_id': 'act-002',
        'habit_id': 'h1',
        'activity_title': 'Evening Walk',
        'confidence': 'medium',
        'note': '',
        'processed_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      final rows = await db.query('processed_activities');
      expect(rows.length, 2);
    });
  });

  // -------------------------------------------------------------------------
  // Group 2 — streak_data: missing row causes silent data loss
  // -------------------------------------------------------------------------
  group('BUG 2 — streak row missing causes silent data loss on check-in', () {
    late Database db;

    setUp(() async {
      db = await _openDb();
      await _insertHabit(db, 'h1');
    });

    tearDown(() async => db.close());

    /// Reproduces the bug: if a habit has no streak_data row, the current
    /// CheckInRepository skips the streak update (no row → no update).
    test('streak row is absent after habit insert without explicit init (bug reproducer)', () async {
      final rows = await db.query('streak_data', where: 'habit_id = ?', whereArgs: ['h1']);
      expect(rows.isEmpty, isTrue, reason: 'streak_data row is NOT auto-created on habit insert');
    });

    /// Verifies the FIX: auto-init the streak row (upsert StreakData.initial)
    /// before applying the check-in delta when no row exists.
    test('upsert initial streak row then apply check-in creates correct data (the fix)', () async {
      // Simulate the fixed recordCheckIn logic:
      // 1. Try to load existing streak row.
      var rows = await db.query('streak_data', where: 'habit_id = ?', whereArgs: ['h1']);
      // 2. If missing, auto-init.
      if (rows.isEmpty) {
        await db.insert('streak_data', {
          'habit_id': 'h1',
          'current_streak': 0,
          'best_streak': 0,
          'total_check_ins': 0,
          'state': 'active',
          'last_check_in': null,
          'freeze_tokens': 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        rows = await db.query('streak_data', where: 'habit_id = ?', whereArgs: ['h1']);
      }

      expect(rows.length, 1, reason: 'After auto-init, exactly one streak row should exist');

      // 3. Apply the check-in delta (first ever check-in → streak becomes 1).
      final existing = rows.first;
      final newTotal = (existing['total_check_ins'] as int) + 1;
      await db.update(
        'streak_data',
        {
          'current_streak': 1,
          'best_streak': 1,
          'total_check_ins': newTotal,
          'last_check_in': DateTime.now().toIso8601String(),
        },
        where: 'habit_id = ?',
        whereArgs: ['h1'],
      );

      final updated = (await db.query('streak_data', where: 'habit_id = ?', whereArgs: ['h1'])).first;
      expect(updated['current_streak'], 1);
      expect(updated['best_streak'], 1);
      expect(updated['total_check_ins'], 1);
    });

    test('two consecutive day check-ins produce streak = 2 with auto-init', () async {
      // Day 1 check-in
      await db.insert('streak_data', {
        'habit_id': 'h1',
        'current_streak': 1,
        'best_streak': 1,
        'total_check_ins': 1,
        'state': 'active',
        'last_check_in': DateTime(2026, 7, 25).toIso8601String(),
        'freeze_tokens': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Day 2 check-in (consecutive)
      final rows = await db.query('streak_data', where: 'habit_id = ?', whereArgs: ['h1']);
      final existing = rows.first;
      final lastCheckIn = DateTime.parse(existing['last_check_in'] as String);
      final now = DateTime(2026, 7, 26);
      final diff = now.difference(DateTime(lastCheckIn.year, lastCheckIn.month, lastCheckIn.day)).inDays;
      expect(diff, 1, reason: 'These are consecutive days');

      final newStreak = (existing['current_streak'] as int) + 1;
      await db.update('streak_data', {
        'current_streak': newStreak,
        'best_streak': newStreak > (existing['best_streak'] as int) ? newStreak : existing['best_streak'],
        'total_check_ins': (existing['total_check_ins'] as int) + 1,
        'last_check_in': now.toIso8601String(),
      }, where: 'habit_id = ?', whereArgs: ['h1']);

      final updated = (await db.query('streak_data', where: 'habit_id = ?', whereArgs: ['h1'])).first;
      expect(updated['current_streak'], 2);
      expect(updated['best_streak'], 2);
    });

    test('non-consecutive check-in resets streak to 1', () async {
      // Existing streak of 5, last check-in 3 days ago
      await db.insert('streak_data', {
        'habit_id': 'h1',
        'current_streak': 5,
        'best_streak': 5,
        'total_check_ins': 10,
        'state': 'active',
        'last_check_in': DateTime(2026, 7, 23).toIso8601String(),
        'freeze_tokens': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final rows = await db.query('streak_data', where: 'habit_id = ?', whereArgs: ['h1']);
      final existing = rows.first;
      final lastCheckIn = DateTime.parse(existing['last_check_in'] as String);
      final now = DateTime(2026, 7, 26);
      final diff = now.difference(DateTime(lastCheckIn.year, lastCheckIn.month, lastCheckIn.day)).inDays;
      expect(diff, greaterThan(1), reason: 'Gap > 1 day should reset streak');

      // Gap → streak resets to 1
      await db.update('streak_data', {
        'current_streak': 1,
        'best_streak': existing['best_streak'], // best is preserved
        'total_check_ins': (existing['total_check_ins'] as int) + 1,
        'last_check_in': now.toIso8601String(),
      }, where: 'habit_id = ?', whereArgs: ['h1']);

      final updated = (await db.query('streak_data', where: 'habit_id = ?', whereArgs: ['h1'])).first;
      expect(updated['current_streak'], 1, reason: 'Streak resets to 1 after gap');
      expect(updated['best_streak'], 5, reason: 'Best streak is preserved');
      expect(updated['total_check_ins'], 11);
    });
  });

  // -------------------------------------------------------------------------
  // Group 3 — Schema upgrade: v6 ALTER must be a no-op if columns exist
  // -------------------------------------------------------------------------
  group('BUG 3 — v6 upgrade ALTER TABLE is no-op when columns already exist', () {
    late Database db;

    setUp(() async {
      db = await _openDb();
    });

    tearDown(() async => db.close());

    test('processed_activities schema has activity_title and note columns', () async {
      await _insertHabit(db, 'h1');
      // Insert a row using all expected columns — if columns are missing this throws.
      await expectLater(
        db.insert('processed_activities', {
          'activity_id': 'test-act',
          'habit_id': 'h1',
          'activity_title': 'Test Activity',
          'confidence': 'high',
          'note': 'Some note',
          'processed_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore),
        completes,
        reason: 'Both activity_title and note columns must exist in the schema',
      );
    });

    test('ALTER TABLE processed_activities ADD COLUMN on existing column throws '
        '(without PRAGMA guard)', () async {
      // Reproduces the fragility of the v6 migration: if run against a DB
      // where the column already exists, SQLite throws
      // "duplicate column name: activity_title".
      await expectLater(
        db.execute("ALTER TABLE processed_activities ADD COLUMN activity_title TEXT NOT NULL DEFAULT ''"),
        throwsA(isA<DatabaseException>()),
        reason: 'SQLite throws when adding a column that already exists; must be guarded',
      );
    });

    test('PRAGMA table_info guard correctly skips ALTER on existing columns', () async {
      // This is the safe pattern: check PRAGMA table_info first.
      final tableInfo = await db.rawQuery('PRAGMA table_info(processed_activities)');
      final columnNames = tableInfo.map((r) => r['name'] as String).toSet();

      final needsActivityTitle = !columnNames.contains('activity_title');
      final needsNote = !columnNames.contains('note');

      expect(needsActivityTitle, isFalse,
          reason: 'activity_title already exists; ALTER should be skipped');
      expect(needsNote, isFalse,
          reason: 'note already exists; ALTER should be skipped');

      // No ALTER is attempted — upgrade is safe with PRAGMA guard.
    });

    test('v4 to v6 migration creates processed_activities with all required columns', () async {
      // Simulate a v4 database (no processed_activities table).
      final v4db = await _dbFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, v) async {
            await db.execute('''
              CREATE TABLE habits (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                icon TEXT NOT NULL,
                color INTEGER NOT NULL,
                frequency_type TEXT NOT NULL,
                days_of_week TEXT NOT NULL DEFAULT "[]",
                times_per_week INTEGER NOT NULL DEFAULT 0,
                check_in_type TEXT NOT NULL DEFAULT "tap",
                quantity_unit TEXT,
                reminder_time TEXT,
                is_archived INTEGER NOT NULL DEFAULT 0,
                health_metric_type TEXT NOT NULL DEFAULT "none",
                health_target_value REAL NOT NULL DEFAULT 0.0,
                created_at TEXT NOT NULL
              )
            ''');
            // v4 did NOT have processed_activities yet.
          },
        ),
      );

      // Simulate v5 migration: CREATE TABLE IF NOT EXISTS processed_activities
      // (with activity_title and note already in the schema).
      await v4db.execute('''
        CREATE TABLE IF NOT EXISTS processed_activities (
          activity_id TEXT PRIMARY KEY,
          habit_id TEXT NOT NULL,
          activity_title TEXT NOT NULL DEFAULT "",
          confidence TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT "",
          processed_at TEXT NOT NULL
        )
      ''');

      // Simulate v6 migration with the PRAGMA guard (the fix).
      final tableInfo = await v4db.rawQuery('PRAGMA table_info(processed_activities)');
      final cols = tableInfo.map((r) => r['name'] as String).toSet();

      if (!cols.contains('activity_title')) {
        await v4db.execute("ALTER TABLE processed_activities ADD COLUMN activity_title TEXT NOT NULL DEFAULT ''");
      }
      if (!cols.contains('note')) {
        await v4db.execute("ALTER TABLE processed_activities ADD COLUMN note TEXT NOT NULL DEFAULT ''");
      }

      // Verify the full schema is intact.
      final finalInfo = await v4db.rawQuery('PRAGMA table_info(processed_activities)');
      final finalCols = finalInfo.map((r) => r['name'] as String).toSet();
      expect(
        finalCols,
        containsAll(['activity_id', 'habit_id', 'activity_title', 'confidence', 'note', 'processed_at']),
      );

      await v4db.close();
    });
  });
}
