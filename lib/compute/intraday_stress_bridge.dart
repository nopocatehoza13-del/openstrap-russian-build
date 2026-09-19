// Orchestration only. The metric lives in the separate personal_analytics package.
import 'package:openstrap_analytics/onehz.dart' as ana;
import 'package:personal_analytics/intraday_stress.dart';
import 'substrate.dart';

List<StressSpan> stressWorkoutSpans(
  List<Map<String, dynamic>> sessions,
  int until,
) => [
  for (final s in sessions)
    if (s['start_ts'] is num && (s['end_ts'] is num || s['status'] == 'live'))
      (
        start: (s['start_ts'] as num).toInt(),
        end: (s['end_ts'] as num?)?.toInt() ?? until,
      ),
];

Map<String, dynamic> deriveIntradayStress({
  required Substrate substrate,
  required int start,
  required int end,
  required int observedUntil,
  required Map<String, dynamic> sleepPeriods,
  required List<Map<String, dynamic>> sessions,
  required List<List<int>> wristOff,
  required List<List<int>> charging,
}) {
  final s = substrate;
  final motion = List<bool?>.filled(s.length, null);
  final hr = [
    for (var i = 0; i < s.length; i++) s.hrValidAt(i) == false ? 0 : s.hr[i],
  ];
  for (var i = 1; i < s.length; i++) {
    if (s.tsSec[i] - s.tsSec[i - 1] != 1 ||
        !s.accelPresentAt(i) ||
        !s.accelPresentAt(i - 1)) {
      continue;
    }
    motion[i] =
        (ana.zAngle(s.ax[i], s.ay[i], s.az[i]) -
                ana.zAngle(s.ax[i - 1], s.ay[i - 1], s.az[i - 1]))
            .abs() >
        5;
  }
  final minutes = stressMinutes(
    timestamps: s.tsSec,
    hr: hr,
    moving: motion,
    start: start,
    end: end,
    excluded: [
      for (final p in [...wristOff, ...charging])
        if (p.length == 2) (start: p[0], end: p[1]),
    ],
  );
  return scoreIntradayStress(
    minutes: minutes,
    start: start,
    end: end,
    observedUntil: observedUntil,
    sleep: [
      for (final p in (sleepPeriods['periods'] as List? ?? const []))
        if (p is Map && p['onset_ts'] is num && p['wake_ts'] is num)
          (
            start: (p['onset_ts'] as num).toInt(),
            end: (p['wake_ts'] as num).toInt(),
          ),
    ],
    workouts: stressWorkoutSpans(sessions, observedUntil),
  );
}

/// Pure re-projection after a user adds/removes/retimes an activity. Uses only
/// retained measured features; run off-isolate, never on the repository read seam.
Map<String, dynamic> projectIntradayStress(
  Map<String, dynamic> stored,
  List<Map<String, dynamic>> sessions,
) {
  if (stored['model'] != 'experimental_hr_activation_v1') return const {};
  final start = stored['start'],
      end = stored['end'],
      until = stored['observed_until'];
  if (start is! int ||
      end is! int ||
      until is! int ||
      end <= start ||
      end - start > 26 * 3600 ||
      stored['minute_features'] is! List ||
      stored['sleep_spans'] is! List) {
    return const {};
  }
  return scoreIntradayStress(
    minutes: [
      for (final m in (stored['minute_features'] as List? ?? const []))
        if (m is Map) m.cast<String, dynamic>(),
    ],
    start: (stored['start'] as num).toInt(),
    end: (stored['end'] as num).toInt(),
    observedUntil: (stored['observed_until'] as num).toInt(),
    sleep: [
      for (final p in (stored['sleep_spans'] as List? ?? const []))
        if (p is List && p.length == 2 && p[0] is int && p[1] is int)
          (start: (p[0] as num).toInt(), end: (p[1] as num).toInt()),
    ],
    workouts: stressWorkoutSpans(
      sessions,
      (stored['observed_until'] as num).toInt(),
    ),
  );
}
