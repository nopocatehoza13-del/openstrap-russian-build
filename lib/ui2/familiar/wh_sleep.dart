// Sleep detail and the sleep planner, WHOOP layout over FamiliarData.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:personal_analytics/whoop_observations.dart';

import '../../data/day_label.dart';
import '../../state/prefs.dart';
import '../grammar.dart';
import '../theme.dart';
import 'data.dart';
import 'wh_data.dart';
import 'wh_nav.dart';
import 'wh_widgets.dart';
import 'whoop_charts.dart';

int stageIndex(Object? s) => switch (s?.toString()) { 'wake' || 'awake' => 0, 'rem' => 2, 'deep' || 'sws' => 3, _ => 1 };
const stageNames = ['Бодрствование', 'Лёгкий', 'REM', 'Глубокий'];

class WhSleep extends StatefulWidget {
  final WhView view;
  const WhSleep({super.key, required this.view});
  @override
  State<WhSleep> createState() => _WhSleepState();
}

class _WhSleepState extends State<WhSleep> {
  double? cursor;

  @override
  Widget build(BuildContext c) {
    final v = widget.view, d = v.d;
    final nav = WhNav(c, v);
    final obs = v.observations().where((o) => o.kind == ObservationKind.sleep).toList();
    final perf = v.sleepPerf;
    final tst = v.tstMin;
    final hr = [for (final e in d.nightHr) (e['v'] as num?)?.toDouble()];
    final hrTs = [for (final e in d.nightHr) (e['t'] as num?)?.toInt() ?? 0];
    final hypno = [for (final e in d.sleep['hypnogram'] as List? ?? const []) if (e is Map) e.cast<String, dynamic>()];
    List<int>? stages;
    if (hypno.isNotEmpty && hrTs.isNotEmpty) {
      stages = [
        for (final t in hrTs)
          () {
            var st = 1;
            for (final p in hypno) {
              final pt = p['t'];
              final ts = pt is num ? (pt > 1e11 ? pt ~/ 1000 : pt.toInt()) : null;
              if (ts != null && ts <= t) st = stageIndex(p['stage']);
            }
            return st;
          }(),
      ];
    }
    final ci = cursor == null || hr.isEmpty ? null : (cursor! * (hr.length - 1)).round();
    WhRange? rangeOf30(String key) => v.rangeOfKey(key);
    (int, int)? pctRange(WhRange? r) => r == null || tst == null || tst <= 0 ? null : ((r.lo / tst * 100).round().clamp(0, 100), (r.hi / tst * 100).round().clamp(0, 100));
    int? pct(double? m) => m == null || tst == null || tst <= 0 ? null : (m / tst * 100).round();
    final bedSpans = _weekSpans(d.sleepWindows, v.date);
    final optimal = _optimalBedWake(d.sleepWindows);
    return WhPage(
      title: v.isToday ? 'Сегодня' : dowShort(v.date),
      listKey: const ValueKey('wh-sleep'),
      children: [
        WcDial(color: W.sleep, fraction: perf == null ? null : perf / 100, big: perf == null ? '—' : '${perf.round()}', suffix: perf == null ? null : '%', caption: 'Показатель сна', seg: v.sleepPerfLevel),
        WhCard(
          tip: true,
          padding: const EdgeInsets.fromLTRB(S.x4, S.x2, S.x4, S.x3),
          child: Column(
            children: [
              _perfRow('hours_of_sleep', 'Сон / потребность', v.hoursVsNeed, v.levelOf('hours') >= 0 ? v.levelOf('hours') : (v.hoursVsNeed == null ? -1 : v.hoursVsNeed! >= 85 ? 2 : v.hoursVsNeed! >= 70 ? 1 : 0)),
              _perfRow('consistency', 'Регулярность сна', v.consistency, v.levelOf('consistency')),
              _perfRow('efficiency', 'Эффективность сна', v.efficiencyPct, v.levelOf('efficiency') >= 0 ? v.levelOf('efficiency') : (v.efficiencyPct == null ? -1 : v.efficiencyPct! >= 90 ? 2 : v.efficiencyPct! >= 80 ? 1 : 0)),
              _perfRow('sleep_stress', 'Высокий стресс во сне', v.sleepStressPct, v.levelOf('stress')),
              WhLegendNote(children: [for (final (col, t) in [(W.neg, 'Слабо'), (W.sufficient, 'Достаточно'), (W.action, 'Оптимально')]) Padding(padding: const EdgeInsets.only(right: S.x3 + 2), child: Row(children: [Container(width: 14, height: 3, decoration: BoxDecoration(color: col, borderRadius: WR.rTiny)), const SizedBox(width: 5), Text(t, style: FW.hint.copyWith(color: W.ink2))]))]),
            ],
          ),
        ),
        if (obs.isNotEmpty) WhObservationCard(text: '${obs.first.title}. ${obs.first.text}', link: obs.first.link, onLink: () => nav.go(obs.first.target)),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, S.x3, 0, S.x3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Последний сон', style: FW.t3.copyWith(color: W.ink)), Text.rich(TextSpan(children: [TextSpan(text: v.isToday ? 'Сегодня' : dowShort(v.date), style: FW.hint.copyWith(color: W.ink, fontWeight: FontWeight.w600)), TextSpan(text: ' vs. последние 30 дней', style: FW.hint.copyWith(color: W.ink3))]))])),
              Pressable(onTap: () => nav.go('sleep-edit'), child: Row(children: [Text('ИЗМЕНИТЬ', style: FW.over.copyWith(color: W.ink)), const SizedBox(width: S.x1 + 2), const WhIcon('pencil', size: 12, color: W.ink)])),
            ],
          ),
        ),
        WhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Expanded(child: Text('ЧАСЫ СНА', style: FW.label.copyWith(color: W.ink))), const WhInfoDot(size: 20)]),
              const SizedBox(height: S.x1),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Text(hmOf(tst), style: FW.n28.copyWith(color: W.ink)), const SizedBox(width: S.x2), if (v.sleepRange != null) WhTri(dirOf(tst, v.sleepRange!.median))]),
              if (v.sleepRange != null) Text(hmOf(v.sleepRange!.median), style: FW.hint.copyWith(color: W.ink3)),
              const SizedBox(height: S.x2),
              if (hr.length >= 2)
                Scrubber(
                  value: cursor,
                  label: 'Пульс за ночь',
                  step: 1 / math.max(1, hr.length - 1),
                  describe: (x) {
                    final i = (x * (hr.length - 1)).round().clamp(0, hr.length - 1);
                    return '${clockOf(hrTs[i])}: ${hr[i]?.round() ?? '—'} уд/мин${stages == null ? '' : ', ${stageNames[stages[i]]}'}';
                  },
                  onChanged: (x) => setState(() => cursor = x),
                  child: Stack(
                    children: [
                      WcBox(WcHrAreaPainter(vals: hr, color: W.sleepLine, yTicks: const [30, 50, 70, 90, 110], startLabel: clockOf(v.onsetTs ?? hrTs.first), endLabel: clockOf(v.wakeTs ?? hrTs.last), strokeWidth: 1.2, area: false, stages: stages, cursor: ci), height: 168),
                      if (ci != null)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: S.x2, vertical: S.x1),
                              decoration: BoxDecoration(color: W.ink, borderRadius: const BorderRadius.all(Radius.circular(8))),
                              child: Text.rich(TextSpan(children: [TextSpan(text: '${hr[ci]?.round() ?? '—'} уд/мин', style: FW.n11.copyWith(color: W.onLight)), TextSpan(text: '  ${stages == null ? '' : '${stageNames[stages[ci]].toUpperCase()} · '}${clockOf(hrTs[ci])}', style: FW.tiny.copyWith(color: W.card3, fontWeight: FontWeight.w600, letterSpacing: .6))])),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Padding(padding: const EdgeInsets.symmetric(vertical: S.x3), child: Text(d.sleep['has_sleep'] == false ? 'Ночной сон не записан: браслет был снят или не синхронизирован.' : 'Кривая пульса за ночь появится после синхронизации записей этой ночи.', style: FW.hint.copyWith(color: W.ink3))),
              WhHint(hr.length >= 2 ? 'Ведите пальцем по линии: пульс и стадия сна в этот момент. Стадии рассчитаны по пульсу, ВСР и движению.' : ''),
              Container(
                margin: const EdgeInsets.only(top: S.x2),
                padding: const EdgeInsets.only(top: S.x2 + 2),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: W.line2))),
                child: Row(
                  children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(border: Border.all(color: W.ink4, width: 1.5), borderRadius: WR.rTiny, color: W.ink.withValues(alpha: .08))),
                    const SizedBox(width: S.x2),
                    Text('ТИПИЧНЫЙ ДИАПАЗОН', style: FW.over.copyWith(color: W.ink2)),
                    const Spacer(),
                    Text('ДЛИТЕЛЬНОСТЬ', style: FW.over.copyWith(color: W.ink2)),
                    const SizedBox(width: S.x2),
                    Text(hmOf(v.inBedMin), style: FW.n17.copyWith(color: W.ink)),
                  ],
                ),
              ),
              WcHatchRow(label: 'Бодрствование', pct: pct(v.awakeMin), color: W.awake, range: pctRange(null), value: Text(hmOf(v.awakeMin), style: FW.n17.copyWith(color: W.ink)), circle: true),
              WcHatchRow(label: 'Лёгкий', pct: pct(v.lightMin), color: W.light, range: pctRange(rangeOf30('light')), value: Text(hmOf(v.lightMin), style: FW.n17.copyWith(color: W.ink)), circle: true),
              WcHatchRow(label: 'Глубокий (SWS)', pct: pct(v.deepMin), color: W.deep, range: pctRange(rangeOf30('deep')), value: Text(hmOf(v.deepMin), style: FW.n17.copyWith(color: W.ink)), circle: true),
              WcHatchRow(label: 'Быстрый (REM)', pct: pct(v.remMin), color: W.rem, range: pctRange(rangeOf30('rem')), value: Text(hmOf(v.remMin), style: FW.n17.copyWith(color: W.ink)), circle: true, filled: true),
              Container(
                padding: const EdgeInsets.only(top: S.x3),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: W.line2))),
                child: Row(
                  children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: W.deep, borderRadius: WR.rTiny)),
                    const SizedBox(width: S.x2),
                    Expanded(child: Text('ВОССТАНАВЛИВАЮЩИЙ СОН', style: FW.label.copyWith(color: W.ink))),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(children: [Text(hmOf(v.restorativeMin), style: FW.n17.copyWith(color: W.ink)), const SizedBox(width: S.x1), if (rangeOf30('deep') != null && rangeOf30('rem') != null) WhTri(dirOf(v.restorativeMin, rangeOf30('deep')!.median + rangeOf30('rem')!.median))]),
                        if (rangeOf30('deep') != null && rangeOf30('rem') != null) Text(hmOf(rangeOf30('deep')!.median + rangeOf30('rem')!.median), style: FW.tiny.copyWith(color: W.ink3)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (tst != null && v.needMin != null)
          WhCard(
            child: WcHoursVsNeeded(
              sleptMin: tst,
              needMin: v.needMin!,
              healthyMin: v.lastNight['date'] == d.day && v.lastNeed['baseline_sec'] is num ? (v.lastNeed['baseline_sec'] as num) / 60 : v.needMin!,
              strainAddMin: v.lastNight['date'] == d.day && v.lastNeed['strain_add_sec'] is num ? (v.lastNeed['strain_add_sec'] as num) / 60 : 0,
              debtMin: v.lastNight['date'] == d.day && v.lastNeed['debt_sec'] is num ? (v.lastNeed['debt_sec'] as num) / 60 : 0,
              pct: v.hoursVsNeed?.round() ?? 0,
              prevPct: v.rangeOfKey('whoop_hours_vs_need')?.median.round(),
            ),
          ),
        WhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Expanded(child: Text('РЕГУЛЯРНОСТЬ СНА', style: FW.label.copyWith(color: W.ink))), const WhInfoDot(size: 20)]),
              const SizedBox(height: S.x1),
              Row(children: [Text(v.consistency == null ? '—' : '${v.consistency!.round()}%', style: FW.n28.copyWith(color: W.ink)), const SizedBox(width: S.x2), if (v.rangeOfKey('whoop_consistency') != null) WhTri(dirOf(v.consistency, v.rangeOfKey('whoop_consistency')!.median))]),
              Row(
                children: [
                  Text(v.rangeOfKey('whoop_consistency') == null ? (v.consistency == null ? 'нужно 5 ночей подряд' : '') : '${v.rangeOfKey('whoop_consistency')!.median.round()}%', style: FW.hint.copyWith(color: W.ink3)),
                  const Spacer(),
                  Container(width: 14, height: 0, decoration: const BoxDecoration(border: Border(top: BorderSide(color: W.ink4, width: 1.5)))),
                  const SizedBox(width: S.x1 + 2),
                  Text('ОПТИМАЛЬНЫЕ ОТБОЙ/ПОДЪЁМ', style: FW.over.copyWith(color: W.ink2)),
                ],
              ),
              const SizedBox(height: S.x2),
              if (bedSpans.any((s) => s != null))
                WcBox(WcClockPainter(spans: bedSpans, labels: _weekLabels(v.date), optimal: optimal, todayIdx: 6), height: 200)
              else
                Padding(padding: const EdgeInsets.symmetric(vertical: S.x3), child: Text('График появится после нескольких записанных ночей.', style: FW.hint.copyWith(color: W.ink3))),
            ],
          ),
        ),
        WhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Expanded(child: Text('ЭФФЕКТИВНОСТЬ СНА', style: FW.label.copyWith(color: W.ink))), const WhInfoDot(size: 20)]),
              const SizedBox(height: S.x1),
              Row(children: [Text(v.efficiencyPct == null ? '—' : '${v.efficiencyPct!.round()}%', style: FW.n28.copyWith(color: W.ink)), const SizedBox(width: S.x2), if (v.rangeOfKey('efficiency') != null) WhTri(dirOf(v.efficiencyPct, v.rangeOfKey('efficiency')!.median))]),
              if (v.rangeOfKey('efficiency') != null) Text('${v.rangeOfKey('efficiency')!.median.round()}%', style: FW.hint.copyWith(color: W.ink3)),
              const SizedBox(height: S.x2 + 2),
              Row(children: [Expanded(child: Text('СОН', style: FW.label.copyWith(color: W.ink2))), Text(hmOf(tst), style: FW.n15.copyWith(color: W.ink))]),
              const SizedBox(height: S.x1 + 2),
              ClipRRect(borderRadius: WR.rBar, child: Container(height: 14, color: W.sleep)),
              const SizedBox(height: S.x2 + 2),
              SizedBox(height: 14, child: CustomPaint(painter: _AwakePainter(share: tst == null || v.inBedMin == null || v.inBedMin! <= 0 ? 0 : ((v.awakeMin ?? 0) / v.inBedMin!).clamp(0, 1).toDouble()))),
              const SizedBox(height: S.x1 + 2),
              Row(children: [Expanded(child: Text('БОДРСТВОВАНИЕ', style: FW.label.copyWith(color: W.ink2))), Text(hmOf(v.awakeMin), style: FW.n15.copyWith(color: W.ink))]),
              Container(
                margin: const EdgeInsets.only(top: S.x3),
                padding: const EdgeInsets.only(top: S.x3),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: W.line2))),
                child: Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: W.ink4, borderRadius: WR.rTiny)), const SizedBox(width: S.x2), Expanded(child: Text('ПРОБУЖДЕНИЯ', style: FW.label.copyWith(color: W.ink2))), Text(v.wakeEvents == null ? '—' : '${v.wakeEvents}', style: FW.n17.copyWith(color: W.ink))]),
              ),
            ],
          ),
        ),
        _sleepStressCard(v),
        const WhSection('Недельные тренды'),
        _weekCard('Часы против потребности', 'trend-hours', nav, WcBarsPainter(mode: WcMode.week, vals: trailing(d.health.points('sleep'), v.date, 7, excludeEnd: false).asMap().entries.map((e) => e.key == 6 ? tst : e.value).toList(), labels: _weekLabels(v.date), colors: const [W.sleep], fmt: hmOf, yTicks: const [0, 150, 300, 450, 600], yFmt: hmOf, todayIdx: 6, valueColor: W.ink)),
        _weekCard('Восстанавливающий сон', 'trend-restorative', nav, WcStackedPainter(groups: _pairs(trailing(d.series['deep'] ?? const [], v.date, 7, excludeEnd: false), trailing(d.series['rem'] ?? const [], v.date, 7, excludeEnd: false), v.deepMin, v.remMin), colors: const [W.deep, W.rem], labels: _weekLabels(v.date), values: true, todayIdx: 6), legend: const WhLegend([(W.deep, 'Глубокий'), (W.rem, 'REM')])),
        _weekCard('Время в постели', 'trend-tib', nav, WcClockPainter(spans: bedSpans, labels: _weekLabels(v.date), todayIdx: 6), height: 200),
        WhBigButton('Планировщик сна', icon: 'sleep_coach', onTap: () => nav.go('tonight')),
        const WhNote('Как считается: потребность = личная норма + надбавка за нагрузку 1,7/(1+e^((17−i)/3,5)) ч + недосып − дрёмы (заявка WHOOP US 2024/0252121). Показатель сна: часы против потребности (85/70), регулярность (80/70), эффективность (90/80), высокий стресс во сне (<1 % / 1–5 % / >5 %) — пороги из справки WHOOP; веса компонентов подобраны.'),
      ],
    );
  }

  Widget _perfRow(String icon, String label, double? pct, int level) => WhRow(icon: icon, label: label, value: pct == null ? '—' : '${pct.round()}%', middle: WhSeg3(level, width: 18));

  Widget _weekCard(String title, String target, WhNav nav, CustomPainter painter, {double height = 180, Widget? legend}) => WhCard(
    onTap: () => nav.go(target),
    padding: const EdgeInsets.fromLTRB(S.x3, S.x3 + 2, S.x3, S.x2 + 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: S.x1), child: WhCardHead(title, chevron: true)),
        ?legend,
        WcBox(painter, height: height),
      ],
    ),
  );

  Widget _sleepStressCard(WhView v) {
    final pts = v.stressPoints.where((p) => p['sleep'] is num).toList();
    final high = v.stressMin('sleep', 'high'), med = v.stressMin('sleep', 'medium'), low = v.stressMin('sleep', 'low');
    final total = (high ?? 0) + (med ?? 0) + (low ?? 0);
    int? share(double? m) => m == null || total <= 0 ? null : (m / total * 100).round();
    return WhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text('СТРЕСС ВО СНЕ', style: FW.label.copyWith(color: W.ink))), const WhInfoDot(size: 20)]),
          const SizedBox(height: S.x1),
          Text(v.sleepStressPct == null ? (share(high) == null ? '—' : '${share(high)}%') : '${v.sleepStressPct!.round()}%', style: FW.n28.copyWith(color: W.ink)),
          Text('доля ночи с высоким стрессом', style: FW.hint.copyWith(color: W.ink3)),
          const SizedBox(height: S.x2),
          if (pts.length >= 2)
            WcBox(
              WcStressPainter(
                vals: [for (final p in pts) (p['sleep'] as num).toDouble()],
                startHour: DateTime.fromMillisecondsSinceEpoch(((pts.first['t'] as num).toInt()) * 1000).hour + DateTime.fromMillisecondsSinceEpoch(((pts.first['t'] as num).toInt()) * 1000).minute / 60,
                stepMin: 5,
                sleep: (0, pts.length - 1),
                showZoom: false,
                endLabel: clockOf((pts.last['end'] as num?)?.toInt() ?? (pts.last['t'] as num).toInt()),
              ),
              height: 170,
            )
          else
            Padding(padding: const EdgeInsets.symmetric(vertical: S.x2), child: Text('Стресс во сне появится, когда за ночь есть записи пульса и движения.', style: FW.hint.copyWith(color: W.ink3))),
          for (final (label, m, col) in [('Высокий', high, W.stressHigh), ('Умеренный', med, W.stressMed), ('Низкий', low, W.stressLow)])
            WcHatchRow(label: label, pct: share(m), color: col, value: Text(hmOf(m), style: FW.n17.copyWith(color: W.ink))),
        ],
      ),
    );
  }
}

