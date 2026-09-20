// WHOOP-parity chart kit — the Flutter twin of design/whoop-mock-v6/charts.js.
// Geometry and colours follow the WHOOP 5.x screens (Trend View W/M/6M, HR
// zones, activity HR, stress timeline, sleep). Every painter is pure: it takes
// its data and paints with theme tokens; nothing here reads a repository.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../grammar.dart';
import '../theme.dart';
import 'wh_widgets.dart';

// ── text helper ─────────────────────────────────────────────────────────────

void _txt(Canvas c, String s, Offset at, TextStyle style, {TextAlign align = TextAlign.left, double maxWidth = 200}) {
  final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, textAlign: align)..layout(maxWidth: maxWidth);
  final dx = align == TextAlign.center ? at.dx - tp.width / 2 : align == TextAlign.right ? at.dx - tp.width : at.dx;
  tp.paint(c, Offset(dx, at.dy - tp.height / 2));
}

double _niceStep(double maxV) {
  const steps = <double>[5, 10, 15, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480, 600, 720, 900];
  for (final s in steps) {
    if (s * 4 >= maxV * 1.02) return s;
  }
  return (maxV * 1.02 / 4).ceilToDouble();
}

Path _roundTopBar(double x0, double y0, double x1, double y1, double r) {
  final rr = math.min(r, (x1 - x0) / 2);
  return Path()
    ..moveTo(x0, y0)
    ..lineTo(x0, y1 + rr)
    ..quadraticBezierTo(x0, y1, x0 + rr, y1)
    ..lineTo(x1 - rr, y1)
    ..quadraticBezierTo(x1, y1, x1, y1 + rr)
    ..lineTo(x1, y0)
    ..close();
}

void _avgLine(Canvas c, double left, double w, double y) {
  final p = Paint()
    ..color = W.ink.withValues(alpha: .75)
    ..strokeWidth = 1;
  var x = left;
  while (x < w) {
    c.drawLine(Offset(x, y), Offset(math.min(x + 4, w), y), p);
    x += 8;
  }
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, y - 8, 30, 16), const Radius.circular(4)), Paint()..color = W.ink);
  _txt(c, 'СРЕД.', Offset(15, y), FW.pillAvg.copyWith(color: W.onLight), align: TextAlign.center);
}

void _todayBand(Canvas c, double x0, double w, double top, double h) {
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0, top, w, h - top), const Radius.circular(4)), Paint()..color = W.ink.withValues(alpha: .07));
}

void _twoLine(Canvas c, double x, double yTop, String label, Color color, {bool bold = false}) {
  final p = label.split(' ');
  final st = FW.axis.copyWith(color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400);
  _txt(c, p[0], Offset(x, yTop), st, align: TextAlign.center);
  if (p.length > 1) _txt(c, p.sublist(1).join(' '), Offset(x, yTop + 10), st, align: TextAlign.center);
}

/// A sized chart box; every painter below is wrapped by this.
class WcBox extends StatelessWidget {
  final CustomPainter painter;
  final double height;
  const WcBox(this.painter, {super.key, required this.height});
  @override
  Widget build(BuildContext c) => SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: painter));
}

// ── Trend View: week points / month line / six-month candles ────────────────

enum WcMode { week, month, sixMonth }

class WcTrendPainter extends CustomPainter {
  final WcMode mode;
  final List<double?> vals;
  final List<String> labels;
  final (double, double)? band;
  final Color color;
  final String Function(double) fmt;
  WcTrendPainter({required this.mode, required this.vals, required this.labels, this.band, this.color = W.sleepLine, String Function(double)? fmt})
    : fmt = fmt ?? ((v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1).replaceAll('.', ','));

