import 'package:flutter_test/flutter_test.dart';
import 'package:salah_tracker/domain/prayer_day.dart';
import 'package:salah_tracker/services/prayer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads an empty tracker when no local data exists', () async {
    final entries = await PrayerRepository().load();
    expect(entries, isEmpty);
  });

  test('saves and reloads daily prayer states locally', () async {
    final repository = PrayerRepository();
    await repository.save({
      '2026-10-25': PrayerDay.fromJson({'fajr': true, 'isha': true}),
    });

    final loaded = await repository.load();
    expect(loaded.keys, ['2026-10-25']);
    expect(loaded['2026-10-25']!.completedCount, 2);
  });

  test('recovers safely from corrupt local JSON', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(PrayerRepository.storageKey, '{broken');

    expect(await PrayerRepository().load(), isEmpty);
  });
}