class _AwakePainter extends CustomPainter {
  final double share;
  _AwakePainter({required this.share});
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(4)));
    c.drawRect(Offset.zero & s, Paint()..color = W.card2);
    final hp = Paint()
      ..color = W.card
      ..strokeWidth = 3;
    for (var x = -20.0; x < s.width + 20; x += 8) {
      c.drawLine(Offset(x, s.height + 4), Offset(x + 16, -4), hp);
    }
    c.restore();
    if (share > 0) {
      final n = math.max(1, (share * 12).round());
      for (var i = 0; i < n; i++) {
        final x = s.width * (i + .5) / n;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.5, 0, 3, s.height), const Radius.circular(1)), Paint()..color = W.awake);
      }
    }
  }

  @override
  bool shouldRepaint(_AwakePainter o) => o.share != share;
}

List<String> _weekLabels(DateTime end) => [for (var i = 6; i >= 0; i--) dowShort(DateTime(end.year, end.month, end.day - i))];

List<List<double>?> _pairs(List<double?> a, List<double?> b, double? todayA, double? todayB) => [
  for (var i = 0; i < a.length; i++)
    () {
      final x = i == a.length - 1 && todayA != null ? todayA : a[i];
      final y = i == b.length - 1 && todayB != null ? todayB : b[i];
      return x == null && y == null ? null : [x ?? 0, y ?? 0];
    }(),
];

