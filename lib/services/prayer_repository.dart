import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/prayer_day.dart';
import '../domain/prayer_schedule.dart';
import '../domain/tracker_dates.dart';

// -----------------------------------------------------------------------------
// EXCEPTIONS
// -----------------------------------------------------------------------------

/// Base class for every persistence failure raised by [PrayerRepository].
sealed class PrayerStorageException implements Exception {
  const PrayerStorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      '${runtimeType.toString()}: $message'
      '${cause == null ? '' : '  (cause: $cause)'}';
}

/// Thrown when stored prayer data cannot be read or decoded.
class PrayerStorageReadException extends PrayerStorageException {
  const PrayerStorageReadException(super.message, [super.cause]);
}

/// Thrown when local prayer data cannot be persisted.
class PrayerStorageWriteException extends PrayerStorageException {
  const PrayerStorageWriteException(super.message, [super.cause]);
}

// -----------------------------------------------------------------------------
// REPOSITORY
// -----------------------------------------------------------------------------

/// Local, offline-only persistence for prayer records and prayer schedule.
///
/// Backed by [SharedPreferences] and JSON, with graceful degradation on
/// corruption and clear typed failures on write errors.
class PrayerRepository {
  const PrayerRepository();

  /// Current schema version for stored prayer data. Bump this when the shape
  /// of the JSON payload changes so future migrations can detect old data.
  static const int schemaVersion = 1;

  // -- Public storage keys (kept stable for backward compatibility) -----------
  static const String storageKey = 'namaz-tracker.entries.v1';
  static const String scheduleStorageKey = 'namaz-tracker.schedule.v1';

  // -- Internal metadata keys -------------------------------------------------
  static const String _schemaKey = 'namaz-tracker.schema.v1';
  static const String _lastSavedKey = 'namaz-tracker.lastSavedAt.v1';

  // Cache a single SharedPreferences future per process — avoids repeated
  // platform-channel round trips on every read/write.
  static Future<SharedPreferences>? _preferencesFuture;
  static Future<SharedPreferences> get _preferences =>
      _preferencesFuture ??= SharedPreferences.getInstance();

  // ---------------------------------------------------------------------------
  // PRAYER SCHEDULE
  // ---------------------------------------------------------------------------

  /// Reads the saved prayer schedule, falling back to an empty schedule if the
  /// stored payload is missing, empty, or corrupt.
  Future<PrayerSchedule> loadSchedule() async {
    try {
      final prefs = await _preferences;
      final raw = prefs.getString(scheduleStorageKey);
      if (raw == null || raw.isEmpty) return PrayerSchedule.empty();

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return PrayerSchedule.empty();
      return PrayerSchedule.fromJson(decoded);
    } on FormatException catch (e, st) {
      debugPrint('[PrayerRepository] Corrupt schedule payload: $e\n$st');
      return PrayerSchedule.empty();
    } catch (e, st) {
      debugPrint('[PrayerRepository] Failed to load prayer schedule: $e\n$st');
      return PrayerSchedule.empty();
    }
  }

