import 'package:flutter_test/flutter_test.dart';
import 'package:salah_tracker/domain/prayer_schedule.dart';
import 'package:salah_tracker/services/prayer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves and reloads the user schedule locally', () async {
    const repository = PrayerRepository();
    final schedule = PrayerSchedule.empty()
        .withTime('fajr', '05:05')
        .withTime('isha', '19:45');

    await repository.saveSchedule(schedule);
    final loaded = await repository.loadSchedule();

    expect(loaded.timeFor('fajr'), '05:05');
    expect(loaded.timeFor('isha'), '19:45');
    expect(loaded.timeFor('asr'), isNull);
  });
}