/// Bed/wake spans (hours on the 21:00→13:00 axis) for the seven nights ending
/// on [end], from the repository's sleep windows.
List<(double, double)?> _weekSpans(List<Map<String, dynamic>> windows, DateTime end) {
  final byDay = <String, (double, double)>{};
  for (final w in windows) {
    final on = w['onset_ts'], wk = w['wake_ts'], date = w['date'];
    if (on is num && wk is num && date is String) {
      final a = DateTime.fromMillisecondsSinceEpoch(on.toInt() * 1000), b = DateTime.fromMillisecondsSinceEpoch(wk.toInt() * 1000);
      var bed = a.hour + a.minute / 60;
      var wake = b.hour + b.minute / 60;
      if (bed < 13) bed += 24;
      if (wake < 13) wake += 24;
      byDay[date] = (bed, wake);
    }
  }
  return [for (var i = 6; i >= 0; i--) byDay[dayLabelOf(DateTime(end.year, end.month, end.day - i))]];
}

List<double>? _optimalBedWake(List<Map<String, dynamic>> windows) {
  final beds = <double>[], wakes = <double>[];
  for (final w in windows) {
    final on = w['onset_ts'], wk = w['wake_ts'];
    if (on is num && wk is num) {
      final a = DateTime.fromMillisecondsSinceEpoch(on.toInt() * 1000), b = DateTime.fromMillisecondsSinceEpoch(wk.toInt() * 1000);
      var bed = a.hour + a.minute / 60;
      var wake = b.hour + b.minute / 60;
      if (bed < 13) bed += 24;
      if (wake < 13) wake += 24;
      beds.add(bed);
      wakes.add(wake);
    }
  }
  if (beds.length < 5) return null;
  beds.sort();
  wakes.sort();
  return [beds[beds.length ~/ 2], wakes[wakes.length ~/ 2]];
}

