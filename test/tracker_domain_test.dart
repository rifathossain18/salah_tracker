import 'package:flutter_test/flutter_test.dart';
import 'package:salah_tracker/domain/prayer_day.dart';
import 'package:salah_tracker/domain/tracker_backup.dart';
import 'package:salah_tracker/domain/tracker_dates.dart';

void main() {
  group('PrayerDay', () {
    test('only accepts explicit true values for the five prayers', () {
      final day = PrayerDay.fromJson({
        'fajr': true,
        'dhuhr': false,
        'asr': true,
        'maghrib': 'true',
        'isha': true,
        'extra': true,
      });

      expect(day.completedCount, 3);
      expect(day.isComplete, isFalse);
      expect(day.toJson(), {
        'fajr': true,
        'dhuhr': false,
        'asr': true,
        'maghrib': false,
        'isha': true,
      });
    });

    test('toggles one prayer and can mark the whole day', () {
      final initial = PrayerDay.empty();
      final afterToggle = initial.toggle('fajr');
      final allDone = afterToggle.markAll(true);

      expect(initial.completedCount, 0);
      expect(afterToggle.completedCount, 1);
      expect(afterToggle.toggle('fajr').completedCount, 0);
      expect(allDone.isComplete, isTrue);
      expect(allDone.markAll(false).completedCount, 0);
    });
  });

  group('TrackerDates', () {
    test('validates real dates including leap years', () {
      expect(TrackerDates.isValidDateKey('2024-02-29'), isTrue);
      expect(TrackerDates.isValidDateKey('2025-02-29'), isFalse);
      expect(TrackerDates.isValidDateKey('2026-13-01'), isFalse);
      expect(TrackerDates.isValidDateKey('2026-2-01'), isFalse);
    });

    test('clamps month navigation to the last valid day', () {
      expect(
        TrackerDates.shiftMonth(DateTime(2026, 10, 31), -1),
        DateTime(2026, 9, 30),
      );
      expect(
        TrackerDates.shiftMonth(DateTime(2024, 1, 31), 1),
        DateTime(2024, 2, 29),
      );
    });

    test('summarizes only tracked records in the requested month', () {
      final summary = TrackerDates.summarizeMonth({
        '2026-10-01': PrayerDay.fromJson({
          'fajr': true,
          'dhuhr': true,
          'asr': true,
          'maghrib': true,
          'isha': true,
        }),
        '2026-10-02': PrayerDay.fromJson({'fajr': true}),
        '2026-11-01': PrayerDay.fromJson({
          'fajr': true,
          'dhuhr': true,
          'asr': true,
          'maghrib': true,
          'isha': true,
        }),
        '2026-10-35': PrayerDay.fromJson({'fajr': true}),
      }, 2026, 10);

      expect(summary.totalCompleted, 6);
      expect(summary.fullDays, 1);
      expect(summary.trackedDays, 2);
      expect(summary.daysInMonth, 31);
    });
  });

  group('TrackerBackup', () {
    test('round-trips valid entries and ignores invalid date keys', () {
      final encoded = TrackerBackup.encode({
        '2026-10-25': PrayerDay.fromJson({'fajr': true}),
        'not-a-date': PrayerDay.fromJson({'isha': true}),
      }, exportedAt: DateTime.utc(2026, 10, 25));
      final decoded = TrackerBackup.decode(encoded);

      expect(decoded.keys, ['2026-10-25']);
      expect(decoded['2026-10-25']!.completedCount, 1);
    });

    test('imported records replace same-day entries and preserve other dates', () {
      final merged = TrackerBackup.merge(
        {
          '2026-10-25': PrayerDay.fromJson({'fajr': true}),
          '2026-10-24': PrayerDay.fromJson({'asr': true}),
        },
        {
          '2026-10-25': PrayerDay.fromJson({'dhuhr': true}),
          '2026-10-23': PrayerDay.fromJson({'isha': true}),
        },
      );

      expect(merged['2026-10-25']!.toJson()['fajr'], isFalse);
      expect(merged['2026-10-25']!.toJson()['dhuhr'], isTrue);
      expect(merged['2026-10-24']!.toJson()['asr'], isTrue);
      expect(merged['2026-10-23']!.toJson()['isha'], isTrue);
    });

    test('rejects an unsupported backup format', () {
      expect(
        () => TrackerBackup.decode('{"format":"other","version":1,"entries":{}}'),
        throwsFormatException,
      );
    });
  });
}
