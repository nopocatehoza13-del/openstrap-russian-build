// Trend View — WHOOP's W / M / 6M metric screen over the stored series.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/day_label.dart';
import '../grammar.dart';
import '../screens/home_screen.dart' show ChartPoint;
import '../theme.dart';
import 'wh_data.dart';
import 'wh_widgets.dart';
import 'whoop_charts.dart';

enum _Kind { line, bars, stacked, clock, none }

class _Meta {
  final String label, unit, icon;
  final _Kind kind;
  final List<String> keys; // series keys (stacked: one per layer)
  final List<Color> colors;
  final String Function(double) fmt;
  final List<double>? yTicks;
  final String Function(double)? yFmt;
  final bool lowerBetter;
  final String what, improve;
  final List<(double, String, Color)>? bands; // breakdown thresholds (≥ value → label)
  const _Meta(this.label, this.unit, this.icon, this.kind, this.keys, this.colors, this.fmt, {this.yTicks, this.yFmt, this.lowerBetter = false, required this.what, required this.improve, this.bands});
}

String _pct(double v) => '${v.round()}%';
String _int(double v) => '${v.round()}';

final _meta = <String, _Meta>{
  'hrv': _Meta('Вариабельность ритма', 'мс', 'hrv', _Kind.line, ['hrv'], [W.sleepLine], _int, what: 'RMSSD за ночь: разброс интервалов между ударами. Выше вашей нормы — организм восстановлен, ниже — накопленная нагрузка, стресс или начало болезни. Сравнивайте только с собой.', improve: 'Регулярный отбой, отказ от алкоголя вечером, дыхательные сессии и лёгкие дни после тяжёлых — самые надёжные способы поднять ВСР.'),
  'resting_hr': _Meta('Пульс в покое', 'уд/мин', 'rhr', _Kind.line, ['resting_hr'], [W.sleepLine], _int, lowerBetter: true, what: 'Самый низкий устойчивый пульс за ночь. Рост на 5+ уд/мин относительно нормы часто предшествует болезни или перегрузке.', improve: 'Аэробные тренировки, достаточный сон и гидратация снижают пульс покоя за несколько недель.'),
  'respiratory_rate': _Meta('Частота дыхания', '/мин', 'respiratory_rate', _Kind.line, ['resp_rate'], [W.sleepLine], (v) => ruDecimal(v), what: 'Вдохов в минуту во сне. Очень стабильный показатель: отклонение на 1+ /мин от нормы — сигнал проверить самочувствие.', improve: 'Специально улучшать не нужно: следите за отклонениями и высыпайтесь.'),
  'steps': _Meta('Шаги', '', 'steps', _Kind.bars, ['steps'], [W.strain], groupThousands, yTicks: [0, 5000, 10000, 15000, 20000], yFmt: (v) => v == 0 ? '0' : '${(v / 1000).round()} тыс.', what: 'Шаги, посчитанные браслетом по движению. Один из девяти факторов Healthspan.', improve: 'Каждая дополнительная 1 000 шагов в день снижает риск примерно на 10 % до уровня 8–10 тысяч.'),
  'calories': _Meta('Энергозатраты', 'ккал', 'calories', _Kind.bars, ['calories'], [W.strain], groupThousands, yTicks: [0, 1000, 2000, 3000, 4000], yFmt: (v) => v == 0 ? '0' : '${(v / 1000).toStringAsFixed(1).replaceAll('.', ',')} тыс.', what: 'Активные калории по пульсу плюс базовый обмен.', improve: 'Ориентируйтесь на тренд, а не на число: погрешность оценки по пульсу ±15 %.'),
  'strain': _Meta('Нагрузка за день', '', 'strain', _Kind.bars, ['whoop_strain'], [W.strain], (v) => ruDecimal(v), yTicks: [0, 5, 10, 15, 21], yFmt: _int, what: 'Сердечно-сосудистая нагрузка 0–21 по формуле патента WHOOP: взвешенный интеграл резерва пульса за день на шкале arctan. 0–9 лёгкая, 10–13 умеренная, 14–17 высокая, 18–21 предельная.', improve: 'Держитесь целевого диапазона по восстановлению: зелёный день — можно 14+, красный — до 10.', bands: [(18, 'Предельная (≥18,0)', W.strain), (14, 'Высокая (14,0–17,9)', W.strainMid), (10, 'Умеренная (10,0–13,9)', W.strainLight), (0, 'Лёгкая (<10,0)', W.strainPale)]),
  'recovery': _Meta('Восстановление', '%', 'recovery', _Kind.bars, ['whoop_recovery'], [W.recHigh], _pct, yTicks: [0, 25, 50, 75, 100], yFmt: _pct, what: 'ВСР, пульс в покое, дыхание относительно вашей 30-дневной нормы плюс показатель сна. Зелёная зона от 67 %, жёлтая 34–66 %, красная до 33 % — пороги WHOOP.', improve: 'Сон по потребности и регулярный отбой поднимают восстановление сильнее всего; тяжёлые тренировки ставьте на зелёные дни.', bands: [(67, 'Зелёное (67–99 %)', W.recHigh), (34, 'Жёлтое (34–66 %)', W.recMed), (0, 'Красное (1–33 %)', W.recLow)]),
  'sleepperf': _Meta('Показатель сна', '%', 'sleep_performance', _Kind.bars, ['whoop_sleep_perf'], [W.sleep], _pct, yTicks: [0, 25, 50, 75, 100], yFmt: _pct, what: 'Часы против потребности, регулярность, эффективность и стресс во сне — четыре компонента с порогами WHOOP: оптимально от 85 %, достаточно 70–84 %.', improve: 'Самый весомый компонент — часы против потребности: ложитесь к рекомендованному отбою.', bands: [(85, 'Оптимально (85 %+)', W.action), (70, 'Достаточно (70–84 %)', W.sufficient), (0, 'Слабо (<70 %)', W.neg)]),
  'consistency': _Meta('Регулярность сна', '%', 'consistency', _Kind.bars, ['whoop_consistency'], [W.sleep], _pct, yTicks: [0, 25, 50, 75, 100], yFmt: _pct, what: 'Насколько отбой и подъём последней ночи совпадают с предыдущими четырьмя. 80 %+ оптимально, 70–79 % достаточно.', improve: 'Одно время отбоя и подъёма ±30 минут, включая выходные.', bands: [(80, 'Оптимально (80 %+)', W.action), (70, 'Достаточно (70–79 %)', W.sufficient), (0, 'Слабо (<70 %)', W.neg)]),
  'hours': _Meta('Часы сна', '', 'hours_of_sleep', _Kind.bars, ['sleep'], [W.sleep], hmOf, yTicks: [0, 150, 300, 450, 600], yFmt: hmOf, what: 'Чистое время сна за ночь без бодрствования.', improve: 'Сравнивайте с потребностью, а не с 8 часами: она своя у каждого.'),
  'need': _Meta('Потребность во сне', '', 'sleep_need', _Kind.bars, ['whoop_need_min'], [W.sleep], hmOf, yTicks: [0, 150, 300, 450, 600], yFmt: hmOf, what: 'Личная норма + надбавка за нагрузку дня + недосып − дрёмы, по заявке WHOOP US 2024/0252121.', improve: 'Недосып гасится постепенно: половина долга за ночь, не больше полутора часов.'),
  'restorative': _Meta('Восстанавливающий сон', '', 'restorative_sleep', _Kind.stacked, ['deep', 'rem'], [W.deep, W.rem], hmOf, what: 'Глубокий (SWS) и REM-сон: физическое и умственное восстановление.', improve: 'Алкоголь, жара и поздняя тренировка режут эти стадии сильнее всего.'),
  'tib': _Meta('Время в постели', '', 'time_in_bed', _Kind.clock, [], [W.sleep], hmOf, what: 'Отбой и подъём по ночам: ровный столбик из ночи в ночь и есть регулярность.', improve: 'Двигайте сначала отбой, подъём держите постоянным.'),
  'zones13': _Meta('Зоны пульса 1–3', '', 'hr_zone_3', _Kind.stacked, ['whoop_z13_min'], [W.z2], hmOf, what: 'Минуты при 50–80 % резерва пульса за день — умеренная нагрузка. Цель ВОЗ — 150 минут в неделю.', improve: 'Быстрая ходьба и лёгкое кардио уже считаются.'),
  'zones45': _Meta('Зоны пульса 4–5', '', 'hr_zone_4_5', _Kind.stacked, ['whoop_z45_min'], [W.z4], hmOf, what: 'Минуты при 80–100 % резерва пульса — интенсивная нагрузка. Цель — 75 минут в неделю.', improve: 'Интервалы 1–2 раза в неделю на зелёные дни.'),
  'heart_rate': _Meta('Кислород в крови', '%', 'heart_rate', _Kind.none, [], [W.sleepLine], _int, what: 'SpO₂ появляется только из импорта WHOOP: относительный оптический сигнал браслета в проценты не переводится.', improve: ''),
  'skin_temperature': _Meta('Температура кожи', '°C', 'skin_temperature', _Kind.none, [], [W.sleepLine], _int, what: 'Только измерения в °C из импорта WHOOP.', improve: ''),
};