  @override
  void paint(Canvas c, Size s) {
    const left = 26.0, top = 18.0;
    final w = s.width, h = s.height, bottom = h - 26;
    final all = [for (final v in vals) if (v != null) v];
    if (all.isEmpty) return;
    var lo0 = all.reduce(math.min), hi0 = all.reduce(math.max);
    if (band != null) {
      lo0 = math.min(lo0, band!.$1);
      hi0 = math.max(hi0, band!.$2);
    }
    final pad = (hi0 - lo0) * .35 == 0 ? 1.0 : (hi0 - lo0) * .35;
    final lo = lo0 - pad, hi = hi0 + pad;
    double y(double v) => bottom - (v - lo) / (hi - lo) * (bottom - top);
    double x(int i) => left + i * ((w - left - 10) / math.max(1, vals.length - 1));
    final grid = Paint()..color = W.grid;
    for (var k = 0; k < 4; k++) {
      final v = lo + (hi - lo) * k / 3;
      c.drawLine(Offset(left, y(v)), Offset(w, y(v)), grid);
      _txt(c, v.round().toString(), Offset(0, y(v)), FW.axis.copyWith(color: W.axis));
    }
    if (band != null) {
      c.drawRect(Rect.fromLTRB(left, y(band!.$2), w, math.max(y(band!.$1), y(band!.$2) + 2)), Paint()..color = W.band);
    }
    if (mode == WcMode.sixMonth) {
      final n = vals.length;
      final segW = (w - left - 10) / n;
      for (var i = 0; i < n; i++) {
        final v = vals[i];
        final x0 = left + i * segW + 6, x1 = left + (i + 1) * segW - 6;
        _txt(c, labels[i], Offset((x0 + x1) / 2, h - 6), FW.axis.copyWith(color: W.axis), align: TextAlign.center);
        if (v == null) continue;
        final prev = i > 0 ? vals[i - 1] : null;
        final ch = prev == null || prev == 0 ? 0 : ((v - prev) / prev * 100).round();
        final col = ch > 0 ? W.action : ch < 0 ? W.neg : W.ink;
        final whisker = Paint()
          ..color = W.ink.withValues(alpha: .2)
          ..strokeWidth = 1;
        for (var k = 0; k < 11; k++) {
          final wx = x0 + 3 + k * ((x1 - x0 - 6) / 10);
          final amp = (math.sin(i * 7 + k * 3) * .5 + .5) * (hi - lo) * .26 + (hi - lo) * .04;
          final off = math.cos(i * 3 + k * 5) * (hi - lo) * .08;
          c.drawLine(Offset(wx, y(v + off + amp)), Offset(wx, y(v + off - amp)), whisker);
        }
        c.drawLine(Offset(x0, y(v)), Offset(x1, y(v)), Paint()
          ..color = col
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);
        _txt(c, fmt(v), Offset((x0 + x1) / 2, y(v) - 9), FW.n10.copyWith(color: W.ink), align: TextAlign.center);
        if (i > 0 && ch != 0) _txt(c, '${ch > 0 ? '+' : ''}$ch%', Offset((x0 + x1) / 2, y(v) + 11), FW.n9.copyWith(color: col), align: TextAlign.center);
      }
      return;
    }
    final path = Path();
    var pen = false;
    for (var i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (v == null) {
        pen = false;
        continue;
      }
      if (pen) {
        path.lineTo(x(i), y(v));
      } else {
        path.moveTo(x(i), y(v));
        pen = true;
      }
    }
    c.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round);
    if (mode == WcMode.week) {
      for (var i = 0; i < vals.length; i++) {
        final v = vals[i];
        if (v != null) {
          c.drawCircle(Offset(x(i), y(v)), 4, Paint()..color = W.card);
          c.drawCircle(Offset(x(i), y(v)), 4, Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
          _txt(c, fmt(v), Offset(x(i), y(v) - 11), FW.n10.copyWith(color: W.ink), align: TextAlign.center);
        }
        _twoLine(c, x(i), h - 14, labels[i], W.axis);
      }
    } else {
      var li = vals.length - 1;
      while (li >= 0 && vals[li] == null) {
        li--;
      }
      if (li >= 0) {
        c.drawCircle(Offset(x(li), y(vals[li]!)), 4.5, Paint()..color = W.card);
        c.drawCircle(Offset(x(li), y(vals[li]!)), 4.5, Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
        _txt(c, fmt(vals[li]!), Offset(x(li) + 1, y(vals[li]!) - 11), FW.n10.copyWith(color: W.ink), align: TextAlign.center);
      }
      for (var i = vals.length - 1; i >= 0; i -= 7) {
        _twoLine(c, x(i).clamp(13, w - 13).toDouble(), h - 14, labels[i], W.axis);
      }
    }
  }

  @override
  bool shouldRepaint(WcTrendPainter o) => o.vals != vals || o.mode != mode || o.color != color;
}

// ── Value bars: week (values on top, today band) / month (thin bars, AVG) ────

class WcBarsPainter extends CustomPainter {
  final WcMode mode;
  final List<double?> vals;
  final List<String> labels;
  final List<Color> colors;
  final String Function(double) fmt;
  final List<double> yTicks;
  final String Function(double) yFmt;
  final double? avg;
  final int? todayIdx;
  final Color? valueColor;
  WcBarsPainter({
    required this.mode,
    required this.vals,
    required this.labels,
    required this.colors,
    required this.fmt,
    required this.yTicks,
    required this.yFmt,
    this.avg,
    this.todayIdx,
    this.valueColor,
  });
  @override
  void paint(Canvas c, Size s) {
    const left = 30.0, top = 24.0;
    final w = s.width, h = s.height, bottom = h - 28;
    final max = yTicks.isEmpty ? 1.0 : yTicks.last;
    double y(double v) => bottom - math.min(v, max) / max * (bottom - top);
    final n = vals.length;
    if (n == 0) return;
    final slot = (w - left) / n;
    final bw = mode == WcMode.week ? 12.0 : math.max(3.0, slot * .6);
    if (todayIdx != null) _todayBand(c, left + slot * todayIdx! + 2, slot - 4, top - 14, h);
    final grid = Paint()..color = W.grid;
    for (final t in yTicks) {
      c.drawLine(Offset(left, y(t)), Offset(w, y(t)), grid);
      _txt(c, yFmt(t), Offset(0, y(t)), FW.axis.copyWith(color: W.axis));
    }
    for (var i = 0; i < n; i++) {
      final v = vals[i];
      final cx = left + slot * i + slot / 2;
      final col = colors.length == n ? colors[i] : colors.first;
      if (v != null && v > 0) {
        c.drawPath(_roundTopBar(cx - bw / 2, bottom, cx + bw / 2, y(v), 3), Paint()..color = col);
      }
      if (mode == WcMode.week) {
        _txt(c, v == null ? '—' : fmt(v), Offset(cx, v == null ? bottom - 8 : y(v) - 8), FW.n10.copyWith(color: valueColor ?? col), align: TextAlign.center);
        _twoLine(c, cx, h - 14, labels[i], i == todayIdx ? W.ink : W.axis, bold: i == todayIdx);
      }
    }
    if (mode != WcMode.week) {
      for (var i = n - 1; i >= 0; i -= 7) {
        _twoLine(c, (left + slot * i + slot / 2).clamp(13, w - 13).toDouble(), h - 14, labels[i], W.axis);
      }
    }
    if (avg != null) _avgLine(c, left, w, y(avg!));
  }

