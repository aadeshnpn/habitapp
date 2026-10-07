/// Persisted mindfulness bell settings (single global profile).
class MindfulnessBellConfig {
  static const jitterMinutes = 10;
  static const intervalChoices = [15, 30, 45, 60, 90, 120];
  static const soundChoices = [
    'bowl',
    'chime',
    'soft_bell',
    'wood',
    'gong',
  ];

  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int intervalMinutes;
  final String soundId;

  const MindfulnessBellConfig({
    required this.enabled,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.intervalMinutes,
    required this.soundId,
  });

  static const defaults = MindfulnessBellConfig(
    enabled: false,
    startHour: 9,
    startMinute: 0,
    endHour: 17,
    endMinute: 0,
    intervalMinutes: 30,
    soundId: 'bowl',
  );

  String get startTimeLabel =>
      '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';

  String get endTimeLabel =>
      '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';

  static String soundDisplayName(String soundId) {
    switch (soundId) {
      case 'bowl':
        return 'Bowl';
      case 'chime':
        return 'Chime';
      case 'soft_bell':
        return 'Soft Bell';
      case 'wood':
        return 'Wood';
      case 'gong':
        return 'Gong';
      default:
        return soundId;
    }
  }

  MindfulnessBellConfig copyWith({
    bool? enabled,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    int? intervalMinutes,
    String? soundId,
  }) {
    return MindfulnessBellConfig(
      enabled: enabled ?? this.enabled,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      soundId: soundId ?? this.soundId,
    );
  }
}
