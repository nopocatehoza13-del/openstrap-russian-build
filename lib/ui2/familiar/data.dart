import 'dart:isolate';
import 'package:personal_analytics/personal_analytics.dart';
import '../../compute/intraday_stress_bridge.dart';
import '../../data/day_label.dart';
import '../../data/local_repository.dart';
import '../screens/health_screen.dart';
import '../screens/home_screen.dart';

/// Read-only view model. All scores still come from the existing repository.
class FamiliarData {
  final HomeData home;
  final HealthData health;
  final List<Map<String, dynamic>> activities;
  final Map<String, dynamic> sleep;
  final Map<String, dynamic> intradayStress;
  final List<ChartPoint> recovery, strain, steps;
  final String day;
  final AgeEstimate? age;
  Map get importedVitals => health.today['imported_vitals'] is Map
      ? health.today['imported_vitals'] as Map
      : const {};
  num? get oxygenPercent => importedVitals['spo2_pct'] as num?;
  num? get temperatureC => importedVitals['skin_temperature_c'] as num?;
  // Only an actual Celsius measurement may be labelled degrees. A z-score or
  // raw ADC reading cannot be converted without a calibrated sensor mapping.
  num? get temperature => temperatureC;
  String get temperatureUnit => '°C';
  String get nightDay =>
      importedVitals['date']?.toString() ??
      heldOverNightOf(health.today) ??
      day;
  const FamiliarData({
    this.home = const HomeData(),
    this.health = const HealthData(),
    this.activities = const [],
    this.sleep = const {},
    this.intradayStress = const {},
    this.recovery = const [],
    this.strain = const [],
    this.steps = const [],
    this.day = '',
    this.age,
  });

  static Future<FamiliarData> load(LocalRepository repo, DateTime date) async {
    final label = dayLabelOf(date), today = todayLabel();
    final home = label == today
        ? await HomeData.load(repo)
        : await HomeData.loadForDay(repo, label);
    final health = await HealthData.load(repo);
    final recovery = pointsOf(await repo.getChart('recovery'));
    final strain = pointsOf(await repo.getChart('strain'));
    final steps = pointsOf(await repo.getChart('steps'));
    final rows = await repo.getSessions(
      from:
          DateTime(date.year, date.month, date.day).millisecondsSinceEpoch ~/
          1000,
      to:
          DateTime(
            date.year,
            date.month,
            date.day + 1,
          ).millisecondsSinceEpoch ~/
          1000,
      includeDetected: false,
    );
    final activities = <Map<String, dynamic>>[];
    final stress = await repo.getDayStress(label);
    final stored =
        (stress['intraday_stress'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final stressSessions = [
      for (final row in stress['stress_sessions'] as List? ?? const [])
        if (row is Map) row.cast<String, dynamic>(),
    ];
    // An edited/logged/deleted activity immediately changes the exclusions.
    // Uses the same analytics function as derivation, never the nightly score.
    final intraday = stored.isEmpty
        ? const <String, dynamic>{}
        : await Isolate.run(
            () => projectIntradayStress(stored, stressSessions),
          );
    {
      for (final row in rows) {
        final ts = row['start_ts'];
        if (ts is num &&
            dayLabelOf(
                  DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000),
                ) ==
                label) {
          activities.add(row.cast<String, dynamic>());
        }
      }
    }
    activities.sort(
      (a, b) => (a['start_ts'] as num).compareTo(b['start_ts'] as num),
    );
    List<DailyValue> daily(List<ChartPoint> points, [double scale = 1]) => [
      for (final p in points)
        (
          day: dayLabelOf(DateTime.fromMillisecondsSinceEpoch(p.t * 1000)),
          value: p.v * scale,
        ),
    ];
    final age = estimateAge(
      age: (health.profile['age'] as num?)?.toDouble(),
      end: DateTime.now(),
      rhr: daily(health.points('resting_hr')),
      hrv: daily(health.points('hrv')),
      sleepHours: daily(health.points('sleep'), 1 / 60),
      steps: daily(steps),
    );
    return FamiliarData(
      home: home,
      health: health,
      activities: activities,
      sleep: await repo.getDaySleepV2(label),
      intradayStress: intraday,
      recovery: recovery,
      strain: strain,
      steps: steps,
      day: label,
      age: age,
    );
  }
}

String number(num? value, [int digits = 0]) => value == null || !value.isFinite
    ? '—'
    : value.toStringAsFixed(digits).replaceAll('.', ',');
String hours(num? minutes) => minutes == null || !minutes.isFinite
    ? '—'
    : '${minutes.round() ~/ 60} ч ${minutes.round() % 60} мин';
String clockMinutes(int? minutes) => minutes == null
    ? '—'
    : '${((minutes % 1440) ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
String clockTs(Object? seconds) => seconds is! num
    ? '—'
    : clockMinutes(
        DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000).hour * 60 +
            DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000).minute,
      );

/// A dense, dated series. Never connect across a calendar gap.
List<double?> datedSeries(List<ChartPoint> points, DateTime end, int days) {
  final map = {
    for (final p in points)
      dayLabelOf(DateTime.fromMillisecondsSinceEpoch(p.t * 1000)): p.v,
  };
  return [
    for (var i = days - 1; i >= 0; i--)
      map[dayLabelOf(DateTime(end.year, end.month, end.day - i))],
  ];
}
