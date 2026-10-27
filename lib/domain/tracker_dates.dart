import 'prayer_day.dart';

class MonthSummary {
  const MonthSummary({
    required this.totalCompleted,
    required this.fullDays,
    required this.trackedDays,
    required this.daysInMonth,
  });

  final int totalCompleted;
  final int fullDays;
  final int trackedDays;
  final int daysInMonth;
}

class TrackerDates {
  static final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static String dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static bool isValidDateKey(String key) {
    if (!_datePattern.hasMatch(key)) return false;
    final parts = key.split('-').map(int.tryParse).toList();
    if (parts.any((part) => part == null)) return false;
    final year = parts[0]!;
    final month = parts[1]!;
    final day = parts[2]!;
    if (year < 1 || year > 9999 || month < 1 || month > 12) return false;
    return day >= 1 && day <= daysInMonth(year, month);
  }

  static DateTime? parseDateKey(String key) {
    if (!isValidDateKey(key)) return null;
    final parts = key.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  static int daysInMonth(int year, int month) {
    if (year < 1 || year > 9999 || month < 1 || month > 12) {
      throw RangeError('Year and month must be valid calendar values.');
    }
    if (month == 2) return isLeapYear(year) ? 29 : 28;
    return const <int>[31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1];
  }

  static bool isLeapYear(int year) =>
      year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

  static DateTime shiftMonth(DateTime date, int amount) {
    final totalMonths = date.year * 12 + (date.month - 1) + amount;
    final year = totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    if (year < 1 || year > 9999) {
      throw RangeError('Date is outside the supported calendar range.');
    }
    final day = date.day.clamp(1, daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  static DateTime shiftDay(DateTime date, int amount) =>
      DateTime(date.year, date.month, date.day + amount);

  static MonthSummary summarizeMonth(
    Map<String, PrayerDay> entries,
    int year,
    int month,
  ) {
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-';
    var total = 0;
    var fullDays = 0;
    var trackedDays = 0;

    for (final entry in entries.entries) {
      if (!entry.key.startsWith(prefix) || !isValidDateKey(entry.key)) continue;
      final count = entry.value.completedCount;
      total += count;
      if (count > 0) trackedDays++;
      if (count == prayerIds.length) fullDays++;
    }

    return MonthSummary(
      totalCompleted: total,
      fullDays: fullDays,
      trackedDays: trackedDays,
      daysInMonth: daysInMonth(year, month),
    );
  }
}
