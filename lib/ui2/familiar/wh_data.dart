// The read-only view the WHOOP screens draw from: every number is taken from
// FamiliarData (which itself only reads the repository) and turned into the
// shapes the widgets want. Nothing here invents a value — an absent input is a
// null, and every widget renders “—” for it.
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show BuildContext;

import 'package:personal_analytics/whoop_observations.dart';

import '../../data/day_label.dart';
import '../../state/prefs.dart';
import '../../state/alarm_schedule.dart';
import '../screens/home_screen.dart' show ChartPoint;
import '../screens/workout_screen.dart' show familiarActivityName;
import 'data.dart';
import 'wh_widgets.dart' show WhPlanGoal, ruMonthsGen;

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

/// Exactly [days] values from a chart series, oldest first: the [days]
/// calendar days before [end] when [excludeEnd], or the [days] days ending
/// at [end] itself otherwise. (It used to return [days] + 1 values with
/// [excludeEnd] false — one more than every week/month painter has labels
/// for, so those charts threw in paint on real data.)
List<double?> trailing(List<ChartPoint> pts, DateTime end, int days, {bool excludeEnd = true}) {
  final map = <String, double>{for (final p in pts) dayLabelOf(DateTime.fromMillisecondsSinceEpoch(p.t * 1000)): p.v};
  final first = excludeEnd ? days : days - 1, last = excludeEnd ? 1 : 0;
  return [for (var i = first; i >= last; i--) map[dayLabelOf(DateTime(end.year, end.month, end.day - i))]];
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
  // Band-first vitals (v8): the strap's own overnight SpO₂ estimate and the
  // nightly skin temperature in °C from the day's WHOOP block; a WHOOP export
  // fills the same tiles only when the band has nothing for the day.
  Map<String, dynamic> get bandSpo2 => _m(d.whoopDay['spo2']);
  Map<String, dynamic> get bandSkinTemp => _m(d.whoopDay['skin_temp']);
  Map<String, dynamic> get crossVitals => _m(whoop['vitals']);
  double? get spo2 => _n(bandSpo2['pct']) ?? _n(d.oxygenPercent);
  String? get spo2Source => _n(bandSpo2['pct']) != null ? 'band' : _n(d.oxygenPercent) != null ? 'import' : null;
  int? get spo2Samples => (bandSpo2['samples'] as num?)?.toInt();
  double? get tempC => _n(bandSkinTemp['c']) ?? _n(d.temperatureC);
  double? get tempDevC => _n(bandSkinTemp['dev_c']);

  /// 10–90 % band of the prior 30 nights for a cross-day vital key.
  WhRange? vitalRange(String key) {
    final v = _m(crossVitals[key]);
    final lo = _n(v['lo']), hi = _n(v['hi']), med = _n(v['median']);
    return lo == null || hi == null || med == null ? null : WhRange(lo, hi, med, (v['nights'] as num?)?.toInt() ?? 0);
  }
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
      row('temp', 'skin_temperature', 'Температура кожи', tempC, vitalRange('skin_temp_c'), '°C', digits: 1),
      row('rhr', 'rhr', 'Пульс в покое', rhr, rhrRange, 'уд/мин'),
      row('hrv', 'hrv', 'Вариабельность ритма', hrv, hrvRange, 'мс', higherBetter: true),
      row('spo2', 'heart_rate', 'Кислород в крови', spo2, vitalRange('spo2') ?? (spo2 == null ? null : const WhRange(94, 100, 97, 0)), '%'),
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

  // ── «Мой план»: the current Monday–Sunday week ──
  DateTime get planWeekStart => DateTime(date.year, date.month, date.day - (date.weekday - 1));
  int get planDaysLeft => 7 - date.weekday;
  String get planRange {
    final ws = planWeekStart, we = DateTime(ws.year, ws.month, ws.day + 6);
    return ws.month == we.month ? '${ws.day}–${we.day} ${ruMonthsGen[we.month - 1]}' : '${ws.day} ${ruMonthsGen[ws.month - 1]} – ${we.day} ${ruMonthsGen[we.month - 1]}';
  }

  /// WHO zone minutes for the week, nights at ≥ 85 % sleep performance and
  /// days with the step goal closed — from the stored series, today's values
  /// patched in when its series row is not written yet.
  List<WhPlanGoal> get planGoals {
    final days = date.weekday;
    List<double?> week(List<ChartPoint> pts, double? today) {
      final w = trailing(pts, date, days, excludeEnd: false);
      if (w.isNotEmpty && w.last == null && today != null) w[w.length - 1] = today;
      return w;
    }
    double sum(List<double?> w) => w.whereType<double>().fold(0.0, (a, b) => a + b);
    final z13 = sum(week(d.series['whoop_z13_min'] ?? const [], z13Today));
    final z45 = sum(week(d.series['whoop_z45_min'] ?? const [], z45Today));
    final nights = week(d.series['whoop_sleep_perf'] ?? const [], sleepPerf).where((x) => x != null && x >= 85).length;
    final stepDays = stepGoal <= 0 ? 0 : week(d.steps, steps).where((x) => x != null && x >= stepGoal).length;
    return [
      WhPlanGoal('Зоны 1–3', z13, 150, 'мин', 'trend-zones13'),
      WhPlanGoal('Зоны 4–5', z45, 75, 'мин', 'trend-zones45'),
      WhPlanGoal('Сон от 85 %', nights.toDouble(), 7, 'ночей', 'trend-sleepperf'),
      if (stepGoal > 0) WhPlanGoal('Цель по шагам', stepDays.toDouble(), 7, 'дней', 'trend-steps'),
    ];
  }

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
      final v = [for (final x in xs) ?x];
      return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    }

    final topFactor = ageFactors.isEmpty ? null : (ageFactors..sort((a, b) => (_n(b['years']) ?? 0).abs().compareTo((_n(a['years']) ?? 0).abs()))).first;
    // ── v8 inputs ──
    final pat = _m(whoop['patterns']);
    final recs = _m(whoop['records']);
    final zonesPrev = _m(whoop['zones_prev_week']);
    final zonesWeek = _m(whoop['zones_week']);
    final nowT = isToday ? DateTime.now() : DateTime(date.year, date.month, date.day, 21);
    // Lowest sleeping HR of the night from the night curve.
    double? nightMin;
    int? nightMinAt;
    for (final e in d.nightHr) {
      final v = (e['v'] as num?)?.toDouble(), t = (e['t'] as num?)?.toInt();
      if (v == null || t == null || v <= 0) continue;
      if (nightMin == null || v < nightMin) {
        nightMin = v;
        nightMinAt = minOfDay(t);
      }
    }
    final solVital = _m(crossVitals['sol_min']);
    // Band alarm: the next occurrence within 24 h, and this morning's alarm
    // against the measured wake time.
    final schedule = <AlarmScheduleEntry>[];
    for (final r in d.alarmSchedule) {
      try {
        schedule.add(AlarmScheduleEntry.fromRow(r));
      } catch (_) {}
    }
    final nextAlarm = schedule.isEmpty ? null : nextAlarmOccurrence(schedule, nowT);
    final alarmTomorrow = nextAlarm != null && nextAlarm.difference(nowT).inHours < 24 ? nextAlarm.hour * 60 + nextAlarm.minute : null;
    int? wokeBefore;
    if (wakeTs != null) {
      final w = DateTime.fromMillisecondsSinceEpoch(wakeTs! * 1000);
      for (final e in schedule) {
        if (!e.enabled || e.weekday + 1 != w.weekday) continue;
        final diff = e.hour * 60 + e.minute - (w.hour * 60 + w.minute);
        if (diff > 0 && diff <= 120) wokeBefore = diff;
      }
    }
    // Social jetlag: bedtimes of Friday/Saturday nights against the rest, on a
    // clock shifted by 12 h so midnight does not split the median.
    final weekendBeds = <double>[], weekdayBeds = <double>[];
    for (final w in d.sleepWindows) {
      final on = w['onset_ts'];
      if (on is! num) continue;
      final t = DateTime.fromMillisecondsSinceEpoch(on.toInt() * 1000);
      final evening = DateTime.fromMillisecondsSinceEpoch((on.toInt() - 43200) * 1000);
      final m = ((t.hour * 60 + t.minute + 720) % 1440).toDouble();
      (evening.weekday == DateTime.friday || evening.weekday == DateTime.saturday ? weekendBeds : weekdayBeds).add(m);
    }
    double? medianOf(List<double> xs) {
      if (xs.isEmpty) return null;
      final sorted = [...xs]..sort();
      return sorted[sorted.length ~/ 2];
    }
    final jetlag = weekendBeds.length >= 3 && weekdayBeds.length >= 5 ? medianOf(weekendBeds)! - medianOf(weekdayBeds)! : null;
    // Longest off-wrist gap after waking that ended before the last sync.
    double? gapMin;
    int? gapStart, gapEnd;
    {
      final wakeMin = wakeTs == null ? 8 * 60 : minOfDay(wakeTs)!;
      final syncMin = sinceSync == null ? null : nowT.hour * 60 + nowT.minute - sinceSync.inMinutes;
      for (final sgm in d.wear['segments'] as List? ?? const []) {
        if (sgm is! Map || sgm['on'] == true) continue;
        final st = (sgm['start'] as num?)?.toInt(), en = (sgm['end'] as num?)?.toInt();
        if (st == null || en == null) continue;
        final sm = minOfDay(st)!, em = minOfDay(en)!;
        if (sm < wakeMin) continue;
        if (isToday && syncMin != null && em > syncMin - 5) continue;
        final len = (en - st) / 60;
        if (gapMin == null || len > gapMin) {
          gapMin = len;
          gapStart = sm;
          gapEnd = em;
        }
      }
    }
    // HR ceiling used today against the previous rows' ceilings.
    final ceilingNow = _n(d.whoopDay['max_hr']);
    double? ceilingPrev;
    for (final w in weekRows) {
      if (w['date'] == d.day) continue;
      final v = _n(w['whoop_max_hr']);
      if (v != null && (ceilingPrev == null || v > ceilingPrev)) ceilingPrev = v;
    }
    // The day's last activity and the previous one of the same type.
    final last = d.activities.isEmpty ? null : d.activities.last;
    double? prevSame;
    if (last != null) {
      final lastStart = (last['start_ts'] as num?)?.toInt() ?? 0;
      for (final r in d.recentSessions) {
        if (r['type'] != last['type'] || ((r['start_ts'] as num?)?.toInt() ?? 0) >= lastStart) continue;
        prevSame = _n(r['whoop_strain']) ?? (last['whoop_strain'] == null ? _n(r['strain']) : null);
        break;
      }
    }
    List<double> zoneList(Object? z) {
      if (z is List && z.length == 5) return [for (final v in z) v is num ? v.toDouble() : 0.0];
      if (z is Map) return [for (var k = 1; k <= 5; k++) _n(z['z$k']) ?? _n(z['$k']) ?? 0];
      return const [];
    }
    final lastTitle = (last?['title'] as String?) ?? '';
    final lastName = last == null ? null : (lastTitle.isNotEmpty && lastTitle != last['type'] ? lastTitle : activityTypeRu(last['type']?.toString()));
    final lastEnd = last == null ? null : (last['end_ts'] as num?)?.toInt();
    final unlabeled = d.activities.where((a) {
      final t = (a['title'] as String?) ?? '';
      return (t.isEmpty || t == a['type']) && (a['type'] == null || a['type'] == 'other');
    }).length;
    var rest = 0;
    {
      final sessionDays = {for (final r in d.recentSessions) if (r['start_ts'] is num) dayLabelOf(DateTime.fromMillisecondsSinceEpoch((r['start_ts'] as num).toInt() * 1000))};
      var day = DateTime(date.year, date.month, date.day - 1);
      while (rest < 7 && !sessionDays.contains(dayLabelOf(day))) {
        rest++;
        day = DateTime(day.year, day.month, day.day - 1);
      }
    }
    final respHist = trailing(d.health.points('resp_rate'), date, 8, excludeEnd: false);
    var respStreak = 0;
    if (respRange != null) {
      for (var k = respHist.length - 1; k >= 0; k--) {
        final v = k == respHist.length - 1 ? resp : respHist[k];
        if (v == null || v <= respRange!.hi) break;
        respStreak++;
      }
    }
    final calSeries = trailing(d.series['calories'] ?? const [], date, 8, excludeEnd: false);
    final calPrev = [for (var k = 0; k < calSeries.length - 1; k++) ?calSeries[k]];
    final wd = _m(pat['weekday']);
    final wdIdx = (wd['weekday'] as num?)?.toInt();
    final monthly = _m(pat['monthly']);
    const wdNames = ['', 'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
    return ObservationInput(
      now: nowT,
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
      nightHrMin: nightMin,
      nightHrMinAtMinOfDay: nightMinAt,
      nightHrMinBaseline: vitalRange('sleeping_hr_nadir')?.median,
      latencyMin: solVital['date'] == d.day ? _n(solVital['value']) : null,
      latencyTypicalMin: _n(solVital['median']),
      napMin: _n(d.naps['nap_min']),
      inBedMin: inBedMin,
      alarmTomorrowMinOfDay: alarmTomorrow,
      wokeBeforeAlarmMin: wokeBefore,
      weekendBedShiftMin: jetlag,
      recordNights: (recs['nights'] as num?)?.toInt() ?? 0,
      sleepRecordPrevMax: _n(recs['tst_prev_max']),
      recoveryRecordPrevMax: _n(recs['readiness_prev_max']),
      restorativeRecordPrevMax: _n(recs['restorative_prev_max']),
      noNightData: isToday && tstMin == null && sinceSync != null && sinceSync.inMinutes <= 60 && nowT.hour >= 9,
      noNightReason: d.batteryPct != null && d.batteryPct! <= 5 ? 'Браслет разряжен' : 'Браслет не был на руке ночью или ночь ещё не рассчитана',
      wearGapMin: gapMin,
      wornMin: _n(d.wear['worn_min']),
      wearGapStartMinOfDay: gapStart,
      wearGapEndMinOfDay: gapEnd,
      maxHrNew: ceilingNow,
      maxHrPrev: ceilingPrev,
      lastActivityName: lastName,
      lastActivityStrain: last == null ? null : _n(last['whoop_strain']) ?? _n(last['strain']),
      lastActivityPrevStrain: prevSame,
      lastActivityAvgHr: last == null ? null : _n(last['avg_hr']),
      lastActivityMaxHr: last == null ? null : _n(last['max_hr']),
      lastActivityDurationMin: last == null ? null : _n(last['duration_min']),
      lastActivityZoneMin: last == null ? const [] : zoneList(last['whoop_zone_min'] ?? last['zone_min']),
      lastActivityEndMinOfDay: lastEnd == null ? null : minOfDay(lastEnd),
      z13WeekMin: _n(zonesWeek['z13_min']),
      z13PrevWeekMin: _n(zonesPrev['z13_min']),
      z45WeekMin: _n(zonesWeek['z45_min']),
      unlabeledActivities: unlabeled,
      rhrRisingDays: (pat['rhr_rising_days'] as num?)?.toInt() ?? 0,
      respAboveStreak: respStreak,
      restDays: rest,
      caloriesToday: _n(d.home.caloriesTotal.value) ?? (calSeries.isEmpty ? null : calSeries.last),
      caloriesWeekAvg: avgOf(calPrev),
      spo2Source: spo2Source,
      spo2Samples: spo2Samples,
      skinTempC: _n(bandSkinTemp['c']),
      skinTempDevC: tempDevC,
      hardDayRecovery: _n(pat['hard_day_recovery']),
      easyDayRecovery: _n(pat['easy_day_recovery']),
      patternDays: (pat['pattern_days'] as num?)?.toInt() ?? 0,
      weekdayLow: wdIdx == null || wdIdx < 1 || wdIdx > 7 ? null : wdNames[wdIdx],
      weekdayLowIndex: wdIdx,
      weekdayLowDelta: _n(wd['delta']),
      weekdayN: (wd['weeks'] as num?)?.toInt() ?? 0,
      hrvCv7: _n(pat['hrv_cv7']),
      hrvCv30: _n(pat['hrv_cv30']),
      ageDelta30: _n(monthly['delta_years']),
      ageTopChangeFactor: monthly['top_factor'] == null ? null : ageFactorName(monthly['top_factor'].toString()),
      ageTopChangeYears: _n(monthly['top_factor_years']),
      unifiedMorning: Prefs.getBool('familiar.obs.unified', true),
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

/// A session row's name for the lists: its own title unless that is just the
/// type code, else the catalogue's localized name, else the Russian type name
/// (a bare code such as RUN never reaches the screen).
String activityRowName(BuildContext c, Map<String, dynamic> row) {
  final title = (row['title'] as String?) ?? '', type = row['type']?.toString();
  if (title.isNotEmpty && title != type) return title;
  final loc = familiarActivityName(c, type);
  return loc.toLowerCase() == (type ?? '').toLowerCase() || loc == 'Workout' ? activityTypeRu(type) : loc;
}

/// Russian name of an activity type code (session rows store the code).
String activityTypeRu(String? type) => switch (type) {
  'run' || 'running' => 'Бег',
  'walk' || 'walking' => 'Ходьба',
  'cycle' || 'cycling' || 'bike' => 'Велосипед',
  'strength' || 'weightlifting' || 'gym' => 'Силовая',
  'swim' || 'swimming' => 'Плавание',
  'hike' || 'hiking' => 'Поход',
  'yoga' => 'Йога',
  'hiit' => 'HIIT',
  'football' || 'soccer' => 'Футбол',
  'basketball' => 'Баскетбол',
  'tennis' => 'Теннис',
  'rowing' => 'Гребля',
  'elliptical' => 'Эллипс',
  'other' || null => 'Активность',
  _ => type,
};

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

/// Observations that never throw into a widget build: a rule tripping over an
/// unexpected value logs and yields an empty feed for the day.
List<Observation> safeObservations(WhView v, {Duration? sinceSync}) {
  try {
    return v.observations(sinceSync: sinceSync);
  } catch (e, st) {
    debugPrint('[familiar] observations failed: $e\n$st');
    return const [];
  }
}

List<Observation> safeAllObservations(WhView v, {Duration? sinceSync}) {
  try {
    return v.allObservations(sinceSync: sinceSync);
  } catch (e, st) {
    debugPrint('[familiar] observations failed: $e\n$st');
    return const [];
  }
}

const _dismissKey = 'familiar.obs.dismissed';
Set<String> dismissedObservations() => {for (final s in Prefs.getString(_dismissKey, '').split(';')) if (s.isNotEmpty) s};
void dismissObservation(String id) {
  final all = dismissedObservations().toList()..add(id);
  Prefs.setString(_dismissKey, all.length > 300 ? all.sublist(all.length - 300).join(';') : all.join(';'));
}
