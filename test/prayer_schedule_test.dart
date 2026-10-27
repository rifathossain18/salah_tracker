import 'package:flutter_test/flutter_test.dart';
import 'package:salah_tracker/domain/prayer_schedule.dart';

void main() {
  test('stores valid recurring prayer times in 24-hour format', () {
    final schedule = PrayerSchedule.fromJson({
      'fajr': '04:55',
      'dhuhr': '12:10',
      'asr': '15:35',
      'maghrib': '18:02',
      'isha': '19:30',
    });

    expect(schedule.timeFor('fajr'), '04:55');
    expect(schedule.timeFor('dhuhr'), '12:10');
    expect(schedule.timeFor('isha'), '19:30');
    expect(schedule.toJson()['maghrib'], '18:02');
  });

  test('rejects malformed or impossible times from imported data', () {
    final schedule = PrayerSchedule.fromJson({
      'fajr': '24:00',
      'dhuhr': '4:05',
      'asr': '15:75',
      'maghrib': '18:02',
      'isha': '19:30',
    });

    expect(schedule.timeFor('fajr'), isNull);
    expect(schedule.timeFor('dhuhr'), isNull);
    expect(schedule.timeFor('asr'), isNull);
    expect(schedule.timeFor('maghrib'), '18:02');
  });

  test('updates and clears one prayer time immutably', () {
    final empty = PrayerSchedule.empty();
    final withFajr = empty.withTime('fajr', '05:10');

    expect(empty.timeFor('fajr'), isNull);
    expect(withFajr.timeFor('fajr'), '05:10');
    expect(withFajr.withTime('fajr', null).timeFor('fajr'), isNull);
  });
}
