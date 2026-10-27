import 'prayer_day.dart';

/// Immutable collection of per-prayer times for one local schedule.
///
/// Times are stored internally as strict 24-hour `HH:mm` strings — this keeps
/// date math, `TimeOfDay` interop, and existing persisted data fully compatible.
/// Display helpers in this class format them as 12-hour `h:mm AM/PM` for UI.
///
/// Input parsing accepts both `HH:mm` and `h:mm AM/PM`, so callers can pass
/// either style to [withTime].
class PrayerSchedule {
  PrayerSchedule._(Map<String, String> times)
      : _times = Map<String, String>.unmodifiable(times);

  factory PrayerSchedule.empty() => PrayerSchedule._(const {});

  /// Builds a schedule from JSON. Accepts both strict 24-hour `HH:mm` and
  /// legacy 12-hour `h:mm AM/PM` values; unknown or invalid entries are
  /// silently dropped so a single bad field never discards the whole payload.
  factory PrayerSchedule.fromJson(Object? json) {
    if (json is! Map) return PrayerSchedule.empty();
    final times = <String, String>{};
    for (final id in prayerIds) {
      final value = json[id];
      if (value is! String) continue;
      final normalized = normalizeTime(value);
      if (normalized != null) times[id] = normalized;
    }
    return PrayerSchedule._(times);
  }

  // ── Patterns ──────────────────────────────────────────────────────────────

  static final RegExp _time24 = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
  static final RegExp _time12 =
      RegExp(r'^(\d{1,2}):([0-5]\d)\s*([AaPp][Mm])$');

  // ── State ─────────────────────────────────────────────────────────────────

  final Map<String, String> _times;

  // ── Queries ───────────────────────────────────────────────────────────────

  bool get isEmpty => _times.isEmpty;
  bool get isNotEmpty => _times.isNotEmpty;
  bool get hasAnyTime => _times.isNotEmpty;
  bool get hasAllTimes => prayerIds.every(_times.containsKey);
  int get count => _times.length;
  List<String> get prayerIdsWithTime =>
      prayerIds.where(_times.containsKey).toList(growable: false);

  /// Raw 24-hour `HH:mm` string, or `null` if unset.
  String? timeFor(String prayerId) {
    _checkPrayerId(prayerId);
    return _times[prayerId];
  }

  // ── 12-hour display helpers ───────────────────────────────────────────────

  /// `h:mm AM/PM` (e.g. `"5:30 AM"`), or `null` if unset.
  String? displayTime(String prayerId) {
    final v = timeFor(prayerId);
    return v == null ? null : formatTime12h(v);
  }

  /// Just the 12-hour hour string (`"1"`–`"12"`), or `null`.
  String? hourFor(String prayerId) {
    final v = timeFor(prayerId);
    if (v == null) return null;
    final h = int.parse(v.substring(0, 2));
    return (h % 12 == 0 ? 12 : h % 12).toString();
  }

  /// The minute component (`"00"`–`"59"`), or `null`.
  String? minuteFor(String prayerId) {
    final v = timeFor(prayerId);
    return v?.substring(3, 5);
  }

  /// `"AM"` or `"PM"`, or `null`.
  String? periodFor(String prayerId) {
    final v = timeFor(prayerId);
    if (v == null) return null;
    return int.parse(v.substring(0, 2)) < 12 ? 'AM' : 'PM';
  }

  // ── Mutators ──────────────────────────────────────────────────────────────

  /// Returns a copy with `prayerId` set to `time` (or cleared if `null`).
  /// Accepts both `HH:mm` and `h:mm AM/PM`.
  PrayerSchedule withTime(String prayerId, String? time) {
    _checkPrayerId(prayerId);
    String? normalized = time;
    if (normalized != null) {
      normalized = normalizeTime(normalized);
      if (normalized == null) {
        throw ArgumentError.value(
          time,
          'time',
          'Expected 24-hour "HH:mm" or 12-hour "h:mm AM/PM"',
        );
      }
    }
    final updated = Map<String, String>.of(_times);
    if (normalized == null) {
      updated.remove(prayerId);
    } else {
      updated[prayerId] = normalized;
    }
    return PrayerSchedule._(updated);
  }

