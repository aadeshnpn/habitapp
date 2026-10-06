import 'package:shared_preferences/shared_preferences.dart';

import 'mindfulness_bell_config.dart';

/// Loads/saves [MindfulnessBellConfig] from SharedPreferences.
class MindfulnessBellStore {
  static const _enabledKey = 'mindfulness_bell_enabled';
  static const _startHourKey = 'mindfulness_bell_start_hour';
  static const _startMinuteKey = 'mindfulness_bell_start_minute';
  static const _endHourKey = 'mindfulness_bell_end_hour';
  static const _endMinuteKey = 'mindfulness_bell_end_minute';
  static const _intervalKey = 'mindfulness_bell_interval';
  static const _soundKey = 'mindfulness_bell_sound';

  Future<MindfulnessBellConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = MindfulnessBellConfig.defaults;
    final sound = prefs.getString(_soundKey) ?? defaults.soundId;
    final interval = prefs.getInt(_intervalKey) ?? defaults.intervalMinutes;

    return MindfulnessBellConfig(
      enabled: prefs.getBool(_enabledKey) ?? defaults.enabled,
      startHour: prefs.getInt(_startHourKey) ?? defaults.startHour,
      startMinute: prefs.getInt(_startMinuteKey) ?? defaults.startMinute,
      endHour: prefs.getInt(_endHourKey) ?? defaults.endHour,
      endMinute: prefs.getInt(_endMinuteKey) ?? defaults.endMinute,
      intervalMinutes: MindfulnessBellConfig.intervalChoices.contains(interval)
          ? interval
          : defaults.intervalMinutes,
      soundId: MindfulnessBellConfig.soundChoices.contains(sound)
          ? sound
          : defaults.soundId,
    );
  }

  Future<void> save(MindfulnessBellConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, config.enabled);
    await prefs.setInt(_startHourKey, config.startHour);
    await prefs.setInt(_startMinuteKey, config.startMinute);
    await prefs.setInt(_endHourKey, config.endHour);
    await prefs.setInt(_endMinuteKey, config.endMinute);
    await prefs.setInt(_intervalKey, config.intervalMinutes);
    await prefs.setString(_soundKey, config.soundId);
  }
}
