// Recovery and Strain details — WHOOP layout over FamiliarData.
import 'package:flutter/material.dart';
import 'package:personal_analytics/whoop_observations.dart';

import '../grammar.dart';
import '../screens/log_workout.dart';
import '../screens/workout_screen.dart' show openFamiliarActivityPicker, familiarActivityName;
import '../theme.dart';
import 'wh_data.dart';
import 'wh_home.dart' show activityIconOf;
import 'wh_nav.dart';
import 'wh_widgets.dart';
import 'whoop_charts.dart';

List<String> weekLabels(DateTime end) => [for (var i = 6; i >= 0; i--) dowShort(DateTime(end.year, end.month, end.day - i))];

class WhRecovery extends StatelessWidget {
  final WhView view;
  const WhRecovery({super.key, required this.view});
  @override
  Widget build(BuildContext c) {
    final v = view, d = v.d;
    final nav = WhNav(c, v);
    final obs = v.observations().where((o) => o.kind == ObservationKind.recovery || o.kind == ObservationKind.health).toList();
    final rec = v.recovery;
    final rec7 = trailing(d.series['whoop_recovery']?.isNotEmpty == true ? d.series['whoop_recovery']! : d.recovery, v.date, 7, excludeEnd: false);
    if (rec != null) rec7[6] = rec;
    final hrv7 = trailing(d.health.points('hrv'), v.date, 7, excludeEnd: false);
    if (v.hrv != null) hrv7[6] = v.hrv;
    final rhr7 = trailing(d.health.points('resting_hr'), v.date, 7, excludeEnd: false);
    if (v.rhr != null) rhr7[6] = v.rhr;
    String f0(double? x) => x == null ? '—' : '${x.round()}';
    return WhPage(
      title: v.isToday ? 'Сегодня' : dowShort(v.date),
      children: [
        WcDial(color: W.recovery3(rec), fraction: rec == null ? null : rec / 100, big: rec == null ? '—' : '${rec.round()}', suffix: rec == null ? null : '%', caption: 'Восстановление'),
        WhCard(
          tip: true,
          padding: const EdgeInsets.fromLTRB(S.x4, S.x2, S.x4, S.x3),
          child: Column(
            children: [
              WhRow(icon: 'hrv', label: 'Вариабельность ритма', value: f0(v.hrv), prev: v.hrvRange == null ? null : f0(v.hrvRange!.median), dir: dirOf(v.hrv, v.hrvRange?.median), onTap: () => nav.go('trend-hrv')),
              WhRow(icon: 'rhr', label: 'Пульс в покое', value: f0(v.rhr), prev: v.rhrRange == null ? null : f0(v.rhrRange!.median), dir: dirOf(v.rhr, v.rhrRange?.median, lowerBetter: true), onTap: () => nav.go('trend-resting_hr')),
              WhRow(icon: 'respiratory_rate', label: 'Частота дыхания', value: ruDecimal(v.resp), prev: v.respRange == null ? null : ruDecimal(v.respRange!.median), dir: dirOf(v.resp, v.respRange?.median, eps: .3), goodIsUp: false, onTap: () => nav.go('trend-respiratory_rate')),
              WhRow(icon: 'sleep_performance', label: 'Показатель сна', value: v.sleepPerf == null ? '—' : '${v.sleepPerf!.round()}%', prev: v.rangeOfKey('whoop_sleep_perf') == null ? null : '${v.rangeOfKey('whoop_sleep_perf')!.median.round()}%', dir: dirOf(v.sleepPerf, v.rangeOfKey('whoop_sleep_perf')?.median), onTap: () => nav.go('sleep')),
              WhLegendNote(children: [const WhTri('up'), const WhTri('dn'), const SizedBox(width: S.x1), Text.rich(TextSpan(children: [TextSpan(text: v.isToday ? 'Сегодня' : dowShort(v.date), style: FW.hint.copyWith(color: W.ink, fontWeight: FontWeight.w600)), TextSpan(text: ' vs. последние 30 дней', style: FW.hint.copyWith(color: W.ink2))]))]),
            ],
          ),
        ),
        if (obs.isNotEmpty) WhObservationCard(text: '${obs.first.title}. ${obs.first.text}', link: obs.first.link, onLink: () => nav.go(obs.first.target)),
        const WhSection('Активности за день'),
        WhCard(
          child: Column(
            children: [
              if (d.sleep['duration_min'] is num) _ActRow(icon: 'sleep', tag: hmOf(d.sleep['duration_min'] as num), name: 'Сон', start: clockOf((d.sleep['onset_ts'] as num?)?.toInt()), end: clockOf((d.sleep['wake_ts'] as num?)?.toInt()), color: W.sleep, onTap: () => nav.go('sleep')),
              for (final row in d.activities) _ActRow(icon: activityIconOf(row['type']?.toString()), tag: ruDecimal((row['whoop_strain'] as num?) ?? (row['strain'] as num?)), name: familiarActivityName(c, row['type']?.toString()), start: clockOf((row['start_ts'] as num?)?.toInt()), end: clockOf((row['end_ts'] as num?)?.toInt()), color: W.strain, onTap: () => nav.workout(row)),
              if (d.activities.isEmpty && d.sleep['duration_min'] is! num) Padding(padding: const EdgeInsets.symmetric(vertical: S.x2), child: Text('Записей за день пока нет.', style: FW.hint.copyWith(color: W.ink3))),
            ],
          ),
        ),
        const WhSection('Недельные тренды'),
        weekCard('Восстановление', 'trend-recovery', nav, WcBarsPainter(mode: WcMode.week, vals: rec7, labels: weekLabels(v.date), colors: [for (final r in rec7) W.recovery3(r)], fmt: (x) => '${x.round()}%', yTicks: const [0, 25, 50, 75, 100], yFmt: (x) => '${x.round()}%', todayIdx: 6)),
        weekCard('Вариабельность ритма', 'trend-hrv', nav, WcTrendPainter(mode: WcMode.week, vals: hrv7, labels: weekLabels(v.date), band: v.hrvRange == null ? null : (v.hrvRange!.lo, v.hrvRange!.hi)), height: 170),
        weekCard('Пульс в покое', 'trend-resting_hr', nav, WcTrendPainter(mode: WcMode.week, vals: rhr7, labels: weekLabels(v.date), band: v.rhrRange == null ? null : (v.rhrRange!.lo, v.rhrRange!.hi)), height: 170),
        WhBigButton('Влияние привычек', icon: 'journal', onTap: () => nav.go('journal-insights')),
        WhNote(v.recoveryIsWhoop ? 'Как считается: ВСР (ln RMSSD), пульс в покое и дыхание сравниваются с вашей 30-дневной нормой как z-оценки, плюс показатель сна; шкала 1–99, зелёная зона от 67 %, жёлтая 34–66 % — пороги WHOOP, веса компонентов подобраны.' : 'Показан индекс готовности OpenStrap: WHOOP-расчёт появится после 7 ночей с ВСР.'),
      ],
    );
  }
}