  @override
  bool shouldRepaint(WcBarsPainter o) => o.vals != vals || o.mode != mode || o.todayIdx != todayIdx;
}

// ── Stacked bars (HR zones / restorative sleep) ──────────────────────────────

class WcStackedPainter extends CustomPainter {
  final List<List<double>?> groups;
  final List<Color> colors;
  final List<String> labels;
  final double? avg;
  final bool values;
  final String Function(double) valFmt;
  final int? todayIdx;
  final int labelEvery;
  final double? yMax;
  WcStackedPainter({
    required this.groups,
    required this.colors,
    required this.labels,
    this.avg,
    this.values = false,
    String Function(double)? valFmt,
    this.todayIdx,
    this.labelEvery = 1,
    this.yMax,
  }) : valFmt = valFmt ?? hmOf;
  @override
  void paint(Canvas c, Size s) {
    const left = 30.0, top = 24.0;
    final w = s.width, h = s.height, bottom = h - 28;
    final n = groups.length;
    if (n == 0) return;
    final tot = [for (final g in groups) g == null ? 0.0 : g.fold(0.0, (a, b) => a + b)];
    final step = yMax != null ? yMax! / 4 : _niceStep(math.max(1, tot.reduce(math.max)));
    final max = step * 4;
    double y(double v) => bottom - math.min(v, max) / max * (bottom - top);
    final slot = (w - left) / n;
    final bw = n <= 7 ? 14.0 : n <= 8 ? 36.0 : math.max(3.0, slot * .6);
    if (todayIdx != null) _todayBand(c, left + slot * todayIdx! + 2, slot - 4, top - 14, h);
    final grid = Paint()..color = W.grid;
    for (var k = 0; k <= 4; k++) {
      c.drawLine(Offset(left, y(k * step)), Offset(w, y(k * step)), grid);
      _txt(c, hmOf(k * step), Offset(0, y(k * step)), FW.axis.copyWith(color: W.axis));
    }
    for (var i = 0; i < n; i++) {
      final g = groups[i];
      final cx = left + slot * i + slot / 2;
      if (g != null) {
        var acc = 0.0;
        for (var k = 0; k < g.length; k++) {
          final v = g[k];
          if (v <= 0) continue;
          final y1 = y(acc + v), y0 = y(acc);
          final last = k == g.length - 1 || g.sublist(k + 1).every((q) => q <= 0);
          if (last) {
            c.drawPath(_roundTopBar(cx - bw / 2, y0, cx + bw / 2, y1, 3), Paint()..color = colors[k]);
          } else {
            c.drawRect(Rect.fromLTRB(cx - bw / 2, y1, cx + bw / 2, y0), Paint()..color = colors[k]);
          }
          acc += v;
        }
        if (values) _txt(c, valFmt(tot[i]), Offset(cx, y(tot[i]) - 8), FW.n10.copyWith(color: W.ink), align: TextAlign.center);
      } else if (values) {
        _txt(c, '—', Offset(cx, bottom - 8), FW.n10.copyWith(color: W.ink3), align: TextAlign.center);
      }
      if ((n - 1 - i) % labelEvery == 0) _twoLine(c, cx.clamp(13, w - 13).toDouble(), h - 14, labels[i], i == todayIdx ? W.ink : W.axis, bold: i == todayIdx);
    }
    if (avg != null) _avgLine(c, left, w, y(avg!));
  }

  @override
  bool shouldRepaint(WcStackedPainter o) => o.groups != groups || o.todayIdx != todayIdx;
}

// ── Clock bars (time in bed / consistency): 21:00 → 13:00 ───────────────────

class WcClockPainter extends CustomPainter {
  final List<(double, double)?> spans; // bed hour, wake hour (≥ 24 wraps)
  final List<String> labels;
  final Color color;
  final double start, end;
  final List<double>? optimal;
  final double barW;
  final bool showTimes;
  final int labelEvery;
  final int? todayIdx;
  WcClockPainter({
    required this.spans,
    required this.labels,
    this.color = W.sleep,
    this.start = 21,
    this.end = 13,
    this.optimal,
    this.barW = 14,
    this.showTimes = true,
    this.labelEvery = 1,
    this.todayIdx,
  });
  @override
  void paint(Canvas c, Size s) {
    const left = 34.0, top = 16.0;
    final w = s.width, h = s.height, bottom = h - 28;
    final total = ((end + 24 - start) % 24) == 0 ? 16.0 : (end + 24 - start) % 24;
    final n = spans.length;
    if (n == 0) return;
    final slot = (w - left) / n;
    double y(double hr) {
      var t = hr - start;
      while (t < 0) {
        t += 24;
      }
      return top + t / total * (bottom - top);
    }

    if (todayIdx != null) _todayBand(c, left + slot * todayIdx! + 2, slot - 4, top - 10, h);
    final grid = Paint()..color = W.grid;
    for (final t in <double>[21, 1, 5, 9, 13]) {
      c.drawLine(Offset(left, y(t)), Offset(w, y(t)), grid);
      _txt(c, '${t.toInt().toString().padLeft(2, '0')}:00', Offset(0, y(t)), FW.axis.copyWith(color: W.axis));
    }
    if (optimal != null) {
      final p = Paint()
        ..color = W.ink.withValues(alpha: .55)
        ..strokeWidth = 1;
      for (final t in optimal!) {
        var x = left;
        while (x < w) {
          c.drawLine(Offset(x, y(t)), Offset(math.min(x + 3, w), y(t)), p);
          x += 7;
        }
      }
    }
    String fmt(double t) => '${(t.floor() % 24).toString().padLeft(2, '0')}:${((t % 1) * 60).round().toString().padLeft(2, '0')}';
    for (var i = 0; i < n; i++) {
      final sp = spans[i];
      final cx = left + slot * i + slot / 2;
      if (sp != null) {
        final (b, wk) = sp;
        final yb = y(b), yw = math.max(y(wk), yb + 2);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(cx - barW / 2, yb, cx + barW / 2, yw), Radius.circular(math.min(4, barW / 2))), Paint()..color = color);
        if (showTimes) {
          _txt(c, fmt(b), Offset(cx, yb - 8), FW.n9.copyWith(color: W.ink), align: TextAlign.center);
          _txt(c, fmt(wk), Offset(cx, yw + 8), FW.n9.copyWith(color: W.ink), align: TextAlign.center);
        }
      }
      if ((n - 1 - i) % labelEvery == 0) _twoLine(c, cx.clamp(13, w - 13).toDouble(), h - 14, labels[i], i == todayIdx ? W.ink : W.axis, bold: i == todayIdx);
    }
  }

  @override
  bool shouldRepaint(WcClockPainter o) => o.spans != spans || o.todayIdx != todayIdx;
}