  /// Persists the prayer schedule. Throws [PrayerStorageWriteException] on
  /// failure.
  Future<void> saveSchedule(PrayerSchedule schedule) async {
    try {
      final prefs = await _preferences;
      final saved = await prefs.setString(
        scheduleStorageKey,
        jsonEncode(schedule.toJson()),
      );
      if (!saved) {
        throw const PrayerStorageWriteException(
          'Prayer schedule could not be saved.',
        );
      }
      await _writeMetadata(prefs);
    } on PrayerStorageException {
      rethrow;
    } catch (e) {
      throw PrayerStorageWriteException(
        'Prayer schedule could not be saved.',
        e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // PRAYER ENTRIES
  // ---------------------------------------------------------------------------

  /// Loads all prayer entries. Malformed records are skipped and logged;
  /// corrupt JSON produces an empty map rather than an exception.
  Future<Map<String, PrayerDay>> load() async {
    try {
      final prefs = await _preferences;
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return const {};

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};

      final entries = <String, PrayerDay>{};
      var skipped = 0;
      for (final item in decoded.entries) {
        final key = item.key;
        if (key is! String || !TrackerDates.isValidDateKey(key)) {
          skipped++;
          continue;
        }
        try {
          entries[key] = PrayerDay.fromJson(item.value);
        } catch (_) {
          skipped++;
        }
      }
      if (skipped > 0) {
        debugPrint(
          '[PrayerRepository] Skipped $skipped malformed entries '
          'out of ${decoded.length}.',
        );
      }
      return _sorted(entries);
    } on FormatException catch (e, st) {
      debugPrint('[PrayerRepository] Corrupt entries payload: $e\n$st');
      return const {};
    } catch (e, st) {
      debugPrint('[PrayerRepository] Failed to load prayer entries: $e\n$st');
      return const {};
    }
  }

  /// Persists all prayer entries. Invalid keys are dropped before saving.
  /// Throws [PrayerStorageWriteException] on failure.
  Future<void> save(Map<String, PrayerDay> entries) async {
    try {
      final clean = <String, PrayerDay>{};
      for (final item in entries.entries) {
        if (TrackerDates.isValidDateKey(item.key)) {
          clean[item.key] = item.value;
        }
      }
      final sorted = _sorted(clean);
      final payload = jsonEncode({
        for (final e in sorted.entries) e.key: e.value.toJson(),
      });

      final prefs = await _preferences;
      final saved = await prefs.setString(storageKey, payload);
      if (!saved) {
        throw const PrayerStorageWriteException(
          'Local prayer data could not be saved.',
        );
      }
      await _writeMetadata(prefs);
    } on PrayerStorageException {
      rethrow;
    } catch (e) {
      throw PrayerStorageWriteException(
        'Local prayer data could not be saved.',
        e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // CONVENIENCE / DIAGNOSTICS
  // ---------------------------------------------------------------------------

  /// Removes every stored prayer entry. Schedule is left intact.
  Future<void> clearEntries() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(storageKey);
    } catch (e, st) {
      debugPrint('[PrayerRepository] Failed to clear entries: $e\n$st');
    }
  }

  /// Removes the stored prayer schedule. Entries are left intact.
  Future<void> clearSchedule() async {
    try {
      final prefs = await _preferences;
      await prefs.remove(scheduleStorageKey);
    } catch (e, st) {
      debugPrint('[PrayerRepository] Failed to clear schedule: $e\n$st');
    }
  }

  /// Removes both entries and schedule plus metadata.
  Future<void> clearAll() async {
    try {
      final prefs = await _preferences;
      await Future.wait(<Future<bool>>[
        prefs.remove(storageKey),
        prefs.remove(scheduleStorageKey),
        prefs.remove(_lastSavedKey),
        prefs.remove(_schemaKey),
      ]);
    } catch (e, st) {
      debugPrint('[PrayerRepository] Failed to clear storage: $e\n$st');
    }
  }

  /// Number of stored day records. Useful for diagnostics or empty-state UI.
  Future<int> entryCount() async => (await load()).length;

  /// Approximate byte size of the persisted prayer entries payload.
  Future<int> storageBytes() async {
    try {
      final prefs = await _preferences;
      return (prefs.getString(storageKey) ?? '').length;
    } catch (_) {
      return 0;
    }
  }

  /// Returns the timestamp of the last successful write, if known.
  Future<DateTime?> lastSavedAt() async {
    try {
      final prefs = await _preferences;
      final raw = prefs.getString(_lastSavedKey);
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Returns the stored schema version, or `null` if never written.
  Future<int?> schema() async {
    try {
      final prefs = await _preferences;
      return prefs.getInt(_schemaKey);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // INTERNALS
  // ---------------------------------------------------------------------------

  /// Best-effort metadata write — never throws, never blocks a successful save.
  Future<void> _writeMetadata(SharedPreferences prefs) async {
    try {
      await prefs.setInt(_schemaKey, schemaVersion);
      await prefs.setString(_lastSavedKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[PrayerRepository] Metadata write failed (non-fatal): $e');
    }
  }

  static Map<String, PrayerDay> _sorted(Map<String, PrayerDay> entries) {
    final keys = entries.keys.toList()..sort();
    return Map<String, PrayerDay>.unmodifiable(<String, PrayerDay>{
      for (final key in keys) key: entries[key]!,
    });
  }
}