  /// Returns a copy with multiple times applied at once.
  PrayerSchedule withTimes(Map<String, String?> times) {
    var result = this;
    for (final e in times.entries) {
      result = result.withTime(e.key, e.value);
    }
    return result;
  }

  /// Returns a copy with the given prayer ids cleared.
  PrayerSchedule withoutPrayers(Iterable<String> ids) {
    final updated = Map<String, String>.of(_times);
    for (final id in ids) {
      _checkPrayerId(id);
      updated.remove(id);
    }
    return PrayerSchedule._(updated);
  }

  /// Returns an empty schedule (drops all times).
  PrayerSchedule clear() => PrayerSchedule.empty();

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, String> toJson() => Map<String, String>.unmodifiable(_times);

  // ── Static utilities ──────────────────────────────────────────────────────

  /// True if `value` is a strict 24-hour `HH:mm`.
  static bool isValidTime(String value) => _time24.hasMatch(value);

  /// Normalizes any recognized time string to `HH:mm`. Returns `null` on
  /// failure. Accepts both `HH:mm` and `h:mm AM/PM`.
  static String? normalizeTime(String value) {
    final trimmed = value.trim();
    if (_time24.hasMatch(trimmed)) return trimmed;
    final m = _time12.firstMatch(trimmed);
    if (m == null) return null;
    final h12 = int.parse(m.group(1)!);
    if (h12 < 1 || h12 > 12) return null;
    final mm = m.group(2)!;
    final period = m.group(3)!.toUpperCase();
    var h24 = h12 % 12;
    if (period == 'PM') h24 += 12;
    return '${h24.toString().padLeft(2, '0')}:$mm';
  }

  /// Formats a 24-hour `HH:mm` string as `h:mm AM/PM`.
  static String formatTime12h(String value) {
    final h24 = int.parse(value.substring(0, 2));
    final mm = value.substring(3, 5);
    final period = h24 < 12 ? 'AM' : 'PM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:$mm $period';
  }

  /// Returns the next prayer at or after `now`, or `null` if none are set.
  ({String id, DateTime time})? nextPrayerAfter(DateTime now) {
    String? nextId;
    DateTime? nextTime;
    for (final id in prayerIds) {
      final value = _times[id];
      if (value == null) continue;
      final h = int.parse(value.substring(0, 2));
      final m = int.parse(value.substring(3, 5));
      var candidate = DateTime(now.year, now.month, now.day, h, m);
      if (!candidate.isAfter(now)) {
        candidate = DateTime(now.year, now.month, now.day + 1, h, m);
      }
      if (nextTime == null || candidate.isBefore(nextTime)) {
        nextId = id;
        nextTime = candidate;
      }
    }
    if (nextId == null || nextTime == null) return null;
    return (id: nextId, time: nextTime);
  }

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PrayerSchedule) return false;
    if (other._times.length != _times.length) return false;
    for (final id in _times.keys) {
      if (other._times[id] != _times[id]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var h = 17;
    for (final key in _times.keys.toList()..sort()) {
      h = h * 31 + key.hashCode;
      h = h * 31 + _times[key]!.hashCode;
    }
    return h;
  }

  @override
  String toString() => 'PrayerSchedule('
      '${_times.length} set'
      '${_times.isEmpty ? '' : ': ${_times.keys.join(', ')}'})';

  // ── Internals ─────────────────────────────────────────────────────────────

  static void _checkPrayerId(String prayerId) {
    if (!prayerIds.contains(prayerId)) {
      throw ArgumentError.value(prayerId, 'prayerId', 'Unknown prayer');
    }
  }
}