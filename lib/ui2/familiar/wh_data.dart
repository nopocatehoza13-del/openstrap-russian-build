// The read-only view the WHOOP screens draw from: every number is taken from
// FamiliarData (which itself only reads the repository) and turned into the
// shapes the widgets want. Nothing here invents a value — an absent input is a
// null, and every widget renders “—” for it.
import 'dart:math' as math;

import 'package:personal_analytics/whoop_observations.dart';

import '../../data/day_label.dart';
import '../../state/prefs.dart';
import '../screens/home_screen.dart' show ChartPoint;
import 'data.dart';

double? _n(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
Map<String, dynamic> _m(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

/// A personal range: 10th–90th percentile and median over a dated series.
class WhRange {
  final double lo, hi, median;
  final int n;
  const WhRange(this.lo, this.hi, this.median, this.n);
  bool inside(double v) => v >= lo && v <= hi;
}

WhRange? rangeOf(Iterable<double?> values, {int minN = 5}) {
  final xs = [for (final v in values) if (v != null && v.isFinite) v]..sort();
  if (xs.length < minN) return null;
  double q(double p) {
    final pos = (xs.length - 1) * p;
    final i = pos.floor();
    final f = pos - i;
    return i + 1 < xs.length ? xs[i] + (xs[i + 1] - xs[i]) * f : xs[i];
  }

  return WhRange(q(.1), q(.9), q(.5), xs.length);
}

/// Values of the last [days] calendar days before [end] (exclusive of [end]
/// when [excludeEnd]) from a chart series.
List<double?> trailing(List<ChartPoint> pts, DateTime end, int days, {bool excludeEnd = true}) {
  final map = <String, double>{for (final p in pts) dayLabelOf(DateTime.fromMillisecondsSinceEpoch(p.t * 1000)): p.v};
  return [for (var i = days; i >= (excludeEnd ? 1 : 0); i--) map[dayLabelOf(DateTime(end.year, end.month, end.day - i))]];
}

String dirOf(num? now, num? prev, {bool lowerBetter = false, double eps = 0}) {
  if (now == null || prev == null) return 'eq';
  final d = now - prev;
  if (d.abs() <= eps) return 'eq';
  return (d > 0) != lowerBetter ? 'up' : 'dn';
}

/// Everything the Familiar screens show for one day.
class WhView {
  final FamiliarData d;
  final DateTime date;
  WhView(this.d, this.date);

  bool get isToday => dayLabelOf(date) == todayLabel();

  // ── cross-day WHOOP block ──
  Map<String, dynamic> get whoop => d.whoop;
  Map<String, dynamic> get need => _m(whoop['need']);
  Map<String, dynamic> get lastNight => _m(whoop['last_night']);
  Map<String, dynamic> get lastPerf => _m(lastNight['performance']);
  Map<String, dynamic> get lastNeed => _m(lastNight['need']);
  Map<String, dynamic> get levels => _m(lastPerf['levels']);
  Map<String, dynamic> get whoopRecovery => _m(whoop['recovery']);
  Map<String, dynamic> get whoopAge => _m(whoop['age']);
  List<Map<String, dynamic>> get week => [for (final r in whoop['week'] as List? ?? const []) _m(r)];

  // ── headline scores ──
  /// WHOOP-formula recovery when the rollup has it for this day, else the
  /// OpenStrap readiness for the day being viewed.
  double? get recovery {
    final r = whoopRecovery;
    if (isToday && r['date'] == d.day && r['score'] is num) return _n(r['score']);
    return _n(d.home.readiness.value);
  }

  bool get recoveryIsWhoop => isToday && whoopRecovery['date'] == d.day && whoopRecovery['score'] is num;

  double? get strain => _n(d.whoopDay['strain']) ?? _n(d.home.strain.value);
  bool get strainIsWhoop => d.whoopDay['strain'] is num;
  Map<String, dynamic> get zonesToday => _m(d.whoopDay['zones']);
  double? zoneMin(int z) => _n(zonesToday['z$z']);
  double? get z13Today => zoneMin(1) == null && zoneMin(2) == null && zoneMin(3) == null ? null : (zoneMin(1) ?? 0) + (zoneMin(2) ?? 0) + (zoneMin(3) ?? 0);
  double? get z45Today => zoneMin(4) == null && zoneMin(5) == null ? null : (zoneMin(4) ?? 0) + (zoneMin(5) ?? 0);
  List<Map<String, dynamic>> get strainCurve => [for (final e in d.whoopDay['strain_curve'] as List? ?? const []) _m(e)];
  List<double>? get zoneLower => d.whoopDay['zone_lower_bpm'] is List ? [for (final v in d.whoopDay['zone_lower_bpm'] as List) (v as num).toDouble()] : null;

  (double, double)? get strainTarget {
    final t = d.home.strainTarget;
    final lo = _n(t?['target_min']), hi = _n(t?['target_max']);
    return lo == null || hi == null ? null : (lo, hi);
  }

  /// Sleep performance for the viewed night: the WHOOP-formula one when the
  /// rollup's last night IS this day, else hours ÷ need.
  double? get sleepPerf {
    if (lastNight['date'] == d.day && lastPerf['performance_pct'] is num) return _n(lastPerf['performance_pct']);
    return hoursVsNeed;
  }

  bool get sleepPerfIsWhoop => lastNight['date'] == d.day && lastPerf['performance_pct'] is num;
  double? get tstMin => _n(d.sleep['duration_min']) ?? _n(d.home.sleepMin.value);
  double? get inBedMin => _n(d.sleep['in_bed_min']);
  double? get awakeMin => _n(d.sleep['awake_min']);
  double? get efficiencyPct => _n(lastPerf['efficiency_pct']) ?? (_n(d.sleep['efficiency']) == null ? null : _n(d.sleep['efficiency'])! * 100);
  double? get needMin => lastNight['date'] == d.day && lastNeed['need_sec'] is num ? _n(lastNeed['need_sec'])! / 60 : _n(d.home.sleepNeedMin.value);
  double? get hoursVsNeed {
    if (lastNight['date'] == d.day && lastPerf['hours_vs_need_pct'] is num) return _n(lastPerf['hours_vs_need_pct']);
    final t = tstMin, n = needMin;
    return t == null || n == null || n <= 0 ? null : (t / n * 100).clamp(0, 100).toDouble();
  }

  double? get consistency => lastNight['date'] == d.day ? _n(lastPerf['consistency_pct']) : null;
  double? get sleepStressPct => lastNight['date'] == d.day ? _n(lastPerf['high_stress_pct']) : null;
  int levelOf(String k) => levels[k] is num ? (levels[k] as num).toInt() : -1;
  int get sleepPerfLevel => sleepPerf == null ? -1 : sleepPerf! >= 85 ? 2 : sleepPerf! >= 70 ? 1 : 0;

  double? get lightMin => _n(d.sleep['light_min']);
  double? get deepMin => _n(d.sleep['deep_min']);
  double? get remMin => _n(d.sleep['rem_min']);
  double? get restorativeMin => deepMin == null && remMin == null ? null : (deepMin ?? 0) + (remMin ?? 0);
  int? get onsetTs => (d.sleep['onset_ts'] as num?)?.toInt();
  int? get wakeTs => (d.sleep['wake_ts'] as num?)?.toInt();
  int? get wakeEvents {
    final v = d.sleep['awakenings'] ?? d.sleep['wake_events'];
    return v is num ? v.toInt() : null;
  }

  // tonight
  double? get needTonightMin => _n(need['need_sec']) == null ? null : _n(need['need_sec'])! / 60;
  double? get baselineMin => _n(need['baseline_sec']) == null ? null : _n(need['baseline_sec'])! / 60;
  double? get strainAddTonightMin => _n(need['strain_add_sec']) == null ? null : _n(need['strain_add_sec'])! / 60;
  double? get debtTonightMin => _n(need['debt_sec']) == null ? null : _n(need['debt_sec'])! / 60;
  double? get debtOutstandingMin => _n(whoop['debt_outstanding_sec']) == null ? null : _n(whoop['debt_outstanding_sec'])! / 60;
  String? get baselineSource => need['baseline_source'] as String?;
  int get wakePrefMin => Prefs.getInt('familiar.wakeMinute', -1);
  int get sleepGoalPct => Prefs.getInt('familiar.sleepGoal', 100);

  // ── vitals + ranges ──
  double? get hrv => _n(d.health.hrv.value);
  double? get rhr => _n(d.home.rhr.value);
  double? get resp => _n(d.health.resp.value);
  double? get spo2 => _n(d.oxygenPercent);
  double? get tempC => _n(d.temperatureC);
  WhRange? get hrvRange => rangeOf(trailing(d.health.points('hrv'), date, 30));
  WhRange? get rhrRange => rangeOf(trailing(d.health.points('resting_hr'), date, 30));
  WhRange? get respRange => rangeOf(trailing(d.health.points('resp_rate'), date, 30));
  WhRange? get sleepRange => rangeOf(trailing(d.health.points('sleep'), date, 30));
  WhRange? get stepsRange => rangeOf(trailing(d.steps, date, 30));
  WhRange? get strainRange => rangeOf(trailing(d.strain, date, 30));
  WhRange? rangeOfKey(String key) => rangeOf(trailing(d.series[key] ?? const [], date, 30));

  /// The 30-day range for a series key as the trend screen names it.
  WhRange? rangeOf30(String key) => switch (key) {
    'hrv' => hrvRange,
    'resting_hr' => rhrRange,
    'resp_rate' => respRange,
    'sleep' => sleepRange,
    'steps' => stepsRange,
    _ => rangeOfKey(key),
  };
  double? get steps => _n(d.home.steps.value);
  int get stepGoal => d.home.stepGoal;

  /// Health-monitor status per metric: (label, value string, unit, level 2 ok /
  /// 1 outside / -1 absent, range text).
  List<({String key, String icon, String label, double? value, String unit, int level, String range})> get monitor {
    ({String key, String icon, String label, double? value, String unit, int level, String range}) row(String key, String icon, String label, double? v, WhRange? r, String unit, {int digits = 0, bool higherBetter = false}) {
      var lvl = -1;
      var range = 'нет нормы';
      if (r != null) {
        range = '${r.lo.toStringAsFixed(digits).replaceAll('.', ',')}–${r.hi.toStringAsFixed(digits).replaceAll('.', ',')}';
        if (v != null) lvl = r.inside(v) || (higherBetter && v > r.hi) || (!higherBetter && key == 'rhr' && v < r.lo) ? 2 : 1;
      } else if (v != null) {
        lvl = 2;
        range = 'норма копится';
      }
      if (v == null) lvl = -1;
      return (key: key, icon: icon, label: label, value: v, unit: unit, level: lvl, range: range);
    }

    return [
      row('resp', 'respiratory_rate', 'Частота дыхания', resp, respRange, '/мин', digits: 1),
      row('temp', 'skin_temperature', 'Температура кожи', tempC, null, '°C', digits: 1),
      row('rhr', 'rhr', 'Пульс в покое', rhr, rhrRange, 'уд/мин'),
      row('hrv', 'hrv', 'Вариабельность ритма', hrv, hrvRange, 'мс', higherBetter: true),
      row('spo2', 'heart_rate', 'Кислород в крови', spo2, rangeOf(const <double?>[]) ?? (spo2 == null ? null : const WhRange(94, 100, 97, 0)), '%'),
    ];
  }

  int get monitorTotal => monitor.length;
  int get monitorInRange => monitor.where((m) => m.level == 2).length;
  int get monitorMeasured => monitor.where((m) => m.level >= 0).length;

  // ── stress ──
  Map<String, dynamic> get stressModel => d.intradayStress;
  List<Map<String, dynamic>> get stressPoints => [for (final v in stressModel['points'] as List? ?? const []) if (v is Map) v.cast<String, dynamic>()];
  Map<String, dynamic> stressSummary(String scope) => _m(_m(stressModel['summaries'])[scope]);
  double? get stressNow {
    for (final p in stressPoints.reversed) {
      final v = _n(p['all']);
      if (v != null) return v;
    }
    return null;
  }

  int? get stressNowTs {
    for (final p in stressPoints.reversed) {
      if (p['all'] is num) return (p['t'] as num?)?.toInt();
    }
    return null;
  }

  double? stressMin(String scope, String band) {
    final s = stressSummary(scope)['${band}_sec'];
    return s is num ? s / 60 : null;
  }

  /// Longest run of ≥ 2.0 in the all-day series: (start epoch sec, minutes).
  (int, double)? get longestHigh {
    int? bestStart;
    var bestLen = 0.0;
    int? runStart;
    var runLen = 0.0;
    for (final p in stressPoints) {
      final v = _n(p['all']);
      final t = (p['t'] as num?)?.toInt();
      final e = (p['end'] as num?)?.toInt();
      if (v != null && v >= 2 && t != null) {
        runStart ??= t;
        runLen += e != null ? (e - t) / 60 : 5;
        if (runLen > bestLen) {
          bestLen = runLen;
          bestStart = runStart;
        }
      } else {
        runStart = null;
        runLen = 0;
      }
    }
    return bestStart == null ? null : (bestStart, bestLen);
  }

  // ── healthspan ──
  double? get age => _n(whoopAge['whoop_age']);
  double? get chrono => _n(whoopAge['chronological']) ?? _n(d.health.profile['age']);
  double? get pace => _n(whoop['pace_of_aging']);
  List<Map<String, dynamic>> get ageFactors => [for (final f in whoopAge['factors'] as List? ?? const []) _m(f)];
  List<String> get ageMissing => [for (final k in whoopAge['missing'] as List? ?? const []) k.toString()];

  // ── journal ──
  Set<String> get journalDays => {for (final r in d.journal) if (r['date'] is String) r['date'] as String};
  bool get journalDoneToday => journalDays.contains(todayLabel());
  int get journalStreak {
    var n = 0;
    var day = DateTime.now();
    if (!journalDays.contains(dayLabelOf(day))) day = DateTime(day.year, day.month, day.day - 1);
    while (journalDays.contains(dayLabelOf(day))) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return n;
  }

  List<JournalEffect> get journalEffects => [
    for (final e in d.journalInsights['insights'] as List? ?? const [])
      if (e is Map && e['tag'] is String && e['delta'] is num)
        JournalEffect(e['tag'] as String, (e['delta'] as num).toDouble(), (e['n'] as num?)?.toInt() ?? 0, metric: e['outcome'] == 'efficiency' ? 'sleep' : 'recovery'),
  ];

  // ── observations ──
  ObservationInput observationInput({Duration? sinceSync}) {
    final rec7 = trailing(d.recovery, date, 7, excludeEnd: false);
    if (recovery != null) rec7[rec7.length - 1] = recovery;
    final hrvHist = trailing(d.health.points('hrv'), date, 8, excludeEnd: false);
    final r = hrvRange;
    int streak(bool Function(double) test) {
      var n = 0;
      for (var i = hrvHist.length - 1; i >= 0; i--) {
        final v = i == hrvHist.length - 1 ? hrv : hrvHist[i];
        if (v == null || !test(v)) break;
        n++;
      }
      return n;
    }

    final lh = longestHigh;
    int? minOfDay(int? ts) {
      if (ts == null) return null;
      final t = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      return t.hour * 60 + t.minute;
    }

    final bedMins = [for (final w in d.sleepWindows) if (w['onset_ts'] is num) minOfDay((w['onset_ts'] as num).toInt())!.toDouble()];
    double? typicalBed;
    if (bedMins.length >= 5) {
      // circular median around midnight: shift by 12 h
      final shifted = [for (final m in bedMins) (m + 720) % 1440]..sort();
      typicalBed = (shifted[shifted.length ~/ 2] - 720 + 1440) % 1440;
    }
    final outside = [for (final m in monitor) if (m.level == 1) '${m.label.toLowerCase()} ${m.value!.toStringAsFixed(m.key == 'resp' || m.key == 'temp' ? 1 : 0).replaceAll('.', ',')} ${m.unit} при норме ${m.range}'];
    final rest30 = rangeOfKey('rem');
    final deep30 = rangeOfKey('deep');
    final weekRows = week;
    double? avgOf(Iterable<double?> xs) {
      final v = [for (final x in xs) if (x != null) x];
      return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    }

    final topFactor = ageFactors.isEmpty ? null : (ageFactors..sort((a, b) => (_n(b['years']) ?? 0).abs().compareTo((_n(a['years']) ?? 0).abs()))).first;
    return ObservationInput(
      now: isToday ? DateTime.now() : DateTime(date.year, date.month, date.day, 21),
      today: isToday,
      recovery: recovery,
      hrv: hrv,
      hrvLo: r?.lo,
      hrvHi: r?.hi,
      hrvBaseline: r?.median,
      hrvAboveStreak: r == null ? 0 : streak((v) => v > r.hi),
      hrvBelowStreak: r == null ? 0 : streak((v) => v < r.lo),
      rhr: rhr,
      rhrBaseline: rhrRange?.median,
      rhrLo: rhrRange?.lo,
      rhrHi: rhrRange?.hi,
      resp: resp,
      respLo: respRange?.lo,
      respHi: respRange?.hi,
      spo2: spo2,
      spo2Lo: spo2 == null ? null : 94,
      recovery7: rec7,
      sleepPerf: sleepPerf,
      hoursVsNeed: hoursVsNeed,
      consistency: consistency,
      efficiency: efficiencyPct,
      sleepStressPct: sleepStressPct,
      tstMin: tstMin,
      needMin: needMin,
      needTonightMin: needTonightMin,
      baselineMin: baselineMin,
      debtTonightMin: debtTonightMin,
      strainAddMin: strainAddTonightMin,
      debtOutstandingMin: debtOutstandingMin,
      wakeEvents: wakeEvents,
      awakeMin: awakeMin,
      bedMinOfDay: minOfDay(onsetTs)?.toDouble(),
      typicalBedMinOfDay: typicalBed,
      wakeMinOfDay: wakePrefMin >= 0 ? wakePrefMin.toDouble() : minOfDay(wakeTs)?.toDouble(),
      restorativeMin: restorativeMin,
      restorativeBaselineMin: rest30 == null || deep30 == null ? null : rest30.median + deep30.median,
      baselineSource: baselineSource,
      nightsForBaseline: (_m(whoop['baseline'])['nights'] as num?)?.toInt(),
      strain: strain,
      targetLo: strainTarget?.$1,
      targetHi: strainTarget?.$2,
      z13TodayMin: z13Today,
      z13WeekAvgMin: avgOf(weekRows.map((w) => _n(w['whoop_z13_min']))),
      z45TodayMin: z45Today,
      z45WeekAvgMin: avgOf(weekRows.map((w) => _n(w['whoop_z45_min']))),
      steps: steps?.round(),
      stepGoal: stepGoal,
      activities: d.activities.length,
      activityStrainMax: d.activities.isEmpty ? null : d.activities.map((a) => _n(a['whoop_strain']) ?? _n(a['strain']) ?? 0).reduce(math.max),
      stressNow: stressNow,
      highStressMin: stressMin('all', 'high'),
      mediumStressMin: stressMin('all', 'medium'),
      lowStressMin: stressMin('all', 'low'),
      longestHighStartMinOfDay: lh == null ? null : minOfDay(lh.$1),
      longestHighDurMin: lh?.$2,
      monitorInRange: monitorInRange,
      monitorTotal: monitorMeasured,
      monitorOutside: outside,
      whoopAge: age,
      chronoAge: chrono,
      pace: pace,
      topFactor: topFactor == null ? null : ageFactorName(topFactor['key']?.toString() ?? ''),
      topFactorYears: topFactor == null ? null : _n(topFactor['years']),
      journalEffects: journalEffects,
      journalStreak: journalStreak,
      journalDoneToday: journalDoneToday,
      journalTracked: d.journal.isNotEmpty,
      batteryPct: d.batteryPct,
      charging: d.charging,
      sinceSync: sinceSync,
    );
  }

  /// Observations minus the dismissed ones, highest priority first.
  List<Observation> observations({Duration? sinceSync}) {
    final all = buildObservations(observationInput(sinceSync: sinceSync));
    final gone = dismissedObservations();
    return [for (final o in all) if (!gone.contains(o.id)) o];
  }

  List<Observation> allObservations({Duration? sinceSync}) => buildObservations(observationInput(sinceSync: sinceSync));
}

String ageFactorName(String key) => switch (key) {
  'sleep_hours' => 'часы сна',
  'sleep_consistency' => 'регулярность сна',
  'steps' => 'шаги',
  'zones_1_3' => 'зоны 1–3',
  'zones_4_5' => 'зоны 4–5',
  'strength' => 'силовые',
  'vo2max' => 'VO₂ max',
  'resting_hr' => 'пульс в покое',
  'lean_mass' => 'безжировая масса',
  _ => key,
};

const _dismissKey = 'familiar.obs.dismissed';
Set<String> dismissedObservations() => {for (final s in Prefs.getString(_dismissKey, '').split(';')) if (s.isNotEmpty) s};
void dismissObservation(String id) {
  final all = dismissedObservations().toList()..add(id);
  Prefs.setString(_dismissKey, all.length > 300 ? all.sublist(all.length - 300).join(';') : all.join(';'));
}