/// Tonight's plan: need from the WHOOP-formula rollup, goal 70/85/100 %, wake
/// time → recommended bedtime. Stored on the phone; the strap alarm is separate.
class FamiliarSleepPlanner extends StatefulWidget {
  final FamiliarData data;
  const FamiliarSleepPlanner({super.key, required this.data});
  @override
  State<FamiliarSleepPlanner> createState() => _FamiliarSleepPlannerState();
}

class _FamiliarSleepPlannerState extends State<FamiliarSleepPlanner> {
  late int wake = Prefs.getInt('familiar.wakeMinute', -1);
  late int goal = Prefs.getInt('familiar.sleepGoal', 100);
  @override
  Widget build(BuildContext c) {
    final v = WhView(widget.data, DateTime.now());
    final nav = WhNav(c, v);
    final need = v.needTonightMin ?? widget.data.home.sleepNeedMin.value?.toDouble();
    final planned = need == null ? null : need * goal / 100;
    final bed = planned == null || wake < 0 ? null : ((wake - planned) % 1440 + 1440) % 1440;
    String clk(num? m) => m == null ? '—' : '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).round().toString().padLeft(2, '0')}';
    final parts = [
      if (v.baselineMin != null) 'норма ${hmOf(v.baselineMin)}',
      if ((v.debtTonightMin ?? 0) >= 1) 'недосып ${hmOf(v.debtTonightMin)}',
      if ((v.strainAddTonightMin ?? 0) >= 1) 'нагрузка ${hmOf(v.strainAddTonightMin)}',
    ];
    return WhPage(
      title: 'Планировщик сна',
      children: [
        WhCard(
          color: W.card2,
          child: Column(
            children: [
              Text('ПОТРЕБНОСТЬ ВО СНЕ', style: FW.label.copyWith(color: W.ink2)),
              const SizedBox(height: S.x2),
              Text(hmOf(need), style: FW.n44.copyWith(color: W.ink)),
              const SizedBox(height: S.x1),
              Text(need == null ? 'Появится после первой записанной ночи.' : parts.isEmpty ? 'по формуле WHOOP' : parts.join(' + '), style: FW.hint.copyWith(color: W.ink3), textAlign: TextAlign.center),
              if (v.baselineSource == 'population') Padding(padding: const EdgeInsets.only(top: S.x1), child: Text('Норма пока стартовая по возрасту; личная — после 5 ночей.', style: FW.tiny.copyWith(color: W.ink3), textAlign: TextAlign.center)),
            ],
          ),
        ),
        WhSegmented(labels: const ['Выспаться на 70 %', '85 %', 'На пике 100 %'], selected: [70, 85, 100].indexOf(goal).clamp(0, 2), onSelect: (i) {
          setState(() => goal = [70, 85, 100][i]);
          Prefs.setInt('familiar.sleepGoal', goal);
        }),
        const SizedBox(height: S.x3),
        WhCard(
          child: Column(
            children: [
              Pressable(
                onTap: () async {
                  final t = await showTimePicker(context: c, initialTime: TimeOfDay(hour: wake < 0 ? 7 : wake ~/ 60, minute: wake < 0 ? 0 : wake % 60));
                  if (t != null && mounted) {
                    setState(() => wake = t.hour * 60 + t.minute);
                    Prefs.setInt('familiar.wakeMinute', wake);
                  }
                },
                child: WhKv('Подъём', clk(wake < 0 ? null : wake)),
              ),
              WhKv('Рекомендуемый отбой', clk(bed)),
              WhKv('В постели', hmOf(planned == null ? null : v.efficiencyPct == null || v.efficiencyPct! <= 0 ? planned : planned / (v.efficiencyPct! / 100)), last: true),
            ],
          ),
        ),
        WhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WhCardHead('Будильник браслета'),
              Text('Вибрация браслета по времени. План сна сам будильник не включает: его нужно отправить на браслет отдельно.', style: FW.body.copyWith(color: W.ink2)),
              const SizedBox(height: S.x3),
              WhPill('Настроить будильник', icon: 'strap', onTap: () => nav.go('alarm')),
            ],
          ),
        ),
        WhBigButton('Напоминания о сне', icon: 'notifications', onTap: () => nav.go('notifications')),
      ],
    );
  }
}
