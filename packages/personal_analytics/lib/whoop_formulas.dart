/// WHOOP-published calculations, implemented from the primary documents:
///
///   * Strain — US 9,750,415 B2 / US 11,185,241 B2 ("Intensity score"):
///     heart-rate reserve v(t) = (HR − RHR)/(MHR − RHR), weighted integral
///     I = ∫ w(v) dt, normalisation N = I / (w(1) · 24 h), arctan scale
///     f(x) = ½·(arctan(k·(x − p))/(π/2) + 1), score = 21·f(N).
///   * Sleep need — US 2024/0252121 A1: need = baseline + f₁(strain) + debt −
///     naps, with the claimed strain term f₁(i) = 1.7 / (1 + e^((17 − i)/3.5)) h.
///   * Sleep performance / consistency / efficiency / sleep-stress thresholds,
///     HRR-based heart-rate zones at 50/60/70/80/90 % and the Gellish max-HR
///     estimate — support.whoop.com ("WHOOP Sleep", "Max Heart Rate & HR
///     Zones", "Stress Monitor").
///   * Healthspan — WHOOP 2025 Healthspan white paper: Δage = ln(HR)/0.1 =
///     10·ln(hazard ratio), nine behaviour factors, Pace of Aging −1x…3x.
///
/// What is EXACT here is the structure and every constant the documents print.
/// What the documents do not print (the strain weighting curve and arctan
/// parameters, sleep-debt window and cap, the recovery weights, the per-factor
/// hazard curves) is calibrated in this file and named as such next to the
/// constant. Nothing here reads a database, the clock or Flutter: every input is
/// handed in, so the functions run in an isolate and in a plain Dart test.
library;

import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────────────────────
// MAX HEART RATE AND ZONES (support: "Max Heart Rate & Heart Rate Zones")
// ─────────────────────────────────────────────────────────────────────────────

/// Gellish et al. 2007, the non-linear estimate WHOOP names: 192 − 0.007·age².
double gellishMaxHr(double age) => 192.0 - 0.007 * age * age;

/// WHOOP raises the estimate to the highest heart rate it has actually seen,
/// so the observed ceiling wins when it is higher than the age estimate.
/// Returns null without an age — no estimate is invented.
double? whoopMaxHr({required double? age, double? observedMaxBpm}) {
  if (age == null || !age.isFinite || age < 10 || age > 100) return null;
  final est = gellishMaxHr(age);
  if (observedMaxBpm != null &&
      observedMaxBpm.isFinite &&
      observedMaxBpm > est &&
      observedMaxBpm <= 230) {
    return observedMaxBpm;
  }
  return est;
}

/// Lower bounds of zones 1…5 by heart-rate reserve: RHR + (MHR − RHR)·p for
/// p = 50, 60, 70, 80, 90 % — the five percentages the support article lists.
List<double> whoopZoneLowerBounds({required double rhr, required double maxHr}) {
  final reserve = maxHr - rhr;
  return [for (final p in const [.5, .6, .7, .8, .9]) rhr + reserve * p];
}

/// 0 below zone 1, else 1…5.
int whoopZoneOf(double hr, List<double> lower) {
  var z = 0;
  for (var i = 0; i < lower.length; i++) {
    if (hr >= lower[i]) z = i + 1;
  }
  return z;
}