// ── Heart-rate area (activity detail, live HR, night HR) ───────────────────

class WcHrAreaPainter extends CustomPainter {
  final List<double?> vals;
  final Color color;
  final List<double> yTicks;
  final String startLabel, endLabel;
  final double strokeWidth;
  final bool area;
  final List<int>? stages; // optional per-sample stage 0 awake 1 light 2 rem 3 deep → band under the line
  final int? cursor;
  WcHrAreaPainter({
    required this.vals,
    this.color = W.strain,
    this.yTicks = const [100, 125, 150, 175, 200],
    this.startLabel = '',
    this.endLabel = '',
    this.strokeWidth = 1.6,
    this.area = true,
    this.stages,
    this.cursor,
  });
  @override
  void paint(Canvas c, Size s) {
    const left = 26.0, top = 8.0;
    final w = s.width, h = s.height;
    final bandH = stages == null ? 0.0 : 12.0;
    final bottom = h - 28 - bandH;
    final lo = yTicks.first, hi = yTicks.last;
    double y(double v) => bottom - ((v - lo) / (hi - lo)).clamp(-.1, 1.1).toDouble() * (bottom - top);
    final n = vals.length;
    double x(int i) => left + 6 + i * ((w - left - 12) / math.max(1, n - 1));
    final grid = Paint()..color = W.grid;
    for (final t in yTicks) {
      c.drawLine(Offset(left, y(t)), Offset(w, y(t)), grid);
      _txt(c, t.round().toString(), Offset(0, y(t)), FW.axis.copyWith(color: W.axis));
    }
    if (n > 1) {
      final line = Path();
      var pen = false;
      var firstX = x(0), lastX = x(n - 1);
      for (var i = 0; i < n; i++) {
        final v = vals[i];
        if (v == null) {
          pen = false;
          continue;
        }
        if (!pen) {
          line.moveTo(x(i), y(v));
          pen = true;
          if (i == 0) firstX = x(i);
        } else {
          line.lineTo(x(i), y(v));
        }
        lastX = x(i);
      }
      if (area) {
        final fill = Path.from(line)
          ..lineTo(lastX, bottom)
          ..lineTo(firstX, bottom)
          ..close();
        c.drawPath(
          fill,
          Paint()
            ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: .45), color.withValues(alpha: 0)]).createShader(Rect.fromLTWH(0, top, w, bottom - top)),
        );
      }
      c.drawPath(line, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round);
    }
    final dash = Paint()
      ..color = W.ink.withValues(alpha: .6)
      ..strokeWidth = 1;
    for (final (px, label, alignRight) in [(x(0), startLabel, false), (x(math.max(0, n - 1)), endLabel, true)]) {
      var yy = top;
      while (yy < bottom + 6) {
        c.drawLine(Offset(px, yy), Offset(px, math.min(yy + 3, bottom + 6)), dash);
        yy += 6;
      }
      c.drawCircle(Offset(px, bottom + 6), 2.5, Paint()..color = W.ink);
      if (label.isNotEmpty) _txt(c, label, Offset(px, h - 6), FW.n10.copyWith(color: W.ink), align: alignRight ? TextAlign.right : TextAlign.left);
    }
    if (stages != null && stages!.isNotEmpty) {
      final m = stages!.length;
      const cols = [W.awake, W.light, W.rem, W.deep];
      for (var i = 0; i < m; i++) {
        final x0 = left + 6 + i * ((w - left - 12) / m);
        final x1 = left + 6 + (i + 1) * ((w - left - 12) / m);
        c.drawRect(Rect.fromLTRB(x0, bottom + 12, x1 + .5, bottom + 19), Paint()..color = cols[stages![i].clamp(0, 3).toInt()]);
      }
    }
    if (cursor != null && n > 0) {
      final ci = cursor!.clamp(0, n - 1).toInt();
      final v = vals[ci];
      c.drawLine(Offset(x(ci), top), Offset(x(ci), bottom + 8), Paint()
        ..color = W.ink
        ..strokeWidth = 1);
      if (v != null) c.drawCircle(Offset(x(ci), y(v)), 4.5, Paint()..color = W.ink);
      c.drawCircle(Offset(x(ci), bottom + 8), 4.5, Paint()..color = W.ink);
    }
  }

  @override
  bool shouldRepaint(WcHrAreaPainter o) => o.vals != vals || o.cursor != cursor || o.color != color;
}

// ── Stress timeline: zone-coloured line to “now”, overlays, hour axis ──────

