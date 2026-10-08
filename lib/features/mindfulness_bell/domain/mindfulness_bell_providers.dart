import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_providers.dart';
import 'mindfulness_bell_config.dart';
import 'mindfulness_bell_store.dart';

final mindfulnessBellStoreProvider = Provider<MindfulnessBellStore>((ref) {
  return MindfulnessBellStore();
});

final mindfulnessBellConfigProvider =
    FutureProvider<MindfulnessBellConfig>((ref) async {
  return ref.watch(mindfulnessBellStoreProvider).load();
});

/// Saves config and triggers a full notification reschedule.
/// Returns how many mindfulness alarms were registered.
Future<int> saveMindfulnessBellConfig(
  WidgetRef ref,
  MindfulnessBellConfig config,
) async {
  await ref.read(mindfulnessBellStoreProvider).save(config);
  ref.invalidate(mindfulnessBellConfigProvider);
  // Schedule mindfulness immediately so Save does not race the keepAlive
  // provider (which may still be waiting on habits/streaks).
  final scheduled = await ref
      .read(notificationSchedulerProvider)
      .refreshMindfulnessBell(config);
  ref.invalidate(scheduleNotificationsProvider);
  return scheduled;
}
