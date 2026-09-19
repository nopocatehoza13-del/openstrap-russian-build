import 'dart:math' as math;

/// Experimental HR activation, not a WHOOP implementation or emotion detector.
/// All spans are half-open epoch seconds. No assumed 24-hour day or waking hours.
typedef StressSpan = ({int start, int end});

bool _inside(int t, List<StressSpan> spans) =>
    spans.any((s) => t >= s.start && t < s.end);

/// One minute requires >=30 distinct seconds with BOTH HR and observed motion.
/// A missing motion value is not stillness. Conflicting duplicate seconds are
/// discarded, making replay and input order irrelevant.
List<Map<String, dynamic>> stressMinutes({
  required List<int> timestamps,
  required List<int> hr,
  required List<bool?> moving,
  required int start,
  required int end,
  List<StressSpan> excluded = const [],
}) {
  if (timestamps.length != hr.length || hr.length != moving.length) {
    throw ArgumentError('Stress input arrays must have equal lengths');
  }
  final seconds = <int, (int, bool)>{}, conflicts = <int>{};
  for (var i = 0; i < timestamps.length; i++) {
    final t = timestamps[i], h = hr[i], m = moving[i];
    if (t < start ||
        t >= end ||
        h < 25 ||
        h > 230 ||
        m == null ||
        _inside(t, excluded) ||
        conflicts.contains(t)) {
      continue;
    }
    final value = (h, m), previous = seconds[t];
    if (previous != null && previous != value) {
      seconds.remove(t);
      conflicts.add(t);
    } else {
      seconds[t] = value;
    }
  }
  final groups = <int, List<(int, bool)>>{};
  for (final e in seconds.entries) {
    (groups[start + ((e.key - start) ~/ 60) * 60] ??= []).add(e.value);
  }
  final keys = groups.keys.toList()..sort();
  return [
    for (final t in keys)
      if (groups[t]!.length >= 30)
        {
          't': t,
          'n': groups[t]!.length,
          'hr': groups[t]!.fold<int>(0, (s, v) => s + v.$1) / groups[t]!.length,
          'motion': groups[t]!.where((s) => s.$2).length / groups[t]!.length,
        },
  ];
}

double _quantile(List<double> sorted, double q) {
  final p = (sorted.length - 1) * q, lo = p.floor(), hi = p.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (p - lo);
}

