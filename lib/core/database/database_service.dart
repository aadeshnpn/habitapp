import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseService {
  static const String _dbName = 'habit_tracker.db';
  static const int _dbVersion = 8;

  // Singleton
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb(p.join(await getDatabasesPath(), _dbName));
    return _db!;
  }

  Future<Database> _initDb(String path) async {
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// Enable foreign key enforcement.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        frequency_type TEXT NOT NULL,
        days_of_week TEXT NOT NULL DEFAULT '[]',
        times_per_week INTEGER NOT NULL DEFAULT 0,
        check_in_type TEXT NOT NULL DEFAULT 'tap',
        quantity_unit TEXT,
        reminder_time TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        health_metric_type TEXT NOT NULL DEFAULT 'none',
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
        state TEXT NOT NULL DEFAULT 'active',
        last_check_in TEXT,
        freeze_tokens INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_labels (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL DEFAULT '🏷️',
        color INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_label_assignments (
        habit_id TEXT NOT NULL,
        label_id TEXT NOT NULL,
        PRIMARY KEY (habit_id, label_id),
        FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE,
        FOREIGN KEY (label_id) REFERENCES habit_labels(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE label_streaks (
        label_id TEXT PRIMARY KEY,
        current_streak INTEGER NOT NULL DEFAULT 0,
        best_streak INTEGER NOT NULL DEFAULT 0,
        total_days INTEGER NOT NULL DEFAULT 0,
        state TEXT NOT NULL DEFAULT 'active',
        last_active_day TEXT,
        FOREIGN KEY (label_id) REFERENCES habit_labels(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS processed_activities (
        activity_id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        activity_title TEXT NOT NULL DEFAULT '',
        confidence TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        processed_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE interval_reminders (
        id TEXT PRIMARY KEY,
        habit_id TEXT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT '💧',
        color INTEGER NOT NULL,
        category TEXT NOT NULL DEFAULT 'hydration',
        interval_minutes INTEGER NOT NULL,
        window_start TEXT NOT NULL,
        window_end TEXT NOT NULL,
        target_count INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE interval_check_ins (
        id TEXT PRIMARY KEY,
        reminder_id TEXT NOT NULL,
        logged_at TEXT NOT NULL,
        note TEXT,
        quantity REAL,
        FOREIGN KEY (reminder_id) REFERENCES interval_reminders(id) ON DELETE CASCADE
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_check_ins_habit_id ON check_ins(habit_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_check_ins_habit_timestamp ON check_ins(habit_id, timestamp DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_label_assignments_habit ON habit_label_assignments(habit_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_label_assignments_label ON habit_label_assignments(label_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_interval_check_ins_reminder ON interval_check_ins(reminder_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_interval_check_ins_logged_at ON interval_check_ins(reminder_id, logged_at DESC)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add label tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS habit_labels (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          emoji TEXT NOT NULL DEFAULT '🏷️',
          color INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS habit_label_assignments (
          habit_id TEXT NOT NULL,
          label_id TEXT NOT NULL,
          PRIMARY KEY (habit_id, label_id),
          FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE,
          FOREIGN KEY (label_id) REFERENCES habit_labels(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS label_streaks (
          label_id TEXT PRIMARY KEY,
          current_streak INTEGER NOT NULL DEFAULT 0,
          best_streak INTEGER NOT NULL DEFAULT 0,
          total_days INTEGER NOT NULL DEFAULT 0,
          state TEXT NOT NULL DEFAULT 'active',
          last_active_day TEXT,
          FOREIGN KEY (label_id) REFERENCES habit_labels(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      await _createIndexes(db);
    }

    if (oldVersion < 4) {
      await db.execute(
          "ALTER TABLE habits ADD COLUMN health_metric_type TEXT NOT NULL DEFAULT 'none'");
      await db.execute(
          "ALTER TABLE habits ADD COLUMN health_target_value REAL NOT NULL DEFAULT 0.0");
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS processed_activities (
          activity_id TEXT PRIMARY KEY,
          habit_id TEXT NOT NULL,
          activity_title TEXT NOT NULL DEFAULT '',
          confidence TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          processed_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 6) {
      // The v5 migration created processed_activities with activity_title and
      // note already in the schema.  A user upgrading from v4 → v5 → v6
      // already has these columns; a direct v4 → v6 jump does not.
      // Guard with PRAGMA table_info so we only ALTER when the column is absent.
      final cols = (await db.rawQuery('PRAGMA table_info(processed_activities)'))
          .map((r) => r['name'] as String)
          .toSet();
      if (!cols.contains('activity_title')) {
        await db.execute(
            "ALTER TABLE processed_activities ADD COLUMN activity_title TEXT NOT NULL DEFAULT ''");
      }
      if (!cols.contains('note')) {
        await db.execute(
            "ALTER TABLE processed_activities ADD COLUMN note TEXT NOT NULL DEFAULT ''");
      }
    }

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS interval_reminders (
          id TEXT PRIMARY KEY,
          habit_id TEXT,
          name TEXT NOT NULL,
          icon TEXT NOT NULL DEFAULT '💧',
          color INTEGER NOT NULL,
          category TEXT NOT NULL DEFAULT 'hydration',
          interval_minutes INTEGER NOT NULL,
          window_start TEXT NOT NULL,
          window_end TEXT NOT NULL,
          target_count INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE SET NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS interval_check_ins (
          id TEXT PRIMARY KEY,
          reminder_id TEXT NOT NULL,
          logged_at TEXT NOT NULL,
          note TEXT,
          quantity REAL,
          FOREIGN KEY (reminder_id) REFERENCES interval_reminders(id) ON DELETE CASCADE
        )
      ''');

      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_interval_check_ins_reminder ON interval_check_ins(reminder_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_interval_check_ins_logged_at ON interval_check_ins(reminder_id, logged_at DESC)');
    }

    if (oldVersion < 8) {
      final cols = (await db.rawQuery('PRAGMA table_info(habits)'))
          .map((r) => r['name'] as String)
          .toSet();
      if (!cols.contains('description')) {
        await db.execute('ALTER TABLE habits ADD COLUMN description TEXT');
      }
    }
  }



  /// Close the underlying database. Primarily useful in tests.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
