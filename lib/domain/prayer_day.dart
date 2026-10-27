const prayerIds = <String>['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

const prayerNames = <String, String>{
  'fajr': 'Fajr',
  'dhuhr': 'Dhuhr',
  'asr': 'Asr',
  'maghrib': 'Maghrib',
  'isha': 'Isha',
};

class PrayerDay {
  PrayerDay({Map<String, Object?>? values})
    : _prayers = Map.unmodifiable({
        for (final id in prayerIds) id: values?[id] == true,
      });

  final Map<String, bool> _prayers;

  factory PrayerDay.empty() => PrayerDay();

  factory PrayerDay.fromJson(Object? json) {
    if (json is! Map) return PrayerDay.empty();
    return PrayerDay(values: {for (final id in prayerIds) id: json[id]});
  }

  bool isCompleted(String prayerId) {
    _checkPrayerId(prayerId);
    return _prayers[prayerId]!;
  }

  int get completedCount =>
      prayerIds.where((id) => _prayers[id] == true).length;

  bool get isComplete => completedCount == prayerIds.length;

  PrayerDay toggle(String prayerId) {
    _checkPrayerId(prayerId);
    return PrayerDay(
      values: {
        for (final id in prayerIds)
          id: id == prayerId ? !_prayers[id]! : _prayers[id]!,
      },
    );
  }

  PrayerDay markAll(bool completed) =>
      PrayerDay(values: {for (final id in prayerIds) id: completed});

  Map<String, bool> toJson() => Map.unmodifiable(_prayers);

  static void _checkPrayerId(String prayerId) {
    if (!prayerIds.contains(prayerId)) {
      throw ArgumentError.value(prayerId, 'prayerId', 'Unknown prayer');
    }
  }
}
