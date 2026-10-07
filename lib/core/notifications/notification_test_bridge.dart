import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Consumes optional Android launch extras (`notif_test=show|schedule`) used by
/// emulator/CI verification via:
/// `adb shell am start ... --es notif_test show`
class NotificationTestBridge {
  static const _channel = MethodChannel('habitapp/notif_test');

  static Future<void> consumePendingLaunchTest() async {
    if (kIsWeb || kReleaseMode) return;
    try {
      final pending = await _channel.invokeMethod<String>('takePending');
      if (pending == null || pending.isEmpty) return;

      // Ensure onboarding redirect does not block test runs.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);

      switch (pending) {
        case 'show':
          await NotificationService.instance.showTestNotification();
          debugPrint('NotificationTestBridge: show test fired');
          break;
        case 'schedule':
          await NotificationService.instance
              .scheduleTestNotification(minutesFromNow: 1);
          debugPrint('NotificationTestBridge: 1-minute schedule fired');
          break;
        default:
          debugPrint('NotificationTestBridge: unknown command $pending');
      }
    } catch (e, st) {
      debugPrint('NotificationTestBridge failed: $e\n$st');
    }
  }
}