class WcStressPainter extends CustomPainter {
  final List<double?> vals;
  final double startHour;
  final double stepMin;
  final int? nowIdx;
  final (int, int)? sleep;
  final List<(int, int)> acts;
  final String? endLabel;
  final bool showZoom;
  final int? cursor;
  WcStressPainter({
    required this.vals,
    this.startHour = 0,
    this.stepMin = 5,
    this.nowIdx,
    this.sleep,
    this.acts = const [],
    this.endLabel,
    this.showZoom = true,
    this.cursor,
  });
  @override
  void paint(Canvas c, Size s) {
    const left = 26.0, top = 24.0;
    final w = s.width, h = s.height, bottom = h - 34;
    final n = vals.length;
    if (n == 0) return;
    double x(int i) => left + i * ((w - left - 12) / math.max(1, n - 1));
    double y(double v) => bottom - v / 3 * (bottom - top);
    final ni = (nowIdx ?? n - 1).clamp(0, n - 1).toInt();
    final grid = Paint()..color = W.grid;
    for (var v = 0; v <= 3; v++) {
      c.drawLine(Offset(left, y(v.toDouble())), Offset(w, y(v.toDouble())), grid);
      _txt(c, '$v,0', Offset(0, y(v.toDouble())), FW.axis.copyWith(color: W.axis));
    }
    void band(int a, int b, Color fill, Color bar) {
      final x0 = x(a.clamp(0, n - 1).toInt()), x1 = x(b.clamp(0, n - 1).toInt());
      c.drawRect(Rect.fromLTRB(x0, top, x1, bottom), Paint()..color = fill);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x0, top - 3, x1, top), const Radius.circular(1.5)), Paint()..color = bar);
    }

    if (sleep != null) band(sleep!.$1, sleep!.$2, W.ink.withValues(alpha: .05), W.sleep);
    for (final (a, b) in acts) {
      band(a, b, W.strain.withValues(alpha: .16), W.strain);
    }
    // the line, coloured per point by zone
    Offset? prev;
    Color? prevCol;
    for (var i = 0; i <= ni; i++) {
      final v = vals[i];
      if (v == null) {
        prev = null;
        continue;
      }
      final at = Offset(x(i), y(v.clamp(0, 3).toDouble()));
      final col = W.stress3(v);
      if (prev != null) {
        c.drawLine(prev, at, Paint()
          ..shader = LinearGradient(colors: [prevCol!, col]).createShader(Rect.fromPoints(prev, at))
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round);
      }
      prev = at;
      prevCol = col;
    }
    final nx = math.min(w - 4, x(ni) + 7);
    final dash = Paint()
      ..color = W.ink.withValues(alpha: .7)
      ..strokeWidth = 1;
    var yy = top - 6;
    while (yy < bottom + 8) {
      c.drawLine(Offset(nx, yy), Offset(nx, math.min(yy + 3, bottom + 8)), dash);
      yy += 6;
    }
    c.drawCircle(Offset(nx, bottom + 8), 2.5, Paint()..color = W.ink);
    final lastV = vals[ni];
    if (lastV != null) c.drawCircle(Offset(x(ni), y(lastV.clamp(0, 3).toDouble())), 4, Paint()..color = W.stress3(lastV));
    if (showZoom) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w - 46, bottom - 46, 36, 36), const Radius.circular(10)), Paint()..color = W.bg);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w - 46, bottom - 46, 36, 36), const Radius.circular(10)), Paint()
        ..color = W.line
        ..style = PaintingStyle.stroke);
      final zp = Paint()
        ..color = W.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      c.drawCircle(Offset(w - 28, bottom - 28), 7, zp);
      c.drawLine(Offset(w - 23, bottom - 23), Offset(w - 18, bottom - 18), zp);
      c.drawLine(Offset(w - 32, bottom - 28), Offset(w - 24, bottom - 28), zp);
    }
    double hourAt(int i) => startHour + i * stepMin / 60;
    final firstH = (hourAt(0) / 4).ceil() * 4;
    for (var hh = firstH; hh < hourAt(ni); hh += 4) {
      final i = ((hh - startHour) * 60 / stepMin).round();
      if (i < 0 || i > n - 1 || x(ni) - x(i) < 34) continue;
      _txt(c, '${(hh % 24).toString().padLeft(2, '0')}:00', Offset(x(i), h - 6), FW.axis.copyWith(color: W.axis), align: TextAlign.center);
    }
    final endH = hourAt(ni);
    final endTxt = endLabel ?? '${(endH.floor() % 24).toString().padLeft(2, '0')}:${((endH % 1) * 60).round().toString().padLeft(2, '0')}';
    _txt(c, endTxt, Offset(nx, h - 6), FW.n10.copyWith(color: W.ink), align: TextAlign.right);
    if (cursor != null) {
      final ci = cursor!.clamp(0, n - 1).toInt();
      c.drawLine(Offset(x(ci), top), Offset(x(ci), bottom), Paint()
        ..color = W.ink
        ..strokeWidth = 1);
      final v = vals[ci];
      if (v != null) c.drawCircle(Offset(x(ci), y(v.clamp(0, 3).toDouble())), 4.5, Paint()..color = W.ink);
    }
  }

  @override
  bool shouldRepaint(WcStressPainter o) => o.vals != vals || o.nowIdx != nowIdx || o.cursor != cursor;
}

// ── Rings, dial, gauge ──────────────────────────────────────────────────────

class WcRingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final double stroke;
  final double? goal;
  WcRingPainter(this.fraction, this.color, {this.stroke = 7, this.goal});
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(stroke / 2, stroke / 2, s.width - stroke, s.height - stroke);
    c.drawArc(r, 0, math.pi * 2, false, Paint()
      ..color = W.track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    if (fraction > 0) {
      c.drawArc(r, -math.pi / 2, math.pi * 2 * fraction.clamp(0, 1).toDouble(), false, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round);
    }
    if (goal != null) {
      final a = -math.pi / 2 + math.pi * 2 * goal!.clamp(0, 1).toDouble();
      final cx = s.width / 2, cy = s.height / 2, rad = (s.width - stroke) / 2;
      final p1 = Offset(cx + math.cos(a) * (rad - stroke * .45), cy + math.sin(a) * (rad - stroke * .45));
      final p2 = Offset(cx + math.cos(a) * (rad + stroke * .45), cy + math.sin(a) * (rad + stroke * .45));
      c.drawLine(p1, p2, Paint()
        ..color = W.ink
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.butt);
    }
  }

  @override
  bool shouldRepaint(WcRingPainter o) => o.fraction != fraction || o.color != color || o.goal != goal;
}

/// Home ring: 88 pt, value inside, uppercase label with chevron below.
class WcRing extends StatelessWidget {
  final String label, value;
  final String? suffix;
  final double? fraction;
  final Color color;
  final VoidCallback? onTap;
  const WcRing({super.key, required this.label, required this.value, this.suffix, required this.fraction, required this.color, this.onTap});
  @override
  Widget build(BuildContext c) => Pressable(
    onTap: onTap,
    semanticLabel: '$label: $value${suffix ?? ''}',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 88,
          height: 88,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (fraction ?? 0).clamp(0.0, 1.0)),
            duration: motion(c, Motion.slow),
            builder: (c, v, child) => CustomPaint(painter: WcRingPainter(v, color), child: child),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(value, style: FW.n24.copyWith(color: W.ink)),
                  if (suffix != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(suffix!, style: FW.n12.copyWith(color: W.ink))),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: S.x2 + 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label.toUpperCase(), style: FW.over.copyWith(color: W.ink, letterSpacing: .55), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 3),
            const WhIcon('navigation_forward', size: 9, color: W.ink4),
          ],
        ),
      ],
    ),
  );
}

/// The detail dial: 250 pt, stroke 16, wordmark, big number, caption, seg3.
class WcDial extends StatelessWidget {
  final Color color;
  final double? fraction;
  final String big;
  final String? suffix;
  final String caption;
  final int? seg;
  final double? goal;
  final String wordmark;
  const WcDial({super.key, required this.color, required this.fraction, required this.big, this.suffix, required this.caption, this.seg, this.goal, this.wordmark = 'WHOOD'});
  @override
  Widget build(BuildContext c) => Center(
    child: SizedBox(
      width: 250,
      height: 250,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (fraction ?? 0).clamp(0.0, 1.0)),
        duration: motion(c, Motion.slow),
        builder: (c, v, child) => CustomPaint(painter: WcRingPainter(v, color, stroke: 16, goal: goal), child: child),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(wordmark, style: FW.wordmark.copyWith(color: W.axis)),
              const SizedBox(height: S.x2 + 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(big, style: FW.n62.copyWith(color: W.ink)),
                  if (suffix != null) Padding(padding: const EdgeInsets.only(top: 14, left: 2), child: Text(suffix!, style: FW.n28.copyWith(color: W.ink))),
                ],
              ),
              const SizedBox(height: S.x2),
              Text(caption.toUpperCase(), style: FW.label.copyWith(color: W.ink), textAlign: TextAlign.center),
              if (seg != null) Padding(padding: const EdgeInsets.only(top: S.x2 + 2), child: WhSeg3(seg!)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Stress gauge: full gradient arc with a white needle.
class WcGaugePainter extends CustomPainter {
  final double value; // 0..3
  WcGaugePainter(this.value);
  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2, cy = s.height - 15, r = math.min(s.width / 2 - 20, s.height - 30);
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    c.drawArc(rect, math.pi, math.pi, false, Paint()
      ..shader = const LinearGradient(colors: [W.stressLow, W.stressMed, W.stressHigh]).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round);
    final a = math.pi + math.pi * (value.clamp(0, 3).toDouble() / 3);
    final p1 = Offset(cx + math.cos(a) * (r - 14), cy + math.sin(a) * (r - 14));
    final p2 = Offset(cx + math.cos(a) * (r + 8), cy + math.sin(a) * (r + 8));
    c.drawLine(p1, p2, Paint()
      ..color = W.ink
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(WcGaugePainter o) => o.value != value;
}

// ── HTML-ish pieces: hatched rows, hours vs needed, factor bar, breakdown ─────

/// Hatched track with a filled share and a dashed “typical range” window.
class WcHatchRow extends StatelessWidget {
  final String label;
  final String? sub;
  final int? pct;
  final Color color;
  final (int, int)? range;
  final Widget value;
  final bool circle, filled;
  const WcHatchRow({super.key, required this.label, this.sub, this.pct, required this.color, this.range, required this.value, this.circle = false, this.filled = false});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.fromLTRB(0, S.x2 + 2, 0, S.x3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (circle)
              Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: filled ? color : W.ink, width: 2), color: filled ? color : null))
            else
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: WR.rTiny)),
            const SizedBox(width: S.x2 + 2),
            Text(label.toUpperCase(), style: FW.label.copyWith(color: W.ink)),
            if (sub != null) ...[const SizedBox(width: S.x2), Text(sub!, style: FW.hint.copyWith(color: W.ink3))],
            if (pct != null) ...[const SizedBox(width: S.x2), Text('$pct%', style: FW.n11.copyWith(color: color))],
            const Spacer(),
            value,
          ],
        ),
        const SizedBox(height: S.x2),
        SizedBox(
          height: 22,
          child: CustomPaint(painter: _HatchPainter(pct: pct, color: color, range: range)),
        ),
      ],
    ),
  );
}

