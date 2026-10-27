import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salah_tracker/main.dart';
import 'package:salah_tracker/domain/prayer_day.dart';
import 'package:salah_tracker/domain/prayer_schedule.dart';
import 'package:salah_tracker/services/prayer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'shows prayer times on the tracker and keeps English navigation',
    (tester) async {
      await tester.pumpWidget(const SalahTrackerApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nav-today')), findsOneWidget);
      expect(find.byKey(const Key('nav-history')), findsOneWidget);
      expect(find.byKey(const Key('nav-data')), findsOneWidget);
      expect(find.byKey(const Key('next-prayer-card')), findsNothing);
      expect(find.text('Add prayer time'), findsNWidgets(5));

      await tester.tap(find.byKey(const Key('nav-history')));
      await tester.pumpAndSettle();
      expect(find.text('Prayer history'), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav-data')));
      await tester.pumpAndSettle();
      expect(find.text('Backup & storage'), findsOneWidget);
      expect(find.byKey(const Key('clear-data')), findsNothing);
    },
  );

  testWidgets('keeps prayer records and schedule available after app restart', (
    tester,
  ) async {
    const repository = PrayerRepository();
    await repository.save({
      '2026-10-26': PrayerDay.fromJson({'fajr': true}),
    });
    await repository.saveSchedule(
      PrayerSchedule.empty()
          .withTime('fajr', '04:55')
          .withTime('dhuhr', '12:10'),
    );

    await tester.pumpWidget(SalahTrackerApp(repository: repository));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('schedule-time-fajr')),
        matching: find.text('04:55'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('schedule-time-dhuhr')),
        matching: find.text('12:10'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(SalahTrackerApp(repository: repository));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('schedule-time-fajr')),
        matching: find.text('04:55'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('schedule-time-dhuhr')),
        matching: find.text('12:10'),
      ),
      findsOneWidget,
    );
    expect(
      (await repository.load())['2026-10-26']!.isCompleted('fajr'),
      isTrue,
    );
  });
}
