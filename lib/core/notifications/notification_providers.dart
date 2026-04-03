import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_scheduler.dart';
import 'notification_service.dart';

/// Provides the singleton [NotificationService].
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// Provides [NotificationScheduler] wired to the [NotificationService].
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler(ref.watch(notificationServiceProvider));
});
