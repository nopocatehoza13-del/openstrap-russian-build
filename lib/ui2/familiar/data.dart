import 'dart:isolate';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:personal_analytics/personal_analytics.dart';
import '../../compute/intraday_stress_bridge.dart';
import '../../data/day_label.dart';
import '../../data/db.dart' show LocalDb;
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

  /// This day's WHOOP-formula block (`getDayStrain(day)['whoop']`): strain
  /// 0–21, HRR zone minutes, zone bounds, cumulative curve. Empty when the day
  /// had no reserve.
  final Map<String, dynamic> whoopDay;

  /// Extra series the WHOOP screens draw (deep/rem/light minutes, efficiency,
  /// calories, the whoop_* keys), keyed like [LocalRepository.getChart].
  final Map<String, List<ChartPoint>> series;

  /// Sleep windows of the last 60 nights (`date`, `onset_ts`, `wake_ts`).
  final List<Map<String, dynamic>> sleepWindows;

  /// Journal rows of the last 30 days and the behaviour-impact insights.
  final List<Map<String, dynamic>> journal;
  final Map<String, dynamic> journalInsights;

  /// The night's heart-rate curve (`[{t, v}]`, minute means) across the sleep
  /// window — yesterday's evening half plus this morning's.
  final List<Map<String, dynamic>> nightHr;

  /// Battery percent and charging flag captured at load time.
  final double? batteryPct;
  final bool charging;

  /// v8: the day's wear segments (`getDayWear`), naps (`getDayNaps`), the band
  /// alarm schedule rows and the last 30 days of sessions, newest first (for
  /// "the previous same activity" and rest-day counts).
  final Map<String, dynamic> wear;
  final Map<String, dynamic> naps;
  final List<Map<String, Object?>> alarmSchedule;
  final List<Map<String, dynamic>> recentSessions;

  /// v8.1: readers that failed during [load], as `what: cause`, so the screen
  /// can list every cause at once instead of blanking.
  final List<String> loadFailures;

  /// The cross-day WHOOP-formula block (`insights['whoop']`): tonight's need,
  /// last night's performance, recovery, Healthspan age. Empty when the rollup
  /// is stale or absent.
  Map<String, dynamic> get whoop => health.insights['whoop'] is Map
      ? (health.insights['whoop'] as Map).cast<String, dynamic>()
      : const {};
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
    this.whoopDay = const {},
    this.series = const {},
    this.sleepWindows = const [],
    this.journal = const [],
    this.journalInsights = const {},
    this.nightHr = const [],
    this.batteryPct,
    this.charging = false,
    this.wear = const {},
    this.naps = const {},
    this.alarmSchedule = const [],
    this.recentSessions = const [],
    this.loadFailures = const [],
  });

  static Future<FamiliarData> load(
    LocalRepository repo,
    DateTime date, {
    double? batteryPct,
    bool charging = false,
  }) async {
    final failures = <String>[];
    void fail(String what, Object e) {
      final why = e.toString();
      failures.add('$what: ${why.length > 160 ? why.substring(0, 160) : why}');
      debugPrint('[familiar] $what failed: $e');
    }

    final label = dayLabelOf(date), today = todayLabel();
    // Every reader is guarded on its own (v8.1): one failing read logs its
    // cause and yields an empty block, so the screen shows what it has instead
    // of the "could not read" card for the whole day.
    final home = await _read(
      fail,
      'home',
      () => label == today ? HomeData.load(repo) : HomeData.loadForDay(repo, label),
      const HomeData(),
    );
    final health = await _read(fail, 'health', () => HealthData.load(repo), const HealthData());
    final recovery = pointsOf(await _read(fail, 'chart recovery', () => repo.getChart('recovery'), const <String, dynamic>{}));
    final strain = pointsOf(await _read(fail, 'chart strain', () => repo.getChart('strain'), const <String, dynamic>{}));
    final steps = pointsOf(await _read(fail, 'chart steps', () => repo.getChart('steps'), const <String, dynamic>{}));
    final strainDay = await _read(fail, 'day strain', () => repo.getDayStrain(label), const <String, dynamic>{});
    final series = <String, List<ChartPoint>>{};
    for (final k in const [
      'deep', 'rem', 'light', 'efficiency', 'calories',
      'whoop_strain', 'whoop_z13_min', 'whoop_z45_min', 'whoop_recovery',
      'whoop_sleep_perf', 'whoop_consistency', 'whoop_hours_vs_need', 'whoop_need_min',
      'whoop_spo2_pct', 'whoop_skin_temp_c',
    ]) {
      try {
        series[k] = pointsOf(await repo.getChart(k));
      } catch (e) {
        fail('chart $k', e);
        series[k] = const [];
      }
    }
    List<Map<String, dynamic>> windows = const [];
    List<Map<String, dynamic>> journal = const [];
    Map<String, dynamic> journalInsights = const {};
    try {
      windows = await repo.sleepWindows(days: 60);
    } catch (e) {
      fail('sleep windows', e);
    }
    try {
      journal = await repo.getJournal(range: '30d');
    } catch (e) {
      fail('journal', e);
    }
    try {
      journalInsights = await repo.getJournalInsights(range: '90d');
    } catch (e) {
      fail('journal insights', e);
    }
    final whoopDay = strainDay['whoop'] is Map
        ? (strainDay['whoop'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final toSec = DateTime(date.year, date.month, date.day + 1).millisecondsSinceEpoch ~/ 1000;
    var rows = await _read(
      fail,
      'sessions 30d',
      () => repo.getSessions(
        from: DateTime(date.year, date.month, date.day - 30).millisecondsSinceEpoch ~/ 1000,
        to: toSec,
        includeDetected: false,
      ),
      const <Map<String, dynamic>>[],
    );
    if (rows.isEmpty) {
      rows = await _read(
        fail,
        'sessions day',
        () => repo.getSessions(
          from: DateTime(date.year, date.month, date.day).millisecondsSinceEpoch ~/ 1000,
          to: toSec,
          includeDetected: false,
        ),
        const <Map<String, dynamic>>[],
      );
    }
    final activities = <Map<String, dynamic>>[];
    final stress = await _read(fail, 'day stress', () => repo.getDayStress(label), const <String, dynamic>{});
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
        : await _read(
            fail,
            'intraday stress projection',
            () => Isolate.run(() => projectIntradayStress(stored, stressSessions)),
            const <String, dynamic>{},
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
    // WHOOP strain and zone minutes of the day's last activity and of the
    // previous activity of the same type, from their own 1 Hz rows (one read
    // each; the session rows carry only the Banister headline).
    final recent = [for (final r in rows) r.cast<String, dynamic>()];
    if (activities.isNotEmpty) {
      Future<void> attach(Map<String, dynamic> a) async {
        try {
          final w = await repo.getWorkout(a['id'].toString());
          if (w['whoop_strain'] != null) a['whoop_strain'] = w['whoop_strain'];
          if (w['whoop_zone_min'] != null) a['whoop_zone_min'] = w['whoop_zone_min'];
        } catch (e) {
          fail('workout ${a['id']}', e);
        }
      }
      final last = activities.last;
      await attach(last);
      final lastStart = (last['start_ts'] as num?)?.toInt() ?? 0;
      for (final r in recent) {
        if (r['type'] != last['type'] || ((r['start_ts'] as num?)?.toInt() ?? 0) >= lastStart) continue;
        await attach(r);
        break;
      }
    }
    Map<String, dynamic> wear = const {};
    Map<String, dynamic> naps = const {};
    List<Map<String, Object?>> alarms = const [];
    try {
      wear = await repo.getDayWear(label);
    } catch (e) {
      fail('wear', e);
    }
    try {
      naps = await repo.getDayNaps(label);
    } catch (e) {
      fail('naps', e);
    }
    try {
      alarms = await LocalDb.alarmScheduleRows();
    } catch (e) {
      fail('alarm schedule', e);
    }
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
    // The night's HR: the sleep window usually starts the evening before, so
    // the curve is the tail of yesterday's day curve plus the head of today's.
    final nightSleep = await _read(fail, 'day sleep', () => repo.getDaySleepV2(label), const <String, dynamic>{});
    final nightHr = <Map<String, dynamic>>[];
    final onset = nightSleep['onset_ts'], wake = nightSleep['wake_ts'];
    if (onset is num && wake is num) {
      final prev = dayLabelOf(DateTime(date.year, date.month, date.day - 1));
      for (final d in [prev, label]) {
        try {
          final heart = await repo.getDayHeart(d);
          for (final e in heart['hr'] as List? ?? const []) {
            if (e is Map && e['t'] is num && (e['t'] as num) >= onset - 900 && (e['t'] as num) <= wake + 900) {
              nightHr.add(e.cast<String, dynamic>());
            }
          }
        } catch (e) {
          fail('night heart $d', e);
        }
      }
      nightHr.sort((a, b) => (a['t'] as num).compareTo(b['t'] as num));
    }
    return FamiliarData(
      home: home,
      health: health,
      activities: activities,
      sleep: nightSleep,
      intradayStress: intraday,
      recovery: recovery,
      strain: strain,
      steps: steps,
      day: label,
      age: age,
      whoopDay: whoopDay,
      series: series,
      sleepWindows: windows,
      journal: journal,
      journalInsights: journalInsights,
      nightHr: nightHr,
      batteryPct: batteryPct,
      charging: charging,
      wear: wear,
      naps: naps,
      alarmSchedule: alarms,
      recentSessions: recent,
      loadFailures: failures,
    );
  }
}

/// Run one reader of [FamiliarData.load]; on failure log the cause and return
/// [fallback] so the rest of the day still loads.
Future<T> _read<T>(void Function(String, Object) fail, String what, Future<T> Function() reader, T fallback) async {
  try {
    return await reader();
  } catch (e, st) {
    debugPrint('[familiar] $what failed: $e\n$st');
    fail(what, e);
    return fallback;
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
