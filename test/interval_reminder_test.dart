import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

import 'package:habit_tracker/core/database/database_service.dart';
import 'package:habit_tracker/features/reminders/data/interval_reminder_dao.dart';
import 'package:habit_tracker/features/reminders/data/interval_reminder_model.dart';
import 'package:habit_tracker/features/reminders/domain/interval_reminder_repository.dart';
import 'package:habit_tracker/features/streaks/data/streak_dao.dart';

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

void main() {
  late IntervalReminderDao dao;
  late StreakDao streakDao;
  late IntervalReminderRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = _dbFactory;
  });

  setUp(() async {
    final db = await DatabaseService.instance.database;
    await db.execute('PRAGMA foreign_keys = ON');

    final dbService = DatabaseService.instance;
    dao = IntervalReminderDao(dbService);
    streakDao = StreakDao(dbService);
    repository = IntervalReminderRepository(dao, streakDao);
  });

  test('Creating an interval reminder without linked habit should not fail with FK constraint', () async {
    final params = CreateIntervalReminderParams(
      name: 'Drink Water',
      icon: '💧',
      color: 0xFF0277BD,
      category: ReminderCategory.hydration,
      intervalMinutes: 120,
      windowStart: '08:00',
      windowEnd: '20:00',
      targetCount: 4,
    );

    final reminder = await repository.createReminder(params);
    expect(reminder.id, isNotEmpty);
    expect(reminder.name, equals('Drink Water'));

    final activeReminders = await repository.getActiveReminders();
    expect(activeReminders.any((r) => r.id == reminder.id), isTrue);
  });

  test('Logging check-ins updates today progress and dynamic streak correctly', () async {
    final reminder = await repository.createReminder(
      CreateIntervalReminderParams(
        name: 'Take Medication',
        icon: '💊',
        color: 0xFF6A1B9A,
        category: ReminderCategory.medication,
        intervalMinutes: 240,
        windowStart: '08:00',
        windowEnd: '20:00',
        targetCount: 2,
      ),
    );

    expect(await repository.getTodayProgress(reminder.id), equals(0));

    await repository.logCheckIn(reminder.id, note: 'Morning dose');
    expect(await repository.getTodayProgress(reminder.id), equals(1));

    await repository.logCheckIn(reminder.id, note: 'Evening dose');
    expect(await repository.getTodayProgress(reminder.id), equals(2));

    final streak = await repository.getStreak(reminder.id);
    expect(streak, isNotNull);
    expect(streak!.currentStreak, equals(1));
  });

  test('Deleting a reminder cascades check-in logs properly', () async {
    final reminder = await repository.createReminder(
      CreateIntervalReminderParams(
        name: 'Hourly Stretch',
        icon: '🤸',
        color: 0xFFE65100,
        category: ReminderCategory.movement,
        intervalMinutes: 60,
        windowStart: '09:00',
        windowEnd: '17:00',
      ),
    );

    await repository.logCheckIn(reminder.id);
    expect(await repository.getTodayProgress(reminder.id), equals(1));

    await repository.deleteReminder(reminder.id);
    final active = await repository.getActiveReminders();
    expect(active.any((r) => r.id == reminder.id), isFalse);
  });
}