Widget weekCard(String title, String target, WhNav nav, CustomPainter painter, {double height = 190, Widget? legend}) => WhCard(
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

class WhStrain extends StatelessWidget {
  final WhView view;
  const WhStrain({super.key, required this.view});
  @override
  Widget build(BuildContext c) {
    final v = view, d = v.d;
    final nav = WhNav(c, v);
    final obs = v.observations().where((o) => o.kind == ObservationKind.strain).toList();
    final s = v.strain;
    final t = v.strainTarget;
    final week = v.week;
    double? wk(Map<String, dynamic> r, String k) => r[k] is num ? (r[k] as num).toDouble() : null;
    final strain7 = trailing(d.series['whoop_strain']?.isNotEmpty == true ? d.series['whoop_strain']! : d.strain, v.date, 7, excludeEnd: false);
    if (s != null) strain7[6] = s;
    final z13w = trailing(d.series['whoop_z13_min'] ?? const [], v.date, 7, excludeEnd: false);
    if (v.z13Today != null) z13w[6] = v.z13Today;
    final z45w = trailing(d.series['whoop_z45_min'] ?? const [], v.date, 7, excludeEnd: false);
    if (v.z45Today != null) z45w[6] = v.z45Today;
    final steps7 = trailing(d.steps, v.date, 7, excludeEnd: false);
    if (v.steps != null) steps7[6] = v.steps;
    double? avg(Iterable<double?> xs) {
      final l = [for (final x in xs) ?x];
      return l.isEmpty ? null : l.reduce((a, b) => a + b) / l.length;
    }

    final z13avg = avg(week.map((r) => wk(r, 'whoop_z13_min')));
    final z45avg = avg(week.map((r) => wk(r, 'whoop_z45_min')));
    double strengthMin = 0;
    for (final a in d.activities) {
      final type = (a['type']?.toString() ?? '').toLowerCase();
      if (type.contains('weight') || type.contains('strength') || type.contains('lift') || type.contains('силов')) strengthMin += (a['duration_min'] as num?)?.toDouble() ?? 0;
    }
    return WhPage(
      title: v.isToday ? 'Сегодня' : dowShort(v.date),
      children: [
        WcDial(color: W.strain, fraction: s == null ? null : s / 21, big: s == null ? '—' : ruDecimal(s), caption: 'Нагрузка за день', goal: t == null ? null : (t.$1 + t.$2) / 2 / 21),
        if (t != null) Center(child: Padding(padding: const EdgeInsets.only(top: S.x1), child: Text('Цель ${ruDecimal(t.$1)}–${ruDecimal(t.$2)} · отметка на кольце', style: FW.hint.copyWith(color: W.ink3)))),
        WhCard(
          tip: true,
          padding: const EdgeInsets.fromLTRB(S.x4, S.x2, S.x4, S.x3),
          child: Column(
            children: [
              WhRow(icon: 'hr_zone_3', label: 'Зоны пульса 1–3', value: hmOf(v.z13Today), prev: z13avg == null ? null : hmOf(z13avg), dir: dirOf(v.z13Today, z13avg, eps: 2), onTap: () => nav.go('trend-zones13')),
              WhRow(icon: 'hr_zone_4_5', label: 'Зоны пульса 4–5', value: hmOf(v.z45Today), prev: z45avg == null ? null : hmOf(z45avg), dir: dirOf(v.z45Today, z45avg, eps: 2), onTap: () => nav.go('trend-zones45')),
              WhRow(icon: 'strength_training', label: 'Силовая нагрузка', value: d.activities.isEmpty ? '—' : hmOf(strengthMin), prev: null, dir: 'eq', onTap: () => nav.go('activity-day')),
              WhRow(icon: 'steps', label: 'Шаги', value: groupThousands(v.steps), prev: v.stepsRange == null ? null : groupThousands(v.stepsRange!.median), dir: dirOf(v.steps, v.stepsRange?.median), onTap: () => nav.go('trend-steps')),
              WhLegendNote(children: [const WhTri('up'), const WhTri('dn'), const SizedBox(width: S.x1), Text.rich(TextSpan(children: [TextSpan(text: v.isToday ? 'Сегодня' : dowShort(v.date), style: FW.hint.copyWith(color: W.ink, fontWeight: FontWeight.w600)), TextSpan(text: ' vs. неделя (зоны) и 30 дней (шаги)', style: FW.hint.copyWith(color: W.ink2))]))]),
            ],
          ),
        ),
        if (obs.isNotEmpty) WhObservationCard(text: '${obs.first.title}. ${obs.first.text}', link: obs.first.link, onLink: () => nav.go(obs.first.target)),
        const WhSection('Активности за день'),
        WhCard(
          child: Column(
            children: [
              for (final row in d.activities) _ActRow(icon: activityIconOf(row['type']?.toString()), tag: ruDecimal((row['whoop_strain'] as num?) ?? (row['strain'] as num?)), name: familiarActivityName(c, row['type']?.toString()), start: clockOf((row['start_ts'] as num?)?.toInt()), end: clockOf((row['end_ts'] as num?)?.toInt()), color: W.strain, onTap: () => nav.workout(row)),
              if (d.activities.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: S.x2), child: Text('Активностей за день нет. Нагрузка всё равно копится из пульса в течение дня.', style: FW.hint.copyWith(color: W.ink3))),
              const SizedBox(height: S.x1),
              Row(
                children: [
                  Expanded(child: WhPill('Добавить', icon: 'add', onTap: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const LogWorkout())))),
                  const SizedBox(width: S.x2 + 2),
                  Expanded(child: WhPill('Начать', icon: 'start_activity', onTap: () => openFamiliarActivityPicker(c))),
                ],
              ),
            ],
          ),
        ),
        const WhSection('Недельные тренды'),
        weekCard('Нагрузка', 'trend-strain', nav, WcBarsPainter(mode: WcMode.week, vals: strain7, labels: weekLabels(v.date), colors: const [W.strain], fmt: ruDecimal, yTicks: const [0, 5, 10, 15, 21], yFmt: (x) => '${x.round()}', todayIdx: 6)),
        weekCard('Зоны пульса 1–3', 'trend-zones13', nav, WcStackedPainter(groups: [for (final x in z13w) x == null ? null : [x]], colors: const [W.z2], labels: weekLabels(v.date), values: true, todayIdx: 6), height: 180, legend: const WhLegend([(W.z2, 'зоны 1–3, минуты')])),
        weekCard('Зоны пульса 4–5', 'trend-zones45', nav, WcStackedPainter(groups: [for (final x in z45w) x == null ? null : [x]], colors: const [W.z4], labels: weekLabels(v.date), values: true, todayIdx: 6), height: 180, legend: const WhLegend([(W.z4, 'зоны 4–5, минуты')])),
        weekCard('Шаги', 'trend-steps', nav, WcBarsPainter(mode: WcMode.week, vals: steps7, labels: weekLabels(v.date), colors: const [W.strain], fmt: groupThousands, yTicks: const [0, 3000, 6000, 9000, 12000], yFmt: (x) => x == 0 ? '0' : '${(x / 1000).round()} тыс.', todayIdx: 6, valueColor: W.ink), height: 180),
        WhNote(v.strainIsWhoop ? 'Как считается: резерв пульса v = (HR − RHR)/(MHR − RHR), взвешенный интеграл за день, нормировка на 24 ч и шкала 21·½·(arctan(k·(N − p))/(π/2)+1) — структура патента WHOOP US 9,750,415; вес и k, p подобраны. Зоны: 50/60/70/80/90 % резерва.' : 'Нагрузка OpenStrap (Banister TRIMP). WHOOP-расчёт включится, когда известны возраст, пол и пульс покоя.'),
      ],
    );
  }
}

