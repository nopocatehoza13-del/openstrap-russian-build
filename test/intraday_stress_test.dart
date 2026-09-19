import 'dart:convert';
import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_analytics/intraday_stress.dart';
import 'package:openstrap_edge/compute/intraday_stress_bridge.dart';
import 'package:openstrap_edge/compute/substrate.dart';

const start = 1800000000;
List<Map<String, dynamic>> features({int hours = 6}) => [
  for (var m = 0; m < hours * 60; m++)
    {
      't': start + m * 60,
      'n': 60,
      'hr': m < 120
          ? 50.0
          : m < 300
          ? 65.0
          : 100.0,
      'motion': 0.0,
    },
];
Map<String, dynamic> score({
  List<Map<String, dynamic>>? rows,
  List<StressSpan> workouts = const [],
  int hours = 6,
  int? until,
}) => scoreIntradayStress(
  minutes: rows ?? features(hours: hours),
  start: start,
  end: start + hours * 3600,
  observedUntil: until ?? start + hours * 3600,
  sleep: const [(start: start, end: start + 7200)],
  workouts: workouts,
);
Map summary(Map m, String scope) => (m['summaries'] as Map)[scope] as Map;

void main() {
  test('no input is absence, not zero stress', () {
    final r = score(rows: []);
    expect(r['status'], 'no_samples');
    for (final s in ['all', 'rest', 'sleep']) {
      expect(summary(r, s)['mean'], isNull);
      expect(summary(r, s)['high_sec'], isNull);
    }
    expect((r['points'] as List).length, 72);
  });
  test('nightly scalar cannot substitute for minute features', () {
    expect(
      projectIntradayStress({
        'stress': {'score': 80},
      }, []),
      isEmpty,
    );
  });
  test('fewer than 60 quiet minutes or three distinct hours abstains', () {
    expect(
      score(rows: features().sublist(120, 179))['status'],
      'need_quiet_reference',
    );
    expect(
      score(rows: features().sublist(120, 240))['status'],
      'need_quiet_reference',
    );
  });
  test('sleep and workout exclusion; total includes physical activation', () {
    final r = score(
      workouts: const [(start: start + 18000, end: start + 21600)],
    );
    expect(r['status'], 'ready');
    expect(r['reference_bpm'], 65);
    expect(summary(r, 'rest')['mean'], closeTo(1.5, 1e-9));
    expect(summary(r, 'sleep')['mean'], lessThan(1));
    expect(summary(r, 'rest')['covered_sec'], 10800);
    expect(summary(r, 'all')['covered_sec'], 21600);
    expect(summary(r, 'all')['high_sec'], 3600);
  });
  test('movement is excluded without requiring a logged workout', () {
    final rows = features();
    for (final m in rows.skip(300)) {
      m['motion'] = .3;
    }
    final r = score(rows: rows);
    expect(summary(r, 'rest')['covered_sec'], 10800);
    expect(summary(r, 'all')['high_sec'], 3600);
  });
  test('sleep/workout conflict never enters sleep or non-activity', () {
    final r = score(workouts: const [(start: start, end: start + 3600)]);
    expect(summary(r, 'sleep')['covered_sec'], 3600);
  });
  test(
    'post-exercise elevated HR excluded from non-activity for 30 minutes',
    () {
      final rows = features(hours: 8);
      final r = score(
        rows: rows,
        hours: 8,
        workouts: const [(start: start + 18000, end: start + 21600)],
      );
      // Rest 02–05 plus 06:30–08:00; never double-count overlapping windows.
      expect(summary(r, 'rest')['covered_sec'], 16200);
    },
  );
  test('missing intervals stay holes, future intervals not computed', () {
    final r = score(
      rows: features()
          .where(
            (m) => m['t'] != start + 15000 && (m['t'] as int) >= start + 300,
          )
          .toList(),
      until: start + 21000,
    );
    final p = r['points'] as List;
    expect(p.first['all'], isNull);
    expect(p.last['all'], isNull);
    expect(summary(r, 'all')['covered_sec'], lessThan(21600));
  });
  test(
    'fewer than four valid minutes leaves a whole five-minute bucket absent',
    () {
      final rows = features()
          .where((m) => !{start + 15000, start + 15060}.contains(m['t']))
          .toList();
      final r = score(rows: rows);
      expect((r['points'] as List)[50]['all'], isNull);
    },
  );
  test('invalid persisted features ignored, not clamped', () {
    final bad = [
      for (final m in features()) {...m, 'hr': double.nan},
    ];
    expect(score(rows: bad)['status'], 'no_samples');
    expect(
      score(
        rows: [
          for (final m in features()) {...m, 'n': 61},
        ],
      )['status'],
      'no_samples',
    );
  });
  test('idempotent JSON and stable input ordering', () {
    expect(
      jsonEncode(score()),
      jsonEncode(score(rows: features().reversed.toList())),
    );
    final r = score();
    expect(jsonDecode(jsonEncode(r))['model'], 'experimental_hr_activation_v1');
  });
  for (final hours in [23, 25]) {
    test('DST $hours hour local calendar uses real boundaries', () {
      final r = score(hours: hours);
      expect((r['points'] as List).length, hours * 12);
      expect(summary(r, 'all')['covered_sec'], hours * 3600);
    });
  }
  test('coverage totals partition observed seconds only', () {
    final r = score(
      rows: [
        for (final m in features()) {...m, 'n': 30},
      ],
    );
    final s = summary(r, 'all');
    expect(s['covered_sec'], 10800);
    expect(
      (s['low_sec'] as int) + (s['medium_sec'] as int) + (s['high_sec'] as int),
      s['covered_sec'],
    );
  });
  test('monotonic HR response against same measured reference', () {
    final r = score(
      workouts: const [(start: start + 18000, end: start + 21600)],
    );
    final high = (r['points'] as List).last['all'] as double;
    expect(high, greaterThan(1.5));
    expect(high, lessThanOrEqualTo(3));
  });
  test('all three scope summaries are bounded or null', () {
    final r = score();
    for (final s in ['all', 'rest', 'sleep']) {
      final x = summary(r, s)['mean'] as double?;
      expect(x == null || x >= 0 && x <= 3, true);
    }
  });
  test('sample arrays mismatch is explicit error', () {
    expect(
      () => stressMinutes(
        timestamps: [start],
        hr: [],
        moving: [],
        start: start,
        end: start + 60,
      ),
      throwsArgumentError,
    );
  });
  test('missing HR or motion is not stillness', () {
    final ts = [for (var i = 0; i < 60; i++) start + i];
    expect(
      stressMinutes(
        timestamps: ts,
        hr: List.filled(60, 0),
        moving: List.filled(60, false),
        start: start,
        end: start + 60,
      ),
      isEmpty,
    );
    expect(
      stressMinutes(
        timestamps: ts,
        hr: List.filled(60, 70),
        moving: List.filled(60, null),
        start: start,
        end: start + 60,
      ),
      isEmpty,
    );
  });
  test(
    'same second repeated cannot fill coverage; conflicting copies discarded',
    () {
      expect(
        stressMinutes(
          timestamps: List.filled(60, start),
          hr: List.filled(60, 70),
          moving: List.filled(60, false),
          start: start,
          end: start + 60,
        ),
        isEmpty,
      );
      final ts = [for (var i = 0; i < 60; i++) start + i];
      expect(
        stressMinutes(
          timestamps: [...ts, ...ts],
          hr: [...List.filled(60, 70), ...List.filled(60, 80)],
          moving: List.filled(120, false),
          start: start,
          end: start + 60,
        ),
        isEmpty,
      );
    },
  );
  test('reported off wrist and charger reject plausible HR', () {
    final ts = [for (var i = 0; i < 120; i++) start + i];
    expect(
      stressMinutes(
        timestamps: ts,
        hr: List.filled(120, 70),
        moving: List.filled(120, false),
        start: start,
        end: start + 120,
        excluded: const [(start: start, end: start + 120)],
      ),
      isEmpty,
    );
  });
  test(
    'retained features reclassify immediately after manual workout correction',
    () async {
      final before = score();
      final after = await Isolate.run(
        () => projectIntradayStress(before, [
          {
            'start_ts': start + 18000,
            'end_ts': start + 21600,
            'status': 'done',
          },
        ]),
      );
      expect(summary(after, 'rest')['covered_sec'], 10800);
      expect(summary(before, 'rest')['covered_sec'], 14400);
      final undone = projectIntradayStress(after, []);
      expect(jsonEncode(undone), jsonEncode(before));
    },
  );
  test('live workout excludes until observed edge', () {
    final r = projectIntradayStress(score(), [
      {'start_ts': start + 18000, 'status': 'live'},
    ]);
    expect(summary(r, 'rest')['covered_sec'], 10800);
  });
  test(
    'bridge uses real substrate, HR validity, motion and canonical sleep',
    () {
      const n = 21600;
      final s = Substrate(
        tsSec: [for (var i = 0; i < n; i++) start + i],
        hr: [
          for (var i = 0; i < n; i++)
            i < 7200
                ? 50
                : i < 18000
                ? 65
                : 100,
        ],
        rrTsMs: [],
        rrMs: [],
        ax: List.filled(n, 0.0),
        ay: List.filled(n, 0.0),
        az: List.filled(n, 1.0),
        spo2Red: List.filled(n, 0),
        spo2Ir: List.filled(n, 0),
        skinTemp: List.filled(n, 0),
        skinContact: List.filled(n, 0),
      );
      final r = deriveIntradayStress(
        substrate: s,
        start: start,
        end: start + n,
        observedUntil: start + n,
        sleepPeriods: {
          'periods': [
            {'onset_ts': start, 'wake_ts': start + 7200},
          ],
        },
        sessions: [
          {'start_ts': start + 18000, 'end_ts': start + n},
        ],
        wristOff: [],
        charging: [],
      );
      expect(r['status'], 'ready');
      expect(summary(r, 'all')['covered_sec'], n - 1);
      expect(summary(r, 'rest')['covered_sec'], 10800);
    },
  );
}
