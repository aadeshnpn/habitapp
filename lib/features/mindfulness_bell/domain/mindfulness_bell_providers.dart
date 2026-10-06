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
Future<void> saveMindfulnessBellConfig(
  WidgetRef ref,
  MindfulnessBellConfig config,
) async {
  await ref.read(mindfulnessBellStoreProvider).save(config);
  ref.invalidate(mindfulnessBellConfigProvider);
  ref.invalidate(scheduleNotificationsProvider);
}