class _ActRow extends StatelessWidget {
  final String icon, tag, name, start, end;
  final Color color;
  final VoidCallback onTap;
  const _ActRow({required this.icon, required this.tag, required this.name, required this.start, required this.end, required this.color, required this.onTap});
  @override
  Widget build(BuildContext c) => Pressable(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: S.x2),
      padding: const EdgeInsets.fromLTRB(S.x2, S.x2, S.x2 + 2, S.x2),
      decoration: BoxDecoration(color: W.card2, borderRadius: WR.rChip),
      child: Row(
        children: [
          Container(width: 74, height: 38, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.all(Radius.circular(9))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [WhIcon(icon, size: 15, color: W.ink), const SizedBox(width: 5), Text(tag, style: FW.n15.copyWith(color: W.ink))])),
          const SizedBox(width: S.x3),
          Expanded(child: Text(name.toUpperCase(), style: FW.label.copyWith(color: W.ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(start, style: FW.axisNum.copyWith(color: W.ink4)), const SizedBox(height: 2), Text(end, style: FW.axisNum.copyWith(color: W.ink4))]),
          const SizedBox(width: S.x1 + 2),
          Container(width: 3, height: 26, decoration: BoxDecoration(color: color, borderRadius: WR.rTiny)),
        ],
      ),
    ),
  );
}
