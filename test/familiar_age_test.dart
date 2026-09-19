import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_analytics/personal_analytics.dart';

void main() {
  final end = DateTime(2026, 9, 19);
  List<DailyValue> rows(double value, [int n = 7]) => [
    for (var i = 0; i < n; i++) (day: '2026-09-${19 - i}', value: value),
  ];
  AgeEstimate? run({
    double? age = 35,
    List<DailyValue>? rhr,
    List<DailyValue>? hrv,
    List<DailyValue>? sleep,
    List<DailyValue>? steps,
  }) => estimateAge(
    age: age,
    end: end,
    rhr: rhr ?? rows(56),
    hrv: hrv ?? rows(48),
    sleepHours: sleep ?? rows(7.6),
    steps: steps ?? rows(8450),
  );
  test('independently checked five-factor arithmetic', () {
    final out = run()!;
    final sum = -.09 + ((36.5 - 48) / 36.5) * .16 - .25 * .45 - 1.45 * .064;
    expect(out.estimated, closeTo(35 + sum * .75 / (math.ln2 / 8), 1e-9));
    expect(out.contributions.length, 5);
    expect(out.from, '2026-09-13');
    expect(out.through, '2026-09-19');
  });
  test('missing age is absent', () => expect(run(age: null), isNull));
  test('invalid or unsupported age is absent', () {
    for (final a in [double.nan, double.infinity, 19.0, 91.0]) {
      expect(run(age: a), isNull);
    }
  });
  test(
    'sleep variability is not a third independent measurement',
    () => expect(run(hrv: [], steps: []), isNull),
  );
  test(
    'three real quantities are sufficient without steps',
    () => expect(run(steps: []), isNotNull),
  );
  test('missing factors excluded, not neutral imputation', () {
    final a = run(steps: [])!;
    expect(a.contributions.containsKey('steps'), false);
    expect(a.estimated, greaterThan(run()!.estimated));
  });
  test(
    'each measured quantity requires three distinct days',
    () => expect(run(rhr: rows(56, 2), hrv: rows(48, 2)), isNull),
  );
  test('duplicate dates do not meet minimum coverage', () {
    final duplicate = List<DailyValue>.filled(7, (
      day: '2026-09-19',
      value: 56,
    ));
    expect(run(rhr: duplicate, hrv: []), isNull);
  });
  test('stale history cannot produce current age', () {
    final old = [(day: '2026-08-01', value: 56.0)];
    expect(run(rhr: old, hrv: old, sleep: old, steps: old), isNull);
  });
  test(
    'invalid values are excluded',
    () => expect(run(rhr: rows(double.nan), hrv: rows(-1)), isNull),
  );
  test('zero measured steps is valid, absence is different', () {
    expect(run(steps: rows(0))!.contributions['steps'], greaterThan(0));
    expect(run(steps: [])!.contributions.containsKey('steps'), false);
  });
  test('age reference interpolation and clamped endpoints', () {
    expect(rmssdReference(40), 33);
    expect(rmssdReference(35), 36.5);
    expect(rmssdReference(90), 20);
  });
  test('calendar boundary is local not duration subtraction', () {
    final a = estimateAge(age: 35, end: DateTime(2026, 3, 2), rhr: [], hrv: []);
    expect(a, isNull);
  });
  test('return cannot be mutated into another result', () {
    expect(() => run()!.contributions['rhr'] = 123, throwsUnsupportedError);
  });
}
