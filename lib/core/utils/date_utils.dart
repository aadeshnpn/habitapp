// Date utility helpers
class HabitDateUtils {
  /// Returns a [DateTime] with only the date portion (no time).
  static DateTime dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  /// Returns true if [date] is today.
  static bool isToday(DateTime date) {
    final now = dateOnly(DateTime.now());
    return dateOnly(date) == now;
  }

  /// Returns the difference in days between two dates (ignores time).
  static int daysBetween(DateTime from, DateTime to) {
    final f = dateOnly(from);
    final t = dateOnly(to);
    return t.difference(f).inDays;
  }
}
