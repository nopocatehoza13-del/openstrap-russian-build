import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_analytics/whoop_formulas.dart';

void main() {
  group('max HR and HRR zones (support article)', () {
    test('Gellish 192 − 0.007·age²', () {
      expect(gellishMaxHr(35), closeTo(183.425, 1e-9));
      expect(whoopMaxHr(age: 35), closeTo(183.425, 1e-9));
    });
    test('observed ceiling wins only when higher and plausible', () {
      expect(whoopMaxHr(age: 35, observedMaxBpm: 190), 190);
      expect(whoopMaxHr(age: 35, observedMaxBpm: 170), closeTo(183.425, 1e-9));
      expect(whoopMaxHr(age: 35, observedMaxBpm: 240), closeTo(183.425, 1e-9));
      expect(whoopMaxHr(age: null), isNull);
    });
    test('zone lower bounds at 50/60/70/80/90 % of reserve', () {
      final z = whoopZoneLowerBounds(rhr: 52, maxHr: 190);
      expect(z, [121, 134.8, 148.6, 162.4, 176.2].map((v) => closeTo(v, 1e-9)));
      expect(whoopZoneOf(78, z), 0);
      expect(whoopZoneOf(121, z), 1);
      expect(whoopZoneOf(150, z), 3);
      expect(whoopZoneOf(200, z), 5);
    });
    test('zone minutes count each sample by cadence', () {
      final z = whoopZoneLowerBounds(rhr: 52, maxHr: 190);
      final m = whoopZoneMinutes([80, 125, 125, 150, 180], z);
      expect(m, {'z1': 2.0, 'z2': 0.0, 'z3': 1.0, 'z4': 0.0, 'z5': 1.0});
      final s = whoopZoneMinutes([125, 125], z, minutesPerSample: 1 / 60);
      expect(s['z1'], closeTo(2 / 60, 1e-12));
    });
  });

  group('strain (patent structure, calibrated constants)', () {
    test('arctan scale is the patent formula and stays in 0–21', () {
      final f = whoopStrainScale(whoopStrainP);
      expect(f, closeTo(10.5, 1e-9));
      expect(whoopStrainScale(0), greaterThan(0));
      expect(whoopStrainScale(1), lessThan(21));
      expect(whoopStrainScale(1), greaterThan(whoopStrainScale(0.5)));
    });
    test('needs a reserve and some heart rate', () {
      expect(whoopStrain([70, 80], rhr: null, maxHr: 190, female: false), isNull);
      expect(whoopStrain([70, 80], rhr: 60, maxHr: 55, female: false), isNull);
      expect(whoopStrain(const <double>[], rhr: 52, maxHr: 190, female: false), isNull);
    });
    test('anchors: quiet day light, hard hour moderate-high, marathon all out', () {
      const rhr = 52.0, mhr = 190.0;
      final quiet = whoopStrain(List.filled(16 * 60, 63.0), rhr: rhr, maxHr: mhr, female: false)!;
      expect(quiet.score, inInclusiveRange(4, 7));
      expect(whoopStrainBand(quiet.score), 'light');
      final runDay = [...List.filled(15 * 60, 63.0), ...List.filled(60, 162.0)];
      final run = whoopStrain(runDay, rhr: rhr, maxHr: mhr, female: false)!;
      expect(run.score, inInclusiveRange(12, 16));
      final twoHours = [...List.filled(14 * 60, 63.0), ...List.filled(120, 162.0)];
      expect(whoopStrain(twoHours, rhr: rhr, maxHr: mhr, female: false)!.score, inInclusiveRange(16.5, 19));
      final marathon = [...List.filled(12 * 60, 63.0), ...List.filled(240, 169.0)];
      final m = whoopStrain(marathon, rhr: rhr, maxHr: mhr, female: false)!.score;
      expect(m, inInclusiveRange(19, 21));
      expect(whoopStrainBand(m), 'all_out');
      expect(run.coveredSec, 16 * 3600);
    });
    test('curve is monotone and ends at the day score', () {
      const rhr = 52.0, mhr = 190.0;
      final hr = [...List.filled(30, 63.0), ...List.filled(30, 160.0), ...List.filled(30, 63.0)];
      final curve = whoopStrainCurve(hr, rhr: rhr, maxHr: mhr, female: false);
      expect(curve.length, hr.length);
      for (var i = 1; i < curve.length; i++) {
        expect(curve[i], greaterThanOrEqualTo(curve[i - 1]));
      }
      final day = whoopStrain(hr, rhr: rhr, maxHr: mhr, female: false)!;
      expect(curve.last, closeTo(day.score, 1e-9));
    });
    test('women use the gentler weight', () {
      final hr = [...List.filled(15 * 60, 63.0), ...List.filled(60, 150.0)];
      final m = whoopStrain(hr, rhr: 52, maxHr: 190, female: false)!;
      final f = whoopStrain(hr, rhr: 52, maxHr: 190, female: true)!;
      expect(f.intensity, isNot(closeTo(m.intensity, 1e-9)));
    });
  });

  group('sleep need (US 2024/0252121 A1)', () {
    test('claim 8 strain term, in hours', () {
      expect(whoopStrainSleepAddHours(8) * 60, closeTo(7.4, 0.2));
      expect(whoopStrainSleepAddHours(12) * 60, closeTo(19.7, 0.3));
      expect(whoopStrainSleepAddHours(17) * 60, closeTo(51, 0.1));
      expect(whoopStrainSleepAddHours(20) * 60, closeTo(71.6, 0.3));
      expect(whoopStrainSleepAddHours(0), lessThan(0.02));
    });
    test('baseline: median of nights after light days, else population', () {
      final nights = [
        for (var i = 0; i < 12; i++)
          (tstSec: (7.0 + (i % 3) * 0.5) * 3600, priorStrain: i.isEven ? 6.0 : 15.0),
      ];
      final b = whoopSleepBaseline(nights, age: 35);
      expect(b.source, 'personal');
      expect(b.nights, 6);
      expect(b.baselineSec, closeTo(7.5 * 3600, 1e-6));
      final few = whoopSleepBaseline(nights.take(3).toList(), age: 35);
      expect(few.source, 'population');
      expect(few.baselineSec, 7.6 * 3600);
      expect(whoopPopulationBaselineSec(22), 8.0 * 3600);
      expect(whoopPopulationBaselineSec(70), 7.2 * 3600);
    });
    test('debt accumulates shortfall, repays with surplus, capped', () {
      const base = 8.0 * 3600;
      final short = [for (var i = 0; i < 7; i++) (tstSec: 6.0 * 3600, priorStrain: 5.0)];
      expect(whoopSleepDebtSec(short, base), whoopDebtCapSec);
      final mixed = [(tstSec: 9.0 * 3600, priorStrain: 5.0), (tstSec: 7.0 * 3600, priorStrain: 5.0)];
      // oldest first: 7 h → +1 h (+ the small strain term) of debt, then 9 h
      // repays the hour; only the two strain terms remain.
      expect(whoopSleepDebtSec(mixed, base), closeTo(2 * whoopStrainSleepAddHours(5) * 3600, 1e-6));
      expect(whoopSleepDebtSec([(tstSec: 7.0 * 3600, priorStrain: 5.0)], base), closeTo(3600 + whoopStrainSleepAddHours(5) * 3600, 1e-6));
    });
    test('need = baseline + strain term + repayable debt − naps', () {
      final b = const WhoopSleepBaseline(7.5 * 3600, 'personal', 10);
      final n = whoopSleepNeed(baseline: b, todayStrain: 15, debtSec: 2 * 3600, napSec: 30 * 60);
      expect(n.strainAddSec, closeTo(whoopStrainSleepAddHours(15) * 3600, 1e-6));
      expect(n.debtSec, closeTo(3600, 1e-6));
      expect(n.napCreditSec, 1800);
      expect(n.needSec, closeTo(7.5 * 3600 + n.strainAddSec + 3600 - 1800, 1e-6));
      expect(n.toJson()['baseline_source'], 'personal');
      expect(whoopSleepNeed(baseline: b, todayStrain: null, debtSec: 0).needSec, closeTo(7.5 * 3600 + whoopStrainSleepAddHours(0) * 3600, 1e-6));
    });
  });

  group('sleep performance (support thresholds)', () {
    test('levels follow the published cut-offs', () {
      expect(whoopLevel(85, optimal: 85, sufficient: 70), 2);
      expect(whoopLevel(84.9, optimal: 85, sufficient: 70), 1);
      expect(whoopLevel(69.9, optimal: 85, sufficient: 70), 0);
      expect(whoopLevel(null, optimal: 85, sufficient: 70), -1);
      expect(whoopSleepStressLevel(0.5), 2);
      expect(whoopSleepStressLevel(3), 1);
      expect(whoopSleepStressLevel(6), 0);
    });
    test('consistency against the previous four nights', () {
      final same = whoopSleepConsistency(bedMinutes: List.filled(5, 23 * 60.0), wakeMinutes: List.filled(5, 7 * 60.0));
      expect(same, 100);
      final drift = whoopSleepConsistency(
        bedMinutes: [23 * 60.0, 23 * 60.0 + 48, 23 * 60.0 - 48, 23 * 60.0 + 48, 23 * 60.0 - 48],
        wakeMinutes: [7 * 60.0, 7 * 60.0 + 48, 7 * 60.0 - 48, 7 * 60.0 + 48, 7 * 60.0 - 48],
      );
      expect(drift, closeTo(80, 1e-9));
      // wrap-around midnight counts as a small deviation
      final wrap = whoopSleepConsistency(bedMinutes: [5.0, 1435, 5, 1435, 5], wakeMinutes: List.filled(5, 420.0));
      expect(wrap, closeTo(100 - (10 * 2 / 8) / 2.4, 1e-9));
      expect(whoopSleepConsistency(bedMinutes: [1, 2, 3], wakeMinutes: [1, 2, 3]), isNull);
    });
    test('performance re-weights missing components, hours alone suffice', () {
      final full = whoopSleepPerformance(tstSec: 7.7 * 3600, needSec: 8.25 * 3600, consistencyPct: 72, efficiencyPct: 96, highStressPct: 2);
      expect(full.hoursVsNeedPct, closeTo(93.33, 0.01));
      final expected = (0.55 * 93.3333 + 0.20 * 72 + 0.15 * 96 + 0.10 * 80) / 1.0;
      expect(full.performancePct, closeTo(expected, 0.01));
      final only = whoopSleepPerformance(tstSec: 6 * 3600, needSec: 8 * 3600);
      expect(only.performancePct, closeTo(75, 1e-9));
      expect(only.consistencyLevel, -1);
      expect(whoopSleepPerformance(tstSec: null, needSec: 8 * 3600).performancePct, isNull);
    });
  });

  group('recovery (weighted vs 30-night baseline)', () {
    test('null without HRV or enough baseline', () {
      expect(whoopRecovery(hrvMs: null, hrvBaselineMs: List.filled(10, 50)), isNull);
      expect(whoopRecovery(hrvMs: 50, hrvBaselineMs: List.filled(6, 50)), isNull);
    });
    test('at baseline ≈ 50, above baseline green, below red', () {
      final base = [for (var i = 0; i < 20; i++) 50.0 + (i % 5) * 2];
      final mid = whoopRecovery(hrvMs: 54, hrvBaselineMs: base)!;
      expect(mid.score, inInclusiveRange(45, 56));
      final high = whoopRecovery(hrvMs: 80, hrvBaselineMs: base, rhr: 48, rhrBaseline: List.filled(10, 54), sleepPerformancePct: 95)!;
      expect(high.band, 'green');
      final low = whoopRecovery(hrvMs: 32, hrvBaselineMs: base, rhr: 62, rhrBaseline: List.filled(10, 54), sleepPerformancePct: 60)!;
      expect(low.band, 'red');
      expect(high.score, lessThanOrEqualTo(99));
      expect(low.score, greaterThanOrEqualTo(1));
    });
  });

  group('healthspan (white paper transform)', () {
    test('Δage = 10·ln(HR) with shrink and cap', () {
      final a = whoopAge(chronologicalAge: 35, sleepHoursAvg: 7.25, sleepConsistencyPct: 85, stepsAvg: 6000, rhrAvg: 60)!;
      // every factor at its reference → hazard 1 → no years.
      expect(a.deltaYears, closeTo(0, 1e-9));
      expect(a.whoopAge, closeTo(35, 1e-9));
      expect(a.missing, containsAll(['zones_1_3', 'zones_4_5', 'strength', 'vo2max', 'lean_mass']));
      final b = whoopAge(chronologicalAge: 35, sleepHoursAvg: 7.25, sleepConsistencyPct: 85, stepsAvg: 10000, rhrAvg: 60)!;
      final steps = b.factors.firstWhere((f) => f.key == 'steps');
      expect(steps.years, closeTo(10 * math.log(math.pow(0.9, 4)) * 0.5, 1e-9));
      expect(b.whoopAge, lessThan(35));
      final worse = whoopAge(chronologicalAge: 35, sleepHoursAvg: 5, sleepConsistencyPct: 40, stepsAvg: 2000, rhrAvg: 90)!;
      for (final f in worse.factors) {
        expect(f.years.abs(), lessThanOrEqualTo(whoopAgeFactorCapYears));
      }
      expect(worse.whoopAge, greaterThan(35));
    });
    test('needs an age and at least three factors', () {
      expect(whoopAge(chronologicalAge: null, sleepHoursAvg: 7), isNull);
      expect(whoopAge(chronologicalAge: 35, sleepHoursAvg: 7, stepsAvg: 8000), isNull);
    });
    test('pace of aging on the −1x…3x scale', () {
      expect(whoopPaceOfAging(deltaYearsNow: -2, deltaYearsBefore: -2, daysBetween: 28), 1.0);
      expect(whoopPaceOfAging(deltaYearsNow: -2.1, deltaYearsBefore: -2, daysBetween: 28), lessThan(1.0));
      expect(whoopPaceOfAging(deltaYearsNow: 5, deltaYearsBefore: -2, daysBetween: 28), 3.0);
      expect(whoopPaceOfAging(deltaYearsNow: -5, deltaYearsBefore: 2, daysBetween: 28), -1.0);
    });
    test('stress bands', () {
      expect(whoopStressBand(0.9), 'low');
      expect(whoopStressBand(1.5), 'medium');
      expect(whoopStressBand(2.0), 'high');
    });
  });

  // ── v8 ──
  test('band SpO₂: bit 7 masked, 70–100 kept, median with count, thin nights refuse', () {
    final r = whoopBandSpo2(const [97, 0, 98, 224, 96, 99, 97, 95, 96, 40])!;
    expect(r.pct, 96.5);
    expect(r.samples, 8);
    expect(r.lo, 95);
    expect(r.hi, 99);
    expect(r.toJson()['source'], 'band');
    expect(whoopBandSpo2(const [97, 98, 96, 99, 97, 95, 96]), isNull);
    expect(whoopBandSpo2(const [97, 98, 96, 99, 97, 95, 96], minSamples: 7)!.pct, 97);
    expect(whoopBandSpo2(const []), isNull);
  });
  test('coefficient of variation and the 10–90 % range', () {
    expect(whoopCv(const [50, 50, 50, 50, 50, 50]), 0);
    expect(whoopCv(const [50, 50, 50]), isNull);
    expect(whoopCv(const [40, 60, 40, 60, 40, 60]), greaterThan(.2));
    final r = whoopRange(const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])!;
    expect(r.lo, 2);
    expect(r.median, 6);
    expect(r.hi, 10);
    expect(whoopRange(const [1, 2]), isNull);
  });
}
