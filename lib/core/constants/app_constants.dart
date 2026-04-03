// App-wide constants
class AppConstants {
  static const String appName = 'Habit Tracker';
  static const String appVersion = '1.0.0';

  // Database
  static const String dbName = 'habit_tracker.db';
  static const int dbVersion = 1;

  // Shared preferences keys
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyUserId = 'user_id';
  static const String keyThemeMode = 'theme_mode';

  // Notification channel
  static const String notificationChannelId = 'habit_reminders';
  static const String notificationChannelName = 'Habit Reminders';
  static const String notificationChannelDescription =
      'Daily reminders for your habits';
}
