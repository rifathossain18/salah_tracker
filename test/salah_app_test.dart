import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salah_tracker/main.dart';
import 'package:salah_tracker/services/prayer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows five prayers and persists a check-in', (tester) async {
    await tester.pumpWidget(const SalahTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Salah Tracker'), findsOneWidget);
    expect(find.byKey(const Key('brand-mark-logo')), findsOneWidget);
    expect(find.text('Fajr'), findsOneWidget);
    expect(find.text('Dhuhr'), findsOneWidget);
    expect(find.text('Asr'), findsOneWidget);
    expect(find.text('Maghrib'), findsOneWidget);
    expect(find.text('Isha'), findsOneWidget);
    expect(find.byKey(const Key('schedule-empty')), findsOneWidget);
    expect(find.byKey(const Key('schedule-time-fajr')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('prayer-fajr')));
    await tester.tap(find.byKey(const Key('prayer-fajr')));
    await tester.pumpAndSettle();

    final saved = await const PrayerRepository().load();
    expect(saved.values.single.completedCount, 1);

    await tester.tap(find.byKey(const Key('prayer-fajr')));
    await tester.pumpAndSettle();
    final cleared = await const PrayerRepository().load();
    expect(cleared.values.single.completedCount, 0);
  });
}
