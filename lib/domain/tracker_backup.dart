import 'dart:convert';

import 'prayer_day.dart';
import 'tracker_dates.dart';

class TrackerBackup {
  static const String format = 'namaz-tracker-backup';
  static const int version = 1;

  static String encode(
    Map<String, PrayerDay> entries, {
    DateTime? exportedAt,
  }) {
    final clean = _clean(entries);
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'entries': {
        for (final key in clean.keys) key: clean[key]!.toJson(),
      },
    });
  }

  static Map<String, PrayerDay> decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      rethrow;
    }

    if (decoded is! Map ||
        decoded['format'] != format ||
        decoded['version'] != version ||
        decoded['entries'] is! Map) {
      throw const FormatException('Unsupported Salah Tracker backup.');
    }

    final rawEntries = decoded['entries'] as Map;
    final entries = <String, PrayerDay>{};
    for (final item in rawEntries.entries) {
      if (item.key is String && TrackerDates.isValidDateKey(item.key as String)) {
        entries[item.key as String] = PrayerDay.fromJson(item.value);
      }
    }
    return _sorted(entries);
  }

  static Map<String, PrayerDay> merge(
    Map<String, PrayerDay> existing,
    Map<String, PrayerDay> imported,
  ) {
    final merged = <String, PrayerDay>{..._clean(existing), ..._clean(imported)};
    return _sorted(merged);
  }

  static Map<String, PrayerDay> _clean(Map<String, PrayerDay> entries) {
    final clean = <String, PrayerDay>{};
    for (final item in entries.entries) {
      if (TrackerDates.isValidDateKey(item.key)) clean[item.key] = item.value;
    }
    return _sorted(clean);
  }

  static Map<String, PrayerDay> _sorted(Map<String, PrayerDay> entries) {
    final keys = entries.keys.toList()..sort();
    return Map<String, PrayerDay>.unmodifiable({
      for (final key in keys) key: entries[key]!,
    });
  }
}