class _HatchPainter extends CustomPainter {
  final int? pct;
  final Color color;
  final (int, int)? range;
  _HatchPainter({required this.pct, required this.color, this.range});
  @override
  void paint(Canvas c, Size s) {
    final track = Rect.fromLTWH(0, 3, s.width, 16);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(track, const Radius.circular(5)));
    c.drawRect(track, Paint()..color = W.card2);
    final hp = Paint()
      ..color = W.card
      ..strokeWidth = 3;
    for (var x = -20.0; x < s.width + 20; x += 8) {
      c.drawLine(Offset(x, 22), Offset(x + 20, 0), hp);
    }
    c.restore();
    if (pct != null && pct! > 0) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 3, s.width * pct!.clamp(0, 100).toDouble() / 100, 16), const Radius.circular(5)), Paint()..color = color);
    }
    if (range != null) {
      final x0 = s.width * range!.$1 / 100, x1 = s.width * range!.$2 / 100;
      c.drawRect(Rect.fromLTRB(x0, 0, x1, 22), Paint()..color = W.ink.withValues(alpha: .08));
      final dp = Paint()
        ..color = W.ink4
        ..strokeWidth = 1.5;
      for (final xx in [x0, x1]) {
        var yy = 0.0;
        while (yy < 22) {
          c.drawLine(Offset(xx, yy), Offset(xx, math.min(yy + 3, 22)), dp);
          yy += 6;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HatchPainter o) => o.pct != pct || o.range != range || o.color != color;
}

/// “Часы против потребности”: two bars, legend of the need's three parts.
class WcHoursVsNeeded extends StatelessWidget {
  final double sleptMin, needMin, healthyMin, strainAddMin, debtMin;
  final int pct;
  final int? prevPct;
  final Widget? info;
  const WcHoursVsNeeded({super.key, required this.sleptMin, required this.needMin, required this.healthyMin, required this.strainAddMin, required this.debtMin, required this.pct, this.prevPct, this.info});
  @override
  Widget build(BuildContext c) {
    final max = math.max(sleptMin, needMin) * 1.05;
    double frac(double v) => max <= 0 ? 0 : (v / max).clamp(0, 1).toDouble();
    Widget bar(List<(double, Color)> parts) => SizedBox(
      height: 14,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (c, box) => Stack(
          children: [
            Container(decoration: BoxDecoration(color: W.card2, borderRadius: WR.rBar)),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: WR.rBar,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (final (v, col) in parts) Container(width: box.maxWidth * frac(v), color: col)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: S.x1 + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(label.toUpperCase(), style: FW.label.copyWith(color: W.ink2))),
          Text(value, style: FW.n17.copyWith(color: W.ink)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('ЧАСЫ ПРОТИВ ПОТРЕБНОСТИ', style: FW.label.copyWith(color: W.ink))),
            info ?? const WhInfoDot(size: 20),
          ],
        ),
        const SizedBox(height: S.x1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('$pct%', style: FW.n28.copyWith(color: W.ink)),
            const SizedBox(width: S.x2),
            if (prevPct != null) WhTri(pct >= prevPct! ? 'up' : 'dn'),
          ],
        ),
        if (prevPct != null) Text('$prevPct%', style: FW.hint.copyWith(color: W.ink3)),
        const SizedBox(height: S.x2),
        row('Часы сна', hmOf(sleptMin)),
        bar([(sleptMin, W.sleep)]),
        const SizedBox(height: S.x3 + 2),
        bar([(healthyMin, W.track), (strainAddMin, W.strain), (debtMin, W.sufficient)]),
        row('Потребность во сне', hmOf(needMin)),
        Container(
          margin: const EdgeInsets.only(top: S.x2),
          padding: const EdgeInsets.all(S.x3),
          decoration: BoxDecoration(color: W.bg, borderRadius: WR.rChip),
          child: Column(
            children: [
              for (final (col, label, val) in [(W.track, 'Здоровый минимум', hmOf(healthyMin)), (W.strain, 'Недавняя нагрузка', '+${hmOf(strainAddMin)}'), (W.sufficient, 'Недосып', '+${hmOf(debtMin)}')])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: col, borderRadius: WR.rTiny)),
                      const SizedBox(width: S.x2 + 2),
                      Expanded(child: Text(label, style: FW.body.copyWith(color: W.ink2))),
                      Text(val, style: FW.n12.copyWith(color: W.ink)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Healthspan factor: gradient scale with the 6-month and 30-day markers.
class WcFactorBar extends StatelessWidget {
  final String label;
  final double p30, p6; // 0..100 positions
  final String v30, v6, lo, hi;
  final double years;
  final String text;
  final bool good;
  final VoidCallback? onTrend;
  const WcFactorBar({super.key, required this.label, required this.p30, required this.p6, required this.v30, required this.v6, required this.lo, required this.hi, required this.years, required this.text, required this.good, this.onTrend});
  @override
  Widget build(BuildContext c) {
    double cl(double p) => p.clamp(3, 97).toDouble();
    return Container(
      padding: const EdgeInsets.only(top: S.x3 + 2, bottom: S.x2),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: W.line2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(label.toUpperCase(), style: FW.label.copyWith(color: W.ink))), const WhIcon('caret_up', size: 12, color: W.ink4)]),
          const SizedBox(height: S.x1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (c, box) {
                    final wdt = box.maxWidth;
                    return Column(
                      children: [
                        if (v6.isNotEmpty)
                          SizedBox(
                            height: 30,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: (wdt * cl(p6) / 100 - 60).clamp(0, math.max(0, wdt - 120)).toDouble(),
                                  bottom: 0,
                                  width: 120,
                                  child: Column(
                                    children: [
                                      Text('Среднее за 6 мес', style: FW.tiny.copyWith(color: W.ink3)),
                                      Text(v6, style: FW.n11.copyWith(color: W.ink)),
                                      const SizedBox(height: 2),
                                      CustomPaint(size: const Size(10, 6), painter: _TriPainter()),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox(height: S.x2),
                        SizedBox(
                          height: 16,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Row(
                                children: [
                                  for (var i = 0; i < 13; i++)
                                    Expanded(
                                      flex: i == 0 || i == 12 ? 22 : 10,
                                      child: Container(
                                        margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                                        decoration: BoxDecoration(
                                          borderRadius: i == 0 ? const BorderRadius.horizontal(left: Radius.circular(4)) : i == 12 ? const BorderRadius.horizontal(right: Radius.circular(4)) : WR.rTiny,
                                          gradient: i == 3 ? const LinearGradient(colors: [W.neg, W.track]) : i == 9 ? const LinearGradient(colors: [W.track, W.action]) : null,
                                          color: i < 3 ? W.neg : i > 9 ? W.action : i == 3 || i == 9 ? null : W.track,
                                        ),
                                        child: i == 0 || i == 12 ? Center(child: Text(i == 0 ? lo : hi, style: FW.n9.copyWith(color: W.onLight), maxLines: 1)) : null,
                                      ),
                                    ),
                                ],
                              ),
                              Positioned(left: wdt * cl(p30) / 100 - 1.5, top: -2, child: Container(width: 3, height: 20, decoration: BoxDecoration(color: W.ink, borderRadius: WR.rTiny))),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 34,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: (wdt * cl(p30) / 100 - 60).clamp(0, math.max(0, wdt - 120)).toDouble(),
                                top: 6,
                                width: 120,
                                child: Column(children: [Text(v30, style: FW.n12.copyWith(color: W.ink)), Text('Среднее за 30 дней', style: FW.tiny.copyWith(color: W.ink3))]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: S.x2 + 2),
              SizedBox(
                width: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${years > 0 ? '+' : ''}${ruDecimal(years)}', style: FW.n17.copyWith(color: years <= 0 ? W.action : W.neg)),
                    Text(years.abs() == 1 ? 'год' : years.abs() > 1 && years.abs() < 5 ? 'года' : 'лет', style: FW.tiny.copyWith(color: W.ink3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: S.x2),
          Text(good ? 'Лучше нормы' : 'Есть куда расти', style: FW.b1.copyWith(color: W.ink)),
          const SizedBox(height: S.x1),
          Text(text, style: FW.body.copyWith(color: W.ink2)),
          if (onTrend != null) ...[
            const SizedBox(height: S.x2),
            Pressable(onTap: onTrend, child: Text('СМОТРЕТЬ ТРЕНД →', style: FW.over.copyWith(color: W.link))),
          ],
        ],
      ),
    );
  }
}

class _TriPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) => c.drawPath(Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width / 2, s.height)
    ..close(), Paint()..color = W.ink);
  @override
  bool shouldRepaint(_TriPainter o) => false;
}

/// “Разбивка (дни)”: segmented bar + counts.
class WcBreakdown extends StatelessWidget {
  final String title;
  final List<(int, String, Color)> segs;
  const WcBreakdown({super.key, required this.title, required this.segs});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(top: S.x3 + 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Text(title.toUpperCase(), style: FW.label.copyWith(color: W.ink)), const SizedBox(width: S.x1 + 2), Text('(дни)', style: FW.hint.copyWith(color: W.ink3))]),
        const SizedBox(height: S.x2),
        ClipRRect(
          borderRadius: WR.rTiny,
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                for (final (n, _, col) in segs)
                  if (n > 0) Expanded(flex: n, child: Container(color: col, margin: const EdgeInsets.only(right: 2))),
              ],
            ),
          ),
        ),
        const SizedBox(height: S.x2 + 2),
        for (final (n, label, col) in segs)
          Padding(
            padding: const EdgeInsets.only(bottom: S.x1 + 2),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: col, borderRadius: WR.rTiny)),
                const SizedBox(width: S.x2),
                SizedBox(width: 26, child: Text('$n×', style: FW.n12.copyWith(color: W.ink))),
                Text(label, style: FW.sub.copyWith(color: W.ink2)),
              ],
            ),
          ),
      ],
    ),
  );
}

/// The five-segment zone bar under the live pulse card.
class WcZoneBar extends StatelessWidget {
  final int on; // 0 none, 1..5
  const WcZoneBar(this.on, {super.key});
  @override
  Widget build(BuildContext c) => Row(
    children: [
      for (var i = 1; i <= 5; i++)
        Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(left: i == 1 ? 0 : 3),
            decoration: BoxDecoration(color: i == on ? W.strain : W.card3, borderRadius: WR.rBar),
          ),
        ),
    ],
  );
}

/// Stress “stack” bar: low / medium / high shares in one row.
class WcStressStack extends StatelessWidget {
  final List<double> minutes; // low, med, high
  final double height;
  final double opacity;
  const WcStressStack(this.minutes, {super.key, this.height = 12, this.opacity = 1});
  @override
  Widget build(BuildContext c) {
    final total = minutes.fold(0.0, (a, b) => a + b);
    return Opacity(
      opacity: opacity,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(3)),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  flex: total <= 0 ? 1 : math.max(1, (minutes[i] / total * 1000).round()),
                  child: Container(color: [W.stressLow, W.stressMed, W.stressHigh][i], margin: EdgeInsets.only(left: i == 0 ? 0 : 3)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