/// Retained minute features make session corrections possible even after raw
/// retention. This SAME function is used in derivation and off-isolate display
/// projection; the latter replaces only the workout intervals, never the data.
Map<String, dynamic> scoreIntradayStress({
  required List<Map<String, dynamic>> minutes,
  required int start,
  required int end,
  required int observedUntil,
  List<StressSpan> sleep = const [],
  List<StressSpan> workouts = const [],
}) {
  if (end <= start || end - start > 26 * 3600) {
    throw ArgumentError('Expected one local calendar day');
  }
  final until = observedUntil.clamp(start, end);
  // Reject malformed persisted features; never make invalid values plausible.
  final valid = <int, Map<String, dynamic>>{};
  for (final m in minutes) {
    final t = m['t'], n = m['n'], h = m['hr'], movement = m['motion'];
    if (t is! int ||
        n is! int ||
        h is! num ||
        movement is! num ||
        t < start ||
        t + 60 > until ||
        (t - start) % 60 != 0 ||
        n < 30 ||
        n > 60 ||
        !h.isFinite ||
        h < 25 ||
        h > 230 ||
        !movement.isFinite ||
        movement < 0 ||
        movement > 1) {
      continue;
    }
    valid[t] = m;
  }
  final rows = valid.values.toList()
    ..sort((a, b) => (a['t'] as int).compareTo(b['t'] as int));
  bool asleep(Map m) => _inside((m['t'] as int) + 30, sleep);
  bool active(Map m) =>
      _inside((m['t'] as int) + 30, workouts) || (m['motion'] as num) >= .2;
  final quiet = rows.where((m) => !asleep(m) && !active(m)).toList();
  // A short quiet sample must not appear as an established personal reference.
  final hours = quiet.map((m) => ((m['t'] as int) - start) ~/ 3600).toSet();
  final adequate = quiet.length >= 60 && hours.length >= 3;
  final quietHr = quiet.map((m) => (m['hr'] as num).toDouble()).toList()
    ..sort();
  final reference = adequate ? _quantile(quietHr, .25) : null;
  // 5 bpm is a MODEL scale floor, not a fabricated measurement/baseline.
  final scale = adequate
      ? math.max(
          5.0,
          (_quantile(quietHr, .75) - _quantile(quietHr, .25)) / 1.349,
        )
      : null;
  final totals = {
    for (final scope in ['all', 'rest', 'sleep']) scope: _Total(),
  };
  final points = <Map<String, dynamic>>[];
  final grouped = <int, List<Map<String, dynamic>>>{};
  for (final m in rows) {
    final t = m['t'] as int;
    (grouped[start + ((t - start) ~/ 300) * 300] ??= []).add(m);
  }
  int? lastActiveEnd;
  for (var t = start; t < end; t += 300) {
    final group = grouped[t] ?? const <Map<String, dynamic>>[];
    final values = {
      for (final scope in ['all', 'rest', 'sleep']) scope: _Total(),
    };
    for (final m in group) {
      final time = m['t'] as int, isActive = active(m), isSleep = asleep(m);
      if (isActive) lastActiveEnd = time + 60;
      if (!adequate || group.length < 4) continue;
      final h = (m['hr'] as num).toDouble(), n = m['n'] as int;
      final score =
          3 / (1 + math.exp(-((h - reference!) / scale!).clamp(-20.0, 20.0)));
      values['all']!.add(score, n);
      // Exclude post-exercise elevated HR from the non-activity interpretation.
      final recovering =
          lastActiveEnd != null &&
          time - lastActiveEnd < 1800 &&
          h > reference + 8;
      if (isSleep && !isActive) values['sleep']!.add(score, n);
      if (!isSleep && !isActive && !recovering) values['rest']!.add(score, n);
    }
    points.add({
      't': t,
      'end': math.min(t + 300, end),
      for (final e in values.entries) e.key: e.value.mean,
    });
    for (final e in values.entries) {
      totals[e.key]!.merge(e.value);
    }
  }
  return {
    'model': 'experimental_hr_activation_v1',
    'scale_max': 3,
    'start': start,
    'end': end,
    'observed_until': until,
    'reference_bpm': reference,
    'scale_bpm': scale,
    'reference_minutes': quiet.length,
    'reference_hours': hours.length,
    'status': rows.isEmpty
        ? 'no_samples'
        : adequate
        ? 'ready'
        : 'need_quiet_reference',
    'points': points,
    'summaries': {for (final e in totals.entries) e.key: e.value.json()},
    'minute_features': rows,
    'sleep_spans': [
      for (final s in sleep) [s.start, s.end],
    ],
    'workout_spans': [
      for (final s in workouts) [s.start, s.end],
    ],
  };
}

class _Total {
  int n = 0, low = 0, medium = 0, high = 0;
  double sum = 0;
  double? get mean => n == 0 ? null : sum / n;
  void add(double value, int seconds) {
    n += seconds;
    sum += value * seconds;
    if (value < 1) {
      low += seconds;
    } else if (value < 2) {
      medium += seconds;
    } else {
      high += seconds;
    }
  }

  void merge(_Total x) {
    n += x.n;
    sum += x.sum;
    low += x.low;
    medium += x.medium;
    high += x.high;
  }

  Map<String, dynamic> json() => {
    'mean': mean,
    'covered_sec': n,
    'low_sec': n == 0 ? null : low,
    'medium_sec': n == 0 ? null : medium,
    'high_sec': n == 0 ? null : high,
  };
}
