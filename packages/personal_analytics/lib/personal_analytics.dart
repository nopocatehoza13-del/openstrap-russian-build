/// Independently expressed arithmetic described in the NOOP public model audit.
/// Not a medical model, not WHOOP Age, and not a clinical risk prediction.
/// Does not modify or persist OpenStrap's canonical analytics outputs.
library;

import 'dart:math' as math;

typedef DailyValue = ({String day, double value});

class AgeEstimate {
  final double chronological, estimated;
  final Map<String, double> contributions;
  final Map<String, int> samples;
  final String from, through;
  const AgeEstimate(
    this.chronological,
    this.estimated,
    this.contributions,
    this.samples,
    this.from,
    this.through,
  );
}

double rmssdReference(double age) {
  const refs = [47.0, 40.0, 33.0, 29.0, 25.0, 22.0, 20.0];
  final x = ((age - 20) / 10).clamp(0.0, 6.0);
  final i = x.floor();
  if (i == 6) return refs.last;
  return refs[i] + (refs[i + 1] - refs[i]) * (x - i);
}

/// Requires three separately measured quantities (RHR, HRV, sleep or steps).
/// Sleep variability is an extra factor, not a second independent measurement.
/// A seven-day calendar window and >=3 samples per quantity are local safeguards,
/// deliberately stricter than NOOP's caller. No invented factor or confidence.
AgeEstimate? estimateAge({
  required double? age,
  required DateTime end,
  List<DailyValue> rhr = const [],
  List<DailyValue> hrv = const [],
  List<DailyValue> sleepHours = const [],
  List<DailyValue> steps = const [],
}) {
  if (age == null || !age.isFinite || age < 20 || age > 90) return null;
  String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final through = day(end);
  final from = day(DateTime(end.year, end.month, end.day - 6));
  List<double> valid(List<DailyValue> rows, double lo, double hi) {
    final unique = <String, double>{};
    for (final r in rows) {
      if (r.day.compareTo(from) >= 0 &&
          r.day.compareTo(through) <= 0 &&
          r.value.isFinite &&
          r.value >= lo &&
          r.value <= hi) {
        unique[r.day] = r.value;
      }
    }
    return unique.length < 3 ? [] : unique.values.toList();
  }

  final r = valid(rhr, 30, 120), h = valid(hrv, 5, 250);
  final s = valid(sleepHours, 2, 14), st = valid(steps, 0, 80000);
  if ([r, h, s, st].where((e) => e.isNotEmpty).length < 3) return null;
  double mean(List<double> a) => a.reduce((a, b) => a + b) / a.length;
  double median(List<double> a) {
    final b = [...a]..sort();
    final m = b.length ~/ 2;
    return b.length.isOdd ? b[m] : (b[m - 1] + b[m]) / 2;
  }

  final terms = <String, double>{}, counts = <String, int>{};
  void add(String name, double term, int n) {
    terms[name] = term;
    counts[name] = n;
  }

  if (r.isNotEmpty) add('rhr', (median(r) - 65) / 10 * .100, r.length);
  if (h.isNotEmpty) {
    final norm = rmssdReference(age);
    add('hrv', ((norm - median(h)) / norm).clamp(-1.0, 1.0) * .160, h.length);
  }
  if (s.isNotEmpty) {
    final avg = mean(s);
    add(
      'sleep',
      math.max(0.0, (avg - 7.5).abs() - .5).clamp(0.0, 3.0) * .110,
      s.length,
    );
    final sd = math.sqrt(
      s.map((x) => math.pow(x - avg, 2)).reduce((a, b) => a + b) / s.length,
    );
    add('consistency', (.75 - (1 - sd / avg).clamp(0.0, 1.0)) * .450, s.length);
  }
  if (st.isNotEmpty) {
    add(
      'steps',
      ((7000 - mean(st).clamp(0.0, 11000.0)) / 1000).clamp(-4.0, 4.0) * .064,
      st.length,
    );
  }
  final years = {
    for (final e in terms.entries) e.key: e.value * .75 / (math.ln2 / 8),
  };
  final out = (age + years.values.reduce((a, b) => a + b)).clamp(20.0, 90.0);
  return AgeEstimate(
    age,
    out,
    Map.unmodifiable(years),
    Map.unmodifiable(counts),
    from,
    through,
  );
}
