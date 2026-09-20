import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/compute/crossday_pipeline.dart';
import 'package:personal_analytics/whoop_formulas.dart';

/// Synthetic oldest-first day rows in the shape `_crossDayRecord` writes.
List<Map<String, dynamic>> rows(int n, {double tstMin = 450, double strain = 8, bool today = true}) {
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < n; i++) {
    final d = DateTime(2026, 8, 22 + i);
    final onset = DateTime(d.year, d.month, d.day - 1, 23, 10 + (i % 3) * 5).millisecondsSinceEpoch ~/ 1000;
    final wake = DateTime(d.year, d.month, d.day, 6, 50 + (i % 2) * 10).millisecondsSinceEpoch ~/ 1000;
    out.add({
      'date': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      'rhr': 52.0 + (i % 4),
      'rmssd': 55.0 + (i % 5) * 3,
      'readiness': 70.0,
      'resp_rate': 14.2 + (i % 3) * 0.2,
      'strain': strain,
      'whoop_strain': strain + (i % 2 == 0 ? 0 : 6),
      'whoop_z13_min': 30.0 + i % 7,
      'whoop_z45_min': 5.0,
      'steps': 8000.0 + i * 50,
      'nap_min': 0,
      'efficiency': 95.0,
      'in_bed_min': tstMin + 25,
      'sleep_high_stress_pct': 1.5,
      'onset_sec': onset,
      'wake_sec': wake,
      'tst_min': tstMin,
    });
  }
  if (today && out.isNotEmpty) out.last['is_today'] = true;
  return out;
}

void main() {
  const profile = {'age': 35, 'sex': 'male'};
  test('cross-day whoop block: need, last night, recovery, age, pace', () {
    final b = whoopCrossDayBlock(rows(40), profile);
    final need = b['need'] as Map;
    expect(need['baseline_source'], 'personal');
    // baseline = median TST of nights after light (< 10) days = 450 min
    expect(need['baseline_sec'], 450 * 60);
    // tonight's strain term uses TODAY's whoop_strain (index 39 → odd → 14)
    expect(need['strain_add_sec'], (whoopStrainSleepAddHours(14) * 3600).round());
    expect(need['need_sec'], greaterThan(450 * 60));
    final last = b['last_night'] as Map;
    expect(last['tst_sec'], 450 * 60);
    final perf = last['performance'] as Map;
    expect(perf['hours_vs_need_pct'], greaterThan(80));
    expect(perf['consistency_pct'], greaterThan(85));
    expect(perf['efficiency_pct'], 95.0);
    expect(perf['high_stress_pct'], 1.5);
    expect((perf['levels'] as Map)['stress'], 1);
    final rec = b['recovery'] as Map;
    expect(rec['score'], inInclusiveRange(1, 99));
    expect(rec['band'], isIn(['green', 'yellow', 'red']));
    final age = b['age'] as Map;
    expect(age['chronological'], 35.0);
    expect((age['factors'] as List).length, greaterThanOrEqualTo(5));
    expect(b['pace_of_aging'], isNotNull);
    expect((b['zones_week'] as Map)['z13_min'], greaterThan(0));
  });
  test('few rows: population baseline, no recovery baseline, no age', () {
    final b = whoopCrossDayBlock(rows(2), profile);
    expect((b['need'] as Map)['baseline_source'], 'population');
    expect(b['recovery'], isNull);
    expect(b['age'], isNull);
    expect(b['pace_of_aging'], isNull);
  });
  test('no rows at all still yields a population need and nothing invented', () {
    final b = whoopCrossDayBlock(const [], profile);
    expect((b['need'] as Map)['need_sec'], greaterThan(0));
    expect(b['last_night'], isNull);
    expect(b['recovery'], isNull);
    expect((b['zones_week'] as Map)['z13_min'], isNull);
  });
  test('full rollup carries the block', () {
    final bundle = buildCrossDayBundle(rows(12), profile);
    expect(bundle['whoop'], isA<Map>());
    expect((bundle['whoop'] as Map)['need'], isA<Map>());
  });
}
