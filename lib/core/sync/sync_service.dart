import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_service.dart';
import 'auth_service.dart';

/// Syncs local SQLite data to Firestore.
/// Local data always wins (device is source of truth).
/// Requires: Firebase initialized + user signed in.
///
/// NOTE: Replace android/app/google-services.json with real Firebase
/// project credentials before this service will work.
class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _db;
  final AuthService _auth;

  SyncService(this._db, this._auth);

  Future<SyncResult> syncAll() async {
    if (!_auth.isSignedIn) return SyncResult.notSignedIn();
    final uid = _auth.currentUser!.uid;

    try {
      await Future.wait([
        _syncHabits(uid),
        _syncCheckIns(uid),
        _syncStreaks(uid),
      ]);
      // Save last sync timestamp
      await SharedPreferences.getInstance()
          .then((p) => p.setString('last_sync', DateTime.now().toIso8601String()));
      return SyncResult.success();
    } catch (e) {
      return SyncResult.error(e.toString());
    }
  }

  Future<void> _syncHabits(String uid) async {
    final db = await _db.database;
    final rows = await db.query('habits');
    final batch = _firestore.batch();
    for (final row in rows) {
      final ref = _firestore.collection('users/$uid/habits').doc(row['id'] as String);
      batch.set(ref, row, SetOptions(merge: false)); // local wins
    }
    await batch.commit();
  }

  Future<void> _syncCheckIns(String uid) async {
    final db = await _db.database;
    final rows = await db.query('check_ins');
    // Batch writes in groups of 500 (Firestore limit)
    for (var i = 0; i < rows.length; i += 500) {
      final chunk = rows.sublist(i, i + 500 > rows.length ? rows.length : i + 500);
      final batch = _firestore.batch();
      for (final row in chunk) {
        final ref = _firestore.collection('users/$uid/checkIns').doc(row['id'] as String);
        batch.set(ref, row, SetOptions(merge: false));
      }
      await batch.commit();
    }
  }

  Future<void> _syncStreaks(String uid) async {
    final db = await _db.database;
    final rows = await db.query('streak_data');
    final batch = _firestore.batch();
    for (final row in rows) {
      final ref = _firestore.collection('users/$uid/streaks').doc(row['habit_id'] as String);
      batch.set(ref, row, SetOptions(merge: false));
    }
    await batch.commit();
  }
}

class SyncResult {
  final bool success;
  final bool notSignedIn;
  final String? error;
  final DateTime? timestamp;

  SyncResult._({
    required this.success,
    required this.notSignedIn,
    this.error,
    this.timestamp,
  });

  factory SyncResult.success() => SyncResult._(
        success: true,
        notSignedIn: false,
        timestamp: DateTime.now(),
      );

  factory SyncResult.notSignedIn() => SyncResult._(
        success: false,
        notSignedIn: true,
      );

  factory SyncResult.error(String e) => SyncResult._(
        success: false,
        notSignedIn: false,
        error: e,
      );
}