class WhTrend extends StatefulWidget {
  final String metric;
  final WhView view;
  const WhTrend(this.metric, {super.key, required this.view});
  @override
  State<WhTrend> createState() => _WhTrendState();
}

class _WhTrendState extends State<WhTrend> {
  int period = 1; // 0 W, 1 M, 2 6M
  int shift = 0; // periods back

  @override
  Widget build(BuildContext c) {
    final m = _meta[widget.metric] ?? _meta['hrv']!;
    final v = widget.view;
    final end = period == 0 ? DateTime(v.date.year, v.date.month, v.date.day - 7 * shift) : period == 1 ? DateTime(v.date.year, v.date.month, v.date.day - 30 * shift) : DateTime(v.date.year, v.date.month - 6 * shift, v.date.day);
    final n = period == 0 ? 7 : period == 1 ? 30 : 0;
    List<ChartPoint> series(String key) => switch (key) {
      'hrv' || 'resting_hr' || 'resp_rate' || 'sleep' => v.d.health.points(key),
      'steps' => v.d.steps,
      'whoop_strain' => (v.d.series['whoop_strain']?.isNotEmpty ?? false) ? v.d.series['whoop_strain']! : v.d.strain,
      'whoop_recovery' => (v.d.series['whoop_recovery']?.isNotEmpty ?? false) ? v.d.series['whoop_recovery']! : v.d.recovery,
      _ => v.d.series[key] ?? const [],
    };
    final labelsW = [for (var i = 6; i >= 0; i--) dowShort(DateTime(end.year, end.month, end.day - i))];
    final labelsM = [for (var i = 29; i >= 0; i--) dayShort(DateTime(end.year, end.month, end.day - i))];
    final months = [for (var k = 5; k >= 0; k--) DateTime(end.year, end.month - k, 1)];
    final labels6 = [for (final mo in months) ruMonthsShort[mo.month - 1][0].toUpperCase() + ruMonthsShort[mo.month - 1].substring(1)];
    List<double?> monthly(List<ChartPoint> pts, {bool sum = false}) => [
      for (final mo in months)
        () {
          final xs = [for (final p in pts) if (DateTime.fromMillisecondsSinceEpoch(p.t * 1000).year == mo.year && DateTime.fromMillisecondsSinceEpoch(p.t * 1000).month == mo.month) p.v];
          if (xs.isEmpty) return null;
          final s = xs.reduce((a, b) => a + b);
          return sum ? s : s / xs.length;
        }(),
    ];
    List<double?> window(List<ChartPoint> pts) => trailing(pts, end, n, excludeEnd: false);
    Widget chart;
    List<double?> vals = const [];
    double? avg, prevAvg;
    String rangeTxt = period == 0 ? '${DateTime(end.year, end.month, end.day - 6).day} – ${dayShort(end)}' : period == 1 ? '${dayShort(DateTime(end.year, end.month, end.day - 29))} – ${dayShort(end)}' : '${dayShort(DateTime(end.year, end.month - 5, 1))} – ${dayShort(end)} ${end.year % 100}';
    double? mean(Iterable<double?> xs) {
      final l = [for (final x in xs) if (x != null) x];
      return l.isEmpty ? null : l.reduce((a, b) => a + b) / l.length;
    }

    Widget breakdown = const SizedBox.shrink();
    switch (m.kind) {
      case _Kind.none:
        chart = Padding(padding: const EdgeInsets.symmetric(vertical: S.x6), child: Text('Нет измерений. Импортируйте данные WHOOP или дождитесь калибровки.', style: FW.hint.copyWith(color: W.ink3)));
      case _Kind.line:
        final pts = series(m.keys.first);
        final band = v.rangeOf30(m.keys.first);
        if (period == 2) {
          vals = monthly(pts);
          chart = WcBox(WcTrendPainter(mode: WcMode.sixMonth, vals: vals, labels: labels6, color: m.colors.first, fmt: m.fmt), height: 190);
        } else {
          vals = window(pts);
          chart = WcBox(WcTrendPainter(mode: period == 0 ? WcMode.week : WcMode.month, vals: vals, labels: period == 0 ? labelsW : labelsM, band: band == null ? null : (band.lo, band.hi), color: m.colors.first, fmt: m.fmt), height: 190);
        }
        avg = mean(vals.take(math.max(0, vals.length - (shift == 0 && period != 2 ? 1 : 0))));
        prevAvg = period == 2 ? mean(monthly(pts).take(3)) : mean(trailing(pts, DateTime(end.year, end.month, end.day - n), n, excludeEnd: false));
      case _Kind.bars:
        final pts = series(m.keys.first);
        if (period == 2) {
          vals = monthly(pts);
          chart = WcBox(WcTrendPainter(mode: WcMode.sixMonth, vals: vals, labels: labels6, color: W.ink, fmt: m.fmt), height: 190);
        } else {
          vals = window(pts);
          final colors = widget.metric == 'recovery' ? [for (final x in vals) W.recovery3(x)] : m.colors;
          final av = mean(vals.take(math.max(0, vals.length - (shift == 0 ? 1 : 0))));
          chart = WcBox(WcBarsPainter(mode: period == 0 ? WcMode.week : WcMode.month, vals: vals, labels: period == 0 ? labelsW : labelsM, colors: colors, fmt: m.fmt, yTicks: m.yTicks ?? _autoTicks(vals), yFmt: m.yFmt ?? m.fmt, avg: period == 1 ? av : null, todayIdx: period == 0 && shift == 0 ? 6 : null, valueColor: widget.metric == 'recovery' || widget.metric == 'strain' ? null : W.ink), height: 200);
        }
        avg = mean(vals.take(math.max(0, vals.length - (shift == 0 && period != 2 ? 1 : 0))));
        prevAvg = period == 2 ? mean(monthly(pts).take(3)) : mean(trailing(pts, DateTime(end.year, end.month, end.day - n), n, excludeEnd: false));
        if (m.bands != null) {
          final counts = List<int>.filled(m.bands!.length, 0);
          for (final x in vals) {
            if (x == null) continue;
            for (var i = 0; i < m.bands!.length; i++) {
              if (x >= m.bands![i].$1) {
                counts[i]++;
                break;
              }
            }
          }
          breakdown = WcBreakdown(title: widget.metric == 'strain' ? 'Разбивка нагрузки' : widget.metric == 'recovery' ? 'Разбивка восстановления' : 'Разбивка показателя', segs: [for (var i = 0; i < m.bands!.length; i++) (counts[i], m.bands![i].$2, m.bands![i].$3)]);
        }
      case _Kind.stacked:
        final layers = [for (final k in m.keys) series(k)];
        List<List<double>?> groups;
        List<String> labels;
        if (period == 2) {
          final ms = [for (final l in layers) monthly(l, sum: false)];
          groups = [for (var i = 0; i < 6; i++) ms.every((x) => x[i] == null) ? null : <double>[for (final x in ms) (x[i] ?? 0).toDouble()]];
          labels = labels6;
        } else {
          final ws = [for (final l in layers) window(l)];
          groups = [for (var i = 0; i < n; i++) ws.every((x) => x[i] == null) ? null : <double>[for (final x in ws) (x[i] ?? 0).toDouble()]];
          labels = period == 0 ? labelsW : labelsM;
        }
        vals = [for (final g in groups) g == null ? null : g.fold<double>(0.0, (a, b) => a + b)];
        avg = mean(vals.take(math.max(0, vals.length - (shift == 0 && period != 2 ? 1 : 0))));
        chart = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WhLegend([for (var i = 0; i < m.keys.length; i++) (m.colors[i], m.keys.length == 2 ? (i == 0 ? 'Глубокий' : 'REM') : m.label.replaceAll('Зоны пульса ', 'зоны '))]),
            WcBox(WcStackedPainter(groups: groups, colors: m.colors, labels: labels, avg: period == 1 ? avg : null, values: period != 1, todayIdx: period == 0 && shift == 0 ? 6 : null, labelEvery: period == 1 ? 7 : 1), height: 200),
          ],
        );
        prevAvg = period == 2 ? null : mean([for (final l in layers) ...trailing(l, DateTime(end.year, end.month, end.day - n), n, excludeEnd: false)]);
      case _Kind.clock:
        final spans = <(double, double)?>[];
        final byDay = <String, (double, double)>{};
        for (final w in v.d.sleepWindows) {
          final on = w['onset_ts'], wk = w['wake_ts'], date = w['date'];
          if (on is num && wk is num && date is String) {
            final a = DateTime.fromMillisecondsSinceEpoch(on.toInt() * 1000), b = DateTime.fromMillisecondsSinceEpoch(wk.toInt() * 1000);
            var bed = a.hour + a.minute / 60, wake = b.hour + b.minute / 60;
            if (bed < 13) bed += 24;
            if (wake < 13) wake += 24;
            byDay[date] = (bed, wake);
          }
        }
        if (period == 2) {
          for (final mo in months) {
            final xs = [for (final e in byDay.entries) if (e.key.startsWith('${mo.year}-${mo.month.toString().padLeft(2, '0')}')) e.value];
            spans.add(xs.isEmpty ? null : (xs.map((e) => e.$1).reduce((a, b) => a + b) / xs.length, xs.map((e) => e.$2).reduce((a, b) => a + b) / xs.length));
          }
        } else {
          for (var i = n - 1; i >= 0; i--) {
            spans.add(byDay[dayLabelOf(DateTime(end.year, end.month, end.day - i))]);
          }
        }
        vals = [for (final s in spans) s == null ? null : (s.$2 - s.$1) * 60];
        avg = mean(vals);
        chart = WcBox(WcClockPainter(spans: spans, labels: period == 0 ? labelsW : period == 1 ? labelsM : labels6, barW: period == 0 ? 14 : period == 1 ? 5 : 22, showTimes: period != 1, labelEvery: period == 1 ? 7 : 1, todayIdx: period == 0 && shift == 0 ? 6 : null), height: 210);
    }
    final delta = avg == null || prevAvg == null || prevAvg == 0 ? null : (avg - prevAvg) / prevAvg * 100;
    final unit = m.unit.isNotEmpty ? m.unit : (m.kind == _Kind.stacked || m.kind == _Kind.clock || widget.metric == 'hours' || widget.metric == 'need' ? 'ч' : '');
    final sentence = _sentence(widget.metric, m, avg, prevAvg, period, vals);
    return WhPage(
      title: 'Тренд',
      children: [
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: S.x3 + 2),
          margin: const EdgeInsets.only(bottom: S.x3 + 2),
          decoration: BoxDecoration(color: W.card2, borderRadius: WR.rChip),
          child: Row(children: [WhIcon(m.icon, size: 18), const SizedBox(width: S.x2 + 2), Expanded(child: Text(m.label.toUpperCase(), style: FW.h5.copyWith(color: W.ink))), const WhIcon('caret_down', size: 14, color: W.ink)]),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.kind == _Kind.stacked && widget.metric.startsWith('zones') ? 'СРЕДНЕЕ ЗА ДЕНЬ' : 'СРЕДНЕЕ', style: FW.over.copyWith(color: W.ink2)),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(avg == null ? '—' : m.fmt(avg), style: FW.n36.copyWith(color: W.ink)), const SizedBox(width: S.x1 + 2), Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(unit, style: FW.sub.copyWith(color: W.ink3)))]),
                  if (delta != null) Padding(padding: const EdgeInsets.only(top: S.x2), child: WhChangeChip(m.lowerBetter ? -delta : delta, period == 0 ? 'к прошлой неделе' : period == 1 ? 'к прошлому месяцу' : 'к прошлым 6 месяцам')),
                ],
              ),
            ),
            WhSegmented(labels: const ['Нед', 'Мес', '6 мес'], selected: period, width: 150, onSelect: (i) => setState(() {
              period = i;
              shift = 0;
            })),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: S.x2 + 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Pressable(onTap: () => setState(() => shift++), semanticLabel: 'Раньше', child: const SizedBox(width: 36, height: 36, child: Center(child: WhIcon('navigation_backward', size: 12, color: W.ink)))),
              Text(rangeTxt.toUpperCase(), style: FW.label.copyWith(color: W.ink)),
              Pressable(onTap: shift == 0 ? null : () => setState(() => shift--), semanticLabel: 'Позже', child: SizedBox(width: 36, height: 36, child: Center(child: WhIcon('navigation_forward', size: 12, color: shift == 0 ? W.ink3 : W.ink)))),
            ],
          ),
        ),
        Text(sentence, style: FW.body15.copyWith(color: W.ink)),
        if (m.kind == _Kind.line && period != 2) Padding(padding: const EdgeInsets.only(top: S.x2), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: W.band, borderRadius: WR.rTiny)), const SizedBox(width: S.x1 + 2), Text('ТИПИЧНЫЙ ДИАПАЗОН', style: FW.over.copyWith(color: W.ink2))])),
        const SizedBox(height: S.x2),
        chart,
        if (period != 2 && shift == 0 && m.kind != _Kind.clock && m.kind != _Kind.none) WhHint('Среднее не включает сегодня (${dayShort(v.date)})', info: true),
        if (widget.metric.startsWith('zones')) const WhHint('Минуты в зонах считаются по всему дню по резерву пульса', info: true),
        breakdown,
        const SizedBox(height: S.x3),
        WhMenu([
          WhMenuItem('Что такое ${m.label.toLowerCase()}?', icon: 'education', onTap: () => _info(c, m.label, m.what)),
          if (m.improve.isNotEmpty) WhMenuItem('Как улучшить', icon: 'advice', onTap: () => _info(c, 'Как улучшить', m.improve)),
        ]),
      ],
    );
  }

  void _info(BuildContext c, String title, String text) => showModalBottomSheet<void>(
    context: c,
    backgroundColor: W.card,
    sheetAnimationStyle: sheetMotion(c),
    builder: (_) => Padding(padding: const EdgeInsets.fromLTRB(S.x5, S.x5, S.x5, S.x8), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: FW.t3.copyWith(color: W.ink)), const SizedBox(height: S.x3), Text(text, style: FW.body15.copyWith(color: W.ink2))])),
  );
}

