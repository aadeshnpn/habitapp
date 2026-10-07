import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());


class HealthService {
  late final Health? _health;

  HealthService() {
    if (!kIsWeb) {
      _health = Health();
      _health!.configure();
    } else {
      _health = null;
    }
  }

  /// Data types that are supported on BOTH iOS and Android Health Connect.
  /// MINDFULNESS and DISTANCE_WALKING_RUNNING are iOS-only and will error on Android.
  /// Use DISTANCE_DELTA for distance on Android and WORKOUT for exercise sessions.
  static final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.WORKOUT,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_SESSION,
  ];


  /// Request read permissions for Health Connect (Android).
  Future<bool> requestPermissions() async {
    if (kIsWeb || _health == null) return false;

    // Check Health Connect SDK availability
    try {
      final status = await _health!.getHealthConnectSdkStatus();
      debugPrint('Health Connect SDK status: $status');
      if (status == HealthConnectSdkStatus.sdkUnavailable ||
          status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        debugPrint('Health Connect SDK unavailable; launching installer...');
        await _health!.installHealthConnect();
      }
    } catch (e) {
      debugPrint('Health Connect SDK status check error: $e');
    }

    bool anyGranted = false;

    // 1. Attempt bulk request first
    try {
      final permissions = List<HealthDataAccess>.filled(_types.length, HealthDataAccess.READ);
      bool bulkSuccess = await _health!.requestAuthorization(_types, permissions: permissions);
      if (bulkSuccess) {
        debugPrint('Bulk health permission request succeeded');
        return true;
      }
    } catch (e) {
      debugPrint('Bulk health permission request error: $e');
    }

    // 2. Individual per-type request fallback
    for (var type in _types) {
      try {
        final permissions = [HealthDataAccess.READ];
        bool hasPerm = await _health!.hasPermissions([type], permissions: permissions) ?? false;
        if (!hasPerm) {
          bool reqResult = await _health!.requestAuthorization([type], permissions: permissions);
          if (reqResult) {
            debugPrint('Permission granted for ${type.name}');
            anyGranted = true;
          }
        } else {
          debugPrint('Permission already exists for ${type.name}');
          anyGranted = true;
        }
      } catch (e) {
        debugPrint('Permission request error for ${type.name}: $e');
      }
    }

    return anyGranted;
  }

  /// Open Health Connect App Store / Settings page if required.
  Future<void> openHealthConnectSettings() async {
    if (kIsWeb || _health == null) return;
    try {
      await _health!.installHealthConnect();
    } catch (e) {
      debugPrint('Error launching Health Connect settings: $e');
    }
  }

  /// Get total steps for today.
  Future<double> getTodaySteps() async {
    if (kIsWeb || _health == null) return 0.0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      int? steps = await _health!.getTotalStepsInInterval(midnight, now);
      return (steps ?? 0).toDouble();
    } catch (e) {
      debugPrint('Error getting today steps: $e');
      return 0.0;
    }
  }

  /// Get total workout minutes for today.
  Future<double> getTodayWorkoutMinutes() async {
    if (kIsWeb || _health == null) return 0.0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      List<HealthDataPoint> data = await _health!.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );
      int totalMinutes = 0;
      for (var point in data) {
        totalMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
      }
      return totalMinutes.toDouble();
    } catch (e) {
      debugPrint('Error getting workout minutes: $e');
      return 0.0;
    }
  }

  /// Get today's distance in kilometers using DISTANCE_DELTA (Android Health Connect).
  Future<double> getTodayRunningDistanceKm() async {
    if (kIsWeb || _health == null) return 0.0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      List<HealthDataPoint> data = await _health!.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.DISTANCE_DELTA],
      );
      double totalMeters = 0.0;
      for (var point in data) {
        if (point.value is NumericHealthValue) {
          totalMeters += (point.value as NumericHealthValue).numericValue.toDouble();
        }
      }
      return totalMeters / 1000.0;
    } catch (e) {
      debugPrint('Error getting distance: $e');
      return 0.0;
    }
  }

  /// Get today's active calories burned.
  Future<double> getTodayActiveCalories() async {
    if (kIsWeb || _health == null) return 0.0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      List<HealthDataPoint> data = await _health!.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      double totalCalories = 0.0;
      for (var point in data) {
        if (point.value is NumericHealthValue) {
          totalCalories += (point.value as NumericHealthValue).numericValue.toDouble();
        }
      }
      return totalCalories;
    } catch (e) {
      debugPrint('Error getting active calories: $e');
      return 0.0;
    }
  }


}
