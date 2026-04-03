import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseService {
  static const String _dbName = 'habit_tracker.db';
  static const int _dbVersion = 2;

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
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        frequency_type TEXT NOT NULL,
        days_of_week TEXT NOT NULL DEFAULT '[]',
        times_per_week INTEGER NOT NULL DEFAULT 0,
        check_in_type TEXT NOT NULL DEFAULT 'tap',
        quantity_unit TEXT,
        reminder_time TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
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
  }

  /// Close the underlying database. Primarily useful in tests.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