List<double> _autoTicks(List<double?> vals) {
  final mx = vals.whereType<double>().fold(0.0, math.max) * 1.15;
  if (mx <= 0) return const [0, 25, 50, 75, 100];
  final step = _niceStepFor(mx / 4);
  return [for (var i = 0; i <= 4; i++) step * i];
}

double _niceStepFor(double raw) {
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final k in [1, 2, 2.5, 5, 10]) {
    if (mag * k >= raw) return mag * k;
  }
  return mag * 10;
}

String _sentence(String key, _Meta m, double? avg, double? prev, int period, List<double?> vals) {
  final per = period == 0 ? '7 дней' : period == 1 ? 'месяц' : 'полгода';
  if (avg == null) return 'Пока нет данных за $per. Носите браслет ночью и синхронизируйте записи.';
  final cmp = prev == null ? '' : avg > prev * 1.01 ? ' — выше, чем за предыдущий период (${m.fmt(prev)})' : avg < prev * .99 ? ' — ниже, чем за предыдущий период (${m.fmt(prev)})' : ' — как за предыдущий период';
  return switch (key) {
    'strain' => 'Средняя нагрузка за $per ${m.fmt(avg)}$cmp. ${avg >= 14 ? 'Неделя высокой нагрузки: следите за восстановлением.' : avg >= 10 ? 'Умеренный диапазон.' : 'Лёгкий диапазон.'}',
    'recovery' => 'Среднее восстановление ${m.fmt(avg)}$cmp. ${avg >= 67 ? 'Зелёная зона: организм справляется с нагрузкой.' : avg >= 34 ? 'Жёлтая зона: держите баланс нагрузки и сна.' : 'Красная зона: нужен отдых.'}',
    'steps' => 'В среднем ${m.fmt(avg)} шагов за день$cmp.',
    'hrv' => 'Средняя ВСР ${m.fmt(avg)} мс$cmp.',
    'resting_hr' => 'Средний пульс в покое ${m.fmt(avg)} уд/мин$cmp.',
    'tib' => 'В среднем ${hmOf(avg)} в постели за ночь. Ровные столбики — регулярный график.',
    _ => 'Среднее за $per: ${m.fmt(avg)}${m.unit.isNotEmpty ? ' ${m.unit}' : ''}$cmp.',
  };
}