/// Minutes in each zone from a per-minute (or any fixed-cadence) HR series.
/// [minutesPerSample] is the cadence, 1.0 for a per-minute mean.
Map<String, double> whoopZoneMinutes(
  Iterable<double> hr,
  List<double> lower, {
  double minutesPerSample = 1.0,
}) {
  final out = {for (var i = 1; i <= 5; i++) 'z$i': 0.0};
  for (final v in hr) {
    final z = whoopZoneOf(v, lower);
    if (z > 0) out['z$z'] = out['z$z']! + minutesPerSample;
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// STRAIN (US 9,750,415 B2 / US 11,185,241 B2)
// ─────────────────────────────────────────────────────────────────────────────

/// Calibrated, NOT printed in the patent. The weighting w(v) = v·e^(b·v) has
/// the Banister TRIMP shape the patent's "static weighting by thresholds" can be
/// expressed with; b is steeper than Banister's 1.92 so that an all-out hour
/// outweighs a day of walking the way WHOOP's public bands describe
/// (0–9 light, 10–13 moderate, 14–17 high, 18–21 all out).
const double whoopStrainWeightMen = 3.0;
const double whoopStrainWeightWomen = 2.6;

/// Calibrated arctan parameters (k, p). Anchors they reproduce with the weight
/// above: nothing but quiet waking ≈ 4.6, a day with a 1 h hard run ≈ 13.7,
/// two hard hours ≈ 17.9, a marathon ≈ 19.9, no data → 0.
const double whoopStrainK = 80.0;
const double whoopStrainP = 0.015;

/// The patent's own scale: ½·(arctan(k·(x − p))/(π/2) + 1), times 21.
double whoopStrainScale(double normalised, {double k = whoopStrainK, double p = whoopStrainP}) =>
    21.0 * 0.5 * (math.atan(k * (normalised - p)) / (math.pi / 2) + 1.0);

/// Weight of one second at heart-rate reserve fraction [v].
double whoopStrainWeight(double v, {required bool female}) {
  final b = female ? whoopStrainWeightWomen : whoopStrainWeightMen;
  return v * math.exp(b * v);
}

class WhoopStrain {
  /// 0–21.
  final double score;

  /// The patent's normalised intensity N ∈ [0, 1].
  final double intensity;

  /// Seconds of HR the integral actually covered.
  final double coveredSec;
  const WhoopStrain(this.score, this.intensity, this.coveredSec);
}

/// Strain over a heart-rate series. [hr] and [durationSec] are parallel: each
/// sample lasted [durationSec] (60 for a per-minute mean, 1 at 1 Hz). Samples
/// at or below the resting rate weigh 0. Returns null when the inputs cannot
/// define the reserve or when there is no heart-rate at all — never 0 for
/// "unknown".
WhoopStrain? whoopStrain(
  Iterable<double> hr, {
  required double? rhr,
  required double? maxHr,
  required bool female,
  double durationSec = 60.0,
  double dayLengthSec = 86400.0,
}) {
  if (rhr == null || maxHr == null || !(maxHr > rhr) || durationSec <= 0) {
    return null;
  }
  final reserve = maxHr - rhr;
  var integral = 0.0, covered = 0.0;
  for (final h in hr) {
    if (!h.isFinite || h <= 0) continue;
    final v = ((h - rhr) / reserve).clamp(0.0, 1.0);
    integral += whoopStrainWeight(v, female: female) * durationSec;
    covered += durationSec;
  }
  if (covered <= 0) return null;
  final n = integral / (whoopStrainWeight(1.0, female: female) * dayLengthSec);
  return WhoopStrain(whoopStrainScale(n), n, covered);
}

/// Cumulative strain through the day: one point per sample, so a chart can
/// show the score climbing on effort and staying flat at rest.
List<double> whoopStrainCurve(
  Iterable<double> hr, {
  required double rhr,
  required double maxHr,
  required bool female,
  double durationSec = 60.0,
  double dayLengthSec = 86400.0,
}) {
  final reserve = maxHr - rhr;
  if (!(reserve > 0)) return const [];
  final w1 = whoopStrainWeight(1.0, female: female) * dayLengthSec;
  var integral = 0.0;
  final out = <double>[];
  for (final h in hr) {
    if (h.isFinite && h > 0) {
      final v = ((h - rhr) / reserve).clamp(0.0, 1.0);
      integral += whoopStrainWeight(v, female: female) * durationSec;
    }
    out.add(whoopStrainScale(integral / w1));
  }
  return out;
}

/// WHOOP's public strain bands (support: "Strain").
String whoopStrainBand(double strain) => strain >= 18
    ? 'all_out'
    : strain >= 14
    ? 'high'
    : strain >= 10
    ? 'moderate'
    : 'light';

// ─────────────────────────────────────────────────────────────────────────────
// SLEEP NEED (US 2024/0252121 A1)
// ─────────────────────────────────────────────────────────────────────────────

/// Claim 8, verbatim: the extra hours of sleep a day of strain i (0–21) adds.
/// i = 8 → 7 min, 12 → 19 min, 15 → 37 min, 17 → 51 min, 20 → 71 min.
double whoopStrainSleepAddHours(double strain) =>
    1.7 / (1.0 + math.exp((17.0 - strain) / 3.5));

/// Calibrated, not printed: how many of the previous nights feed the debt and
/// the ceiling the application says the debt is "capped" at.
const int whoopDebtWindowNights = 7;
const double whoopDebtCapSec = 3.0 * 3600;

/// Calibrated: the share of the outstanding debt WHOOP asks you to repay
/// tonight and its ceiling (support says debt is repaid gradually).
const double whoopDebtRepayShare = 0.5;
const double whoopDebtRepayCapSec = 1.5 * 3600;

/// Calibrated: nap credit is one-for-one up to two hours.
const double whoopNapCreditCapSec = 2.0 * 3600;

/// Strain band under which a night counts toward the baseline (claim 14: nights
/// after days whose strain "did not exceed a threshold"). 10 is the top of
/// WHOOP's public "light" band.
const double whoopBaselineStrainMax = 10.0;
const int whoopBaselineWindowNights = 30;
const int whoopBaselineMinNights = 5;

/// The starting need WHOOP shows a new user before it has personal nights —
/// by age, the way claim 17 says the baseline depends on age. Flagged as
/// `population` by [whoopSleepBaseline] so the UI can say it is not personal yet.
double whoopPopulationBaselineSec(double? age) {
  if (age == null || !age.isFinite) return 7.6 * 3600;
  if (age < 25) return 8.0 * 3600;
  if (age >= 65) return 7.2 * 3600;
  return 7.6 * 3600;
}

class WhoopSleepBaseline {
  final double baselineSec;

  /// `personal` (from the user's own low-strain nights) or `population`.
  final String source;

  /// Nights the personal baseline was taken over.
  final int nights;
  const WhoopSleepBaseline(this.baselineSec, this.source, this.nights);
}

/// Baseline need from history. [nightsNewestFirst] pairs each night's total
/// sleep with the strain of the day that preceded it (null when unknown).
WhoopSleepBaseline whoopSleepBaseline(
  List<({double tstSec, double? priorStrain})> nightsNewestFirst, {
  double? age,
}) {
  final window = nightsNewestFirst.take(whoopBaselineWindowNights).toList();
  final quiet = <double>[
    for (final n in window)
      if (n.tstSec.isFinite &&
          n.tstSec >= 3 * 3600 &&
          n.tstSec <= 14 * 3600 &&
          n.priorStrain != null &&
          n.priorStrain! < whoopBaselineStrainMax)
        n.tstSec,
  ];
  final pool = quiet.length >= whoopBaselineMinNights
      ? quiet
      : [
          for (final n in window)
            if (n.tstSec.isFinite && n.tstSec >= 3 * 3600 && n.tstSec <= 14 * 3600) n.tstSec,
        ];
  if (pool.length < whoopBaselineMinNights) {
    return WhoopSleepBaseline(whoopPopulationBaselineSec(age), 'population', pool.length);
  }
  final sec = _median(pool).clamp(6.0 * 3600, 10.0 * 3600);
  return WhoopSleepBaseline(sec, 'personal', pool.length);
}

/// Debt carried into tonight: walk the last [whoopDebtWindowNights] nights
/// oldest → newest, adding each night's shortfall against (baseline + that
/// day's strain term) and letting surplus sleep repay it, capped.
/// [nightsNewestFirst] as in [whoopSleepBaseline].
double whoopSleepDebtSec(
  List<({double tstSec, double? priorStrain})> nightsNewestFirst,
  double baselineSec,
) {
  final recent = nightsNewestFirst.take(whoopDebtWindowNights).toList().reversed;
  var debt = 0.0;
  for (final n in recent) {
    if (!n.tstSec.isFinite || n.tstSec <= 0) continue;
    final need = baselineSec + whoopStrainSleepAddHours(n.priorStrain ?? 0) * 3600;
    debt = (debt + (need - n.tstSec)).clamp(0.0, whoopDebtCapSec);
  }
  return debt;
}

class WhoopSleepNeed {
  final double baselineSec, strainAddSec, debtSec, napCreditSec, needSec;
  final String baselineSource;
  const WhoopSleepNeed({
    required this.baselineSec,
    required this.strainAddSec,
    required this.debtSec,
    required this.napCreditSec,
    required this.needSec,
    required this.baselineSource,
  });
  Map<String, dynamic> toJson() => {
        'baseline_sec': baselineSec.round(),
        'baseline_source': baselineSource,
        'strain_add_sec': strainAddSec.round(),
        'debt_sec': debtSec.round(),
        'nap_credit_sec': napCreditSec.round(),
        'need_sec': needSec.round(),
      };
}

/// Tonight's need = baseline + f₁(today's strain) + repayable debt − naps.
/// [debtSec] is the OUTSTANDING debt ([whoopSleepDebtSec]); the part asked for
/// tonight is [whoopDebtRepayShare] of it up to [whoopDebtRepayCapSec].
WhoopSleepNeed whoopSleepNeed({
  required WhoopSleepBaseline baseline,
  required double? todayStrain,
  required double debtSec,
  double napSec = 0,
}) {
  final strainAdd = whoopStrainSleepAddHours(todayStrain ?? 0) * 3600;
  final debtTonight = math.min(debtSec * whoopDebtRepayShare, whoopDebtRepayCapSec);
  final nap = math.min(math.max(0.0, napSec), whoopNapCreditCapSec);
  final need = (baseline.baselineSec + strainAdd + debtTonight - nap).clamp(4.0 * 3600, 12.0 * 3600);
  return WhoopSleepNeed(
    baselineSec: baseline.baselineSec,
    strainAddSec: strainAdd,
    debtSec: debtTonight,
    napCreditSec: nap,
    needSec: need,
    baselineSource: baseline.source,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SLEEP PERFORMANCE (support: "WHOOP Sleep — Sleep Performance")
// ─────────────────────────────────────────────────────────────────────────────

/// Three-level rating: 2 optimal, 1 sufficient, 0 poor, with WHOOP's published
/// cut-offs per component.
int whoopLevel(double? pct, {required double optimal, required double sufficient}) =>
    pct == null ? -1 : pct >= optimal ? 2 : pct >= sufficient ? 1 : 0;

/// High sleep stress share: optimal < 1 %, sufficient 1–5 %, poor > 5 %.
int whoopSleepStressLevel(double? pct) => pct == null ? -1 : pct < 1 ? 2 : pct <= 5 ? 1 : 0;

/// Sleep consistency: last night's bed and wake times against the previous four
/// nights (support: "based on the previous 4 nights"). Times are minutes of the
/// local day, [bedMinutes] and [wakeMinutes] newest first, at least 5 each.
/// Calibrated scale: 100 − (mean absolute deviation in minutes)/2.4, so a 48 min
/// average drift reads 80 % and 72 min reads 70 %.
double? whoopSleepConsistency({
  required List<double> bedMinutes,
  required List<double> wakeMinutes,
}) {
  if (bedMinutes.length < 5 || wakeMinutes.length < 5) return null;
  double dev(double a, double b) {
    var d = (a - b).abs() % 1440;
    if (d > 720) d = 1440 - d;
    return d;
  }

  var sum = 0.0;
  for (var i = 1; i <= 4; i++) {
    sum += dev(bedMinutes[0], bedMinutes[i]) + dev(wakeMinutes[0], wakeMinutes[i]);
  }
  final mean = sum / 8;
  return (100 - mean / 2.4).clamp(0.0, 100.0);
}

class WhoopSleepPerformance {
  final double? hoursVsNeedPct, consistencyPct, efficiencyPct, highStressPct, performancePct;
  const WhoopSleepPerformance({
    this.hoursVsNeedPct,
    this.consistencyPct,
    this.efficiencyPct,
    this.highStressPct,
    this.performancePct,
  });
  int get hoursLevel => whoopLevel(hoursVsNeedPct, optimal: 85, sufficient: 70);
  int get consistencyLevel => whoopLevel(consistencyPct, optimal: 80, sufficient: 70);
  int get efficiencyLevel => whoopLevel(efficiencyPct, optimal: 90, sufficient: 80);
  int get stressLevel => whoopSleepStressLevel(highStressPct);
  int get performanceLevel => whoopLevel(performancePct, optimal: 85, sufficient: 70);
  Map<String, dynamic> toJson() => {
        'hours_vs_need_pct': _r1(hoursVsNeedPct),
        'consistency_pct': _r1(consistencyPct),
        'efficiency_pct': _r1(efficiencyPct),
        'high_stress_pct': _r1(highStressPct),
        'performance_pct': _r1(performancePct),
        'levels': {
          'hours': hoursLevel,
          'consistency': consistencyLevel,
          'efficiency': efficiencyLevel,
          'stress': stressLevel,
          'performance': performanceLevel,
        },
      };
}

/// Calibrated weights of the four published components ("weighted by their
/// impact" is all the article says). Missing components drop out and the rest
/// are re-weighted; hours-vs-need alone is enough for a score.
const whoopSleepPerfWeights = (hours: 0.55, consistency: 0.20, efficiency: 0.15, stress: 0.10);

WhoopSleepPerformance whoopSleepPerformance({
  required double? tstSec,
  required double? needSec,
  double? consistencyPct,
  double? efficiencyPct,
  double? highStressPct,
}) {
  final hvn = (tstSec == null || needSec == null || needSec <= 0)
      ? null
      : (tstSec / needSec * 100).clamp(0.0, 100.0);
  double? perf;
  if (hvn != null) {
    var num = whoopSleepPerfWeights.hours * hvn, den = whoopSleepPerfWeights.hours;
    if (consistencyPct != null) {
      num += whoopSleepPerfWeights.consistency * consistencyPct;
      den += whoopSleepPerfWeights.consistency;
    }
    if (efficiencyPct != null) {
      num += whoopSleepPerfWeights.efficiency * efficiencyPct;
      den += whoopSleepPerfWeights.efficiency;
    }
    if (highStressPct != null) {
      final stressScore = (100 - highStressPct * 10).clamp(0.0, 100.0);
      num += whoopSleepPerfWeights.stress * stressScore;
      den += whoopSleepPerfWeights.stress;
    }
    perf = (num / den).clamp(0.0, 100.0);
  }
  return WhoopSleepPerformance(
    hoursVsNeedPct: hvn,
    consistencyPct: consistencyPct,
    efficiencyPct: efficiencyPct,
    highStressPct: highStressPct,
    performancePct: perf,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// RECOVERY (patent: weighted HRV, RHR, sleep and recent strain vs baseline)
// ─────────────────────────────────────────────────────────────────────────────

/// Calibrated weights; the patents name the inputs, not the weights.
const whoopRecoveryWeights = (hrv: 0.45, rhr: 0.25, sleep: 0.15, resp: 0.15);
const int whoopRecoveryBaselineMinNights = 7;
const int whoopRecoveryBaselineNights = 30;

class WhoopRecovery {
  /// 1–99.
  final double score;
  final double? hrvZ, rhrZ, respZ, sleepTerm;
  const WhoopRecovery(this.score, {this.hrvZ, this.rhrZ, this.respZ, this.sleepTerm});
  String get band => score >= 67 ? 'green' : score >= 34 ? 'yellow' : 'red';
  Map<String, dynamic> toJson() => {
        'score': score.round(),
        'band': band,
        'hrv_z': _r2(hrvZ),
        'rhr_z': _r2(rhrZ),
        'resp_z': _r2(respZ),
        'sleep_term': _r2(sleepTerm),
      };
}

/// HRV is compared on the log scale (RMSSD is log-normal), RHR and breathing
/// rate on their own scale, each as a z-score against the user's previous
/// [whoopRecoveryBaselineNights] nights (the 30-day baseline WHOOP describes).
/// Null without last night's HRV or fewer than [whoopRecoveryBaselineMinNights]
/// baseline nights.
WhoopRecovery? whoopRecovery({
  required double? hrvMs,
  required List<double> hrvBaselineMs,
  double? rhr,
  List<double> rhrBaseline = const [],
  double? respRate,
  List<double> respBaseline = const [],
  double? sleepPerformancePct,
}) {
  if (hrvMs == null || !(hrvMs > 0)) return null;
  final base = [for (final v in hrvBaselineMs.take(whoopRecoveryBaselineNights)) if (v > 0) math.log(v)];
  if (base.length < whoopRecoveryBaselineMinNights) return null;
  final hrvZ = _z(math.log(hrvMs), base, minSd: 0.08);
  double? rhrZ, respZ, sleepTerm;
  if (rhr != null && rhrBaseline.length >= whoopRecoveryBaselineMinNights) {
    rhrZ = -_z(rhr, rhrBaseline.take(whoopRecoveryBaselineNights).toList(), minSd: 1.5);
  }
  if (respRate != null && respBaseline.length >= whoopRecoveryBaselineMinNights) {
    respZ = -_z(respRate, respBaseline.take(whoopRecoveryBaselineNights).toList(), minSd: 0.4).abs();
  }
  if (sleepPerformancePct != null) sleepTerm = (sleepPerformancePct - 80) / 15;
  var num = whoopRecoveryWeights.hrv * hrvZ.clamp(-3, 3), den = whoopRecoveryWeights.hrv;
  if (rhrZ != null) {
    num += whoopRecoveryWeights.rhr * rhrZ.clamp(-3, 3);
    den += whoopRecoveryWeights.rhr;
  }
  if (sleepTerm != null) {
    num += whoopRecoveryWeights.sleep * sleepTerm.clamp(-3, 3);
    den += whoopRecoveryWeights.sleep;
  }
  if (respZ != null) {
    num += whoopRecoveryWeights.resp * respZ.clamp(-3, 3);
    den += whoopRecoveryWeights.resp;
  }
  final composite = num / den;
  final score = (1 + 98 / (1 + math.exp(-1.1 * composite))).clamp(1.0, 99.0);
  return WhoopRecovery(score, hrvZ: hrvZ, rhrZ: rhrZ, respZ: respZ, sleepTerm: sleepTerm);
}

// ─────────────────────────────────────────────────────────────────────────────
// STRESS MONITOR BANDS (support: "Stress Monitor")
// ─────────────────────────────────────────────────────────────────────────────

/// 0–3 scale: low < 1, medium 1–2, high ≥ 2.
String whoopStressBand(double v) => v < 1 ? 'low' : v < 2 ? 'medium' : 'high';

// ─────────────────────────────────────────────────────────────────────────────
// HEALTHSPAN (2025 white paper: Δage = 10·ln(hazard ratio))
// ─────────────────────────────────────────────────────────────────────────────

class WhoopAgeFactor {
  final String key;
  final double value;
  final double hazardRatio;
  final double years;
  final String source;
  const WhoopAgeFactor(this.key, this.value, this.hazardRatio, this.years, this.source);
  Map<String, dynamic> toJson() => {
        'key': key,
        'value': _r2(value),
        'hazard_ratio': _r2(hazardRatio),
        'years': _r2(years),
        'source': source,
      };
}

class WhoopAge {
  final double chronological, whoopAge, deltaYears;
  final List<WhoopAgeFactor> factors;
  final List<String> missing;
  const WhoopAge(this.chronological, this.whoopAge, this.deltaYears, this.factors, this.missing);
  Map<String, dynamic> toJson() => {
        'chronological': _r1(chronological),
        'whoop_age': _r1(whoopAge),
        'delta_years': _r2(deltaYears),
        'factors': [for (final f in factors) f.toJson()],
        'missing': missing,
      };
}

/// The paper prints the transform (ln(HR)/0.1) and the nine factors; the
/// hazard curves below are the peer-reviewed estimates it cites or the closest
/// published ones, each named in the factor's `source`. Two calibrated guards:
/// every log-hazard is shrunk by [whoopAgeShrink] because the factors overlap
/// (the paper describes an adjustment for correlated behaviours), and each
/// factor is capped at ±[whoopAgeFactorCapYears] years.
const double whoopAgeShrink = 0.5;
const double whoopAgeFactorCapYears = 3.0;

WhoopAge? whoopAge({
  required double? chronologicalAge,
  double? sleepHoursAvg,
  double? sleepConsistencyPct,
  double? stepsAvg,
  double? zones13MinPerWeek,
  double? zones45MinPerWeek,
  double? strengthMinPerWeek,
  double? vo2max,
  double? rhrAvg,
  double? leanMassPct,
  bool female = false,
}) {
  if (chronologicalAge == null || !chronologicalAge.isFinite || chronologicalAge < 18 || chronologicalAge > 100) {
    return null;
  }
  final factors = <WhoopAgeFactor>[];
  final missing = <String>[];
  void add(String key, double? value, double? hr, String source) {
    if (value == null || hr == null || !hr.isFinite || hr <= 0) {
      missing.add(key);
      return;
    }
    final years = (10 * math.log(hr) * whoopAgeShrink).clamp(-whoopAgeFactorCapYears, whoopAgeFactorCapYears);
    factors.add(WhoopAgeFactor(key, value, hr, years, source));
  }

  // Sleep duration: U-shaped, minimum at 7–7.5 h (Cappuccio 2010: short HR 1.12, long HR 1.30).
  add(
    'sleep_hours',
    sleepHoursAvg,
    sleepHoursAvg == null ? null : math.exp(0.12 * (sleepHoursAvg - 7.25).abs().clamp(0, 3)),
    'Cappuccio 2010 (Sleep 33:585)',
  );
  // Sleep regularity: Windred 2023 — least regular vs most regular HR ≈ 1.5;
  // treated linearly between 40 % and 80 % consistency.
  add(
    'sleep_consistency',
    sleepConsistencyPct,
    sleepConsistencyPct == null ? null : 1 + 0.5 * ((80 - sleepConsistencyPct).clamp(0, 40) / 40),
    'Windred 2023 (Sleep 47:zsad253)',
  );
  // Steps: Paluch 2022 meta-analysis — risk falls ~10 % per 1 000 steps up to
  // ~10 000 (adults < 60); reference 6 000.
  add(
    'steps',
    stepsAvg,
    stepsAvg == null ? null : math.pow(0.90, (stepsAvg.clamp(2000, 10000) - 6000) / 1000).toDouble(),
    'Paluch 2022 (Lancet Public Health 7:e219)',
  );
  // Moderate activity (zones 1–3): WHO-guideline meta-analyses ≈ 20 % lower
  // mortality at 150 min/week, diminishing past 300.
  add(
    'zones_1_3',
    zones13MinPerWeek,
    zones13MinPerWeek == null ? null : math.exp(-0.0015 * zones13MinPerWeek.clamp(0, 300)),
    'Garcia 2023 (Br J Sports Med 57:979)',
  );
  // Vigorous activity (zones 4–5): 75 min/week ≈ HR 0.80.
  add(
    'zones_4_5',
    zones45MinPerWeek,
    zones45MinPerWeek == null ? null : math.exp(-0.003 * zones45MinPerWeek.clamp(0, 150)),
    'Garcia 2023 (Br J Sports Med 57:979)',
  );
  // Strength: Momma 2022 — 30–60 min/week HR ≈ 0.83, no extra benefit past ~130.
  add(
    'strength',
    strengthMinPerWeek,
    strengthMinPerWeek == null
        ? null
        : strengthMinPerWeek >= 30 && strengthMinPerWeek <= 130
        ? 0.83
        : strengthMinPerWeek > 130
        ? 0.90
        : strengthMinPerWeek >= 15
        ? 0.92
        : 1.0,
    'Momma 2022 (Br J Sports Med 56:755)',
  );
  // VO₂max: Mandsager 2018 — each MET (3.5 ml/kg/min) ≈ 12 % lower mortality;
  // age- and sex-referenced against 40 ml/kg/min at 30 falling 0.35 per year.
  if (vo2max != null) {
    final ref = (female ? 35.0 : 40.0) - 0.35 * (chronologicalAge - 30);
    add('vo2max', vo2max, math.pow(0.88, (vo2max - ref) / 3.5).toDouble(), 'Mandsager 2018 (JAMA Netw Open 1:e183605)');
  } else {
    missing.add('vo2max');
  }
  // Resting HR: Jensen 2013 — HR 1.16 per +10 bpm, reference 60.
  add(
    'resting_hr',
    rhrAvg,
    rhrAvg == null ? null : math.pow(1.16, (rhrAvg.clamp(40, 100) - 60) / 10).toDouble(),
    'Jensen 2013 (Heart 99:882)',
  );
  // Lean body mass: Srikanthan 2014 — highest vs lowest muscle-mass quartile
  // HR ≈ 0.80; linear across 70–90 % lean mass.
  add(
    'lean_mass',
    leanMassPct,
    leanMassPct == null ? null : 1 - 0.2 * ((leanMassPct.clamp(65, 90) - 65) / 25),
    'Srikanthan 2014 (Am J Med 127:547)',
  );
  if (factors.length < 3) return null;
  var delta = 0.0;
  for (final f in factors) {
    delta += f.years;
  }
  final age = (chronologicalAge + delta).clamp(18.0, 100.0);
  return WhoopAge(chronologicalAge, age, delta, factors, missing);
}

/// Pace of Aging: how fast WHOOP Age moves against the calendar. 1.0x means the
/// gap to the calendar age is unchanged; 0.0x means WHOOP Age stood still while
/// [daysBetween] calendar days passed; clamped to WHOOP's −1.0x…3.0x scale.
double whoopPaceOfAging({
  required double deltaYearsNow,
  required double deltaYearsBefore,
  required int daysBetween,
}) {
  if (daysBetween <= 0) return 1.0;
  final years = daysBetween / 365.25;
  return (1 + (deltaYearsNow - deltaYearsBefore) / years).clamp(-1.0, 3.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// helpers
// ─────────────────────────────────────────────────────────────────────────────

double _median(List<double> xs) {
  final s = [...xs]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

double _z(double x, List<double> base, {required double minSd}) {
  final n = base.length;
  final mean = base.reduce((a, b) => a + b) / n;
  var ss = 0.0;
  for (final v in base) {
    ss += (v - mean) * (v - mean);
  }
  final sd = math.max(minSd, math.sqrt(ss / math.max(1, n - 1)));
  return (x - mean) / sd;
}

double? _r1(double? v) => v == null || !v.isFinite ? null : (v * 10).round() / 10;
double? _r2(double? v) => v == null || !v.isFinite ? null : (v * 100).round() / 100;
