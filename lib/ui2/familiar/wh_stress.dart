// Stress Monitor — gauge, day timeline, scopes — over the experimental
// intraday model (`experimental_hr_activation_v1`), WHOOP layout.
import 'package:flutter/material.dart';
import 'package:personal_analytics/whoop_observations.dart';

import '../grammar.dart';
import '../theme.dart';
import 'data.dart';
import 'wh_data.dart';
import 'wh_nav.dart';
import 'wh_widgets.dart';
import 'whoop_charts.dart';

class FamiliarStressDetail extends StatefulWidget {
  final FamiliarData data;
  const FamiliarStressDetail({super.key, required this.data});
  @override
  State<FamiliarStressDetail> createState() => _FamiliarStressDetailState();
}

class _FamiliarStressDetailState extends State<FamiliarStressDetail> {
  int scope = 0;
  int? selected;
  static const scopes = ['all', 'rest', 'sleep'];
  static const scopeNames = ['Весь день', 'Без активности', 'Сон'];

  @override
  Widget build(BuildContext c) {
    final d = widget.data;
    final v = WhView(d, DateTime.tryParse(d.day) ?? DateTime.now());
    final nav = WhNav(c, v);
    final key = scopes[scope];
    final summary = v.stressSummary(key);
    final points = v.stressPoints;
    final values = [for (final p in points) (p[key] as num?)?.toDouble()];
    final chosen = selected != null && selected! < points.length ? points[selected!] : null;
    final mean = summary['mean'] as num?;
    final status = v.stressModel['status'];
    final cur = v.stressNow;
    final level = cur == null ? null : cur < 1 ? 'Низкий' : cur < 2 ? 'Умеренный' : 'Высокий';
    final obs = v.observations().where((o) => o.kind == ObservationKind.stress).toList();
    final startTs = (v.stressModel['start'] as num?)?.toInt() ?? (points.isEmpty ? null : (points.first['t'] as num?)?.toInt());
    final startHour = startTs == null ? 0.0 : DateTime.fromMillisecondsSinceEpoch(startTs * 1000).hour + DateTime.fromMillisecondsSinceEpoch(startTs * 1000).minute / 60;
    int? idxOf(num? ts) {
      if (ts == null || points.isEmpty) return null;
      for (var i = 0; i < points.length; i++) {
        if ((points[i]['t'] as num? ?? 0) >= ts) return i;
      }
      return points.length - 1;
    }

    final sleepSpan = idxOf(v.onsetTs) != null && idxOf(v.wakeTs) != null ? (idxOf(v.onsetTs)!, idxOf(v.wakeTs)!) : null;
    final acts = [for (final a in d.activities) if (idxOf(a['start_ts'] as num?) != null && idxOf(a['end_ts'] as num?) != null) (idxOf(a['start_ts'] as num?)!, idxOf(a['end_ts'] as num?)!)];
    var nowIdx = points.length - 1;
    while (nowIdx > 0 && points[nowIdx]['all'] == null) {
      nowIdx--;
    }
    final low = v.stressMin(key, 'low') ?? 0, med = v.stressMin(key, 'medium') ?? 0, high = v.stressMin(key, 'high') ?? 0;
    return WhPage(
      title: 'Монитор стресса',
      right: const WhIcon('settings', size: 20, color: W.ink),
      children: [
        Center(child: Padding(padding: const EdgeInsets.only(bottom: S.x2), child: Text(d.day == v.d.day && v.isToday ? 'СЕГОДНЯ' : d.day, style: FW.label.copyWith(color: W.ink)))),
        SizedBox(
          height: 186,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: WcGaugePainter(cur ?? 0))),
              Positioned(
                left: 0,
                right: 0,
                top: 62,
                child: Column(
                  children: [
                    Text(cur == null ? '—' : ruDecimal(cur), style: FW.n52.copyWith(color: W.ink)),
                    const SizedBox(height: S.x1),
                    Text((level ?? 'Нет данных').toUpperCase(), style: FW.h5.copyWith(color: cur == null ? W.ink3 : W.stress3(cur))),
                    const SizedBox(height: S.x2),
                    Text(v.stressNowTs == null ? 'нужны записи пульса и движения' : 'Обновлено ${clockOf(v.stressNowTs)}', style: FW.hint.copyWith(color: W.ink2)),
                    const SizedBox(height: S.x1),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${scopeNames[scope].toUpperCase()} · СРЕДНЕЕ ', style: FW.tiny.copyWith(color: W.ink3, letterSpacing: .6)),
                        Text('${mean == null ? '—' : ruDecimal(mean)} / 3', key: const ValueKey('stress-summary'), style: FW.n11.copyWith(color: W.ink)),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(left: 30, bottom: 0, child: Text('0,0', style: FW.axisNum.copyWith(color: W.axis))),
              Positioned(right: 30, bottom: 0, child: Text('3,0', style: FW.axisNum.copyWith(color: W.axis))),
              const Positioned(right: 0, top: 4, child: WhInfoDot()),
            ],
          ),
        ),
        const SizedBox(height: S.x3),
        WhCard(
          padding: const EdgeInsets.fromLTRB(S.x3, S.x3, S.x3, S.x2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (points.length >= 2)
                Scrubber(
                  key: const ValueKey('stress-chart'),
                  value: selected == null ? null : selected! / (points.length > 1 ? points.length - 1 : 1),
                  step: 1 / (points.length > 1 ? points.length - 1 : 1),
                  label: 'График стресса, шкала от 0 до 3',
                  onChanged: (x) => setState(() => selected = (x * (points.length - 1)).round().clamp(0, points.length - 1)),
                  describe: (x) {
                    final p = points[(x * (points.length - 1)).round().clamp(0, points.length - 1)];
                    return '${clockOf((p['t'] as num?)?.toInt())}: ${ruDecimal(p[key] as num?)}';
                  },
                  child: WcBox(WcStressPainter(vals: values, startHour: startHour, stepMin: 5, nowIdx: nowIdx, sleep: sleepSpan, acts: acts, cursor: selected, endLabel: clockOf((points[nowIdx]['end'] as num?)?.toInt() ?? (points[nowIdx]['t'] as num?)?.toInt())), height: 200),
                )
              else
                Padding(padding: const EdgeInsets.symmetric(vertical: S.x4), child: Text('График появится, когда за день будут записи пульса и движения с браслета.', style: FW.hint.copyWith(color: W.ink3))),
              Padding(
                padding: const EdgeInsets.only(top: S.x1 + 2),
                child: Text(
                  chosen == null ? 'Нажмите на график, чтобы посмотреть интервал' : '${clockOf((chosen['t'] as num?)?.toInt())}–${clockOf((chosen['end'] as num?)?.toInt())}: ${ruDecimal(chosen[key] as num?)}',
                  key: const ValueKey('stress-selected'),
                  style: FW.hint.copyWith(color: W.ink3),
                ),
              ),
            ],
          ),
        ),
        if (obs.isNotEmpty) WhObservationCard(text: '${obs.first.title}. ${obs.first.text}', link: obs.first.link, onLink: () => nav.go(obs.first.target)),
        WhChips(labels: scopeNames, selected: scope, onSelect: (i) => setState(() {
          scope = i;
          selected = null;
        })),
        WhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [WhIcon(scope == 2 ? 'sleep' : scope == 1 ? 'non_activity_stress' : 'day_stress', size: 16, color: W.ink), const SizedBox(width: S.x2), Text(scopeNames[scope].toUpperCase(), style: FW.label.copyWith(color: W.ink))]),
              const SizedBox(height: S.x2 + 2),
              Row(
                children: [
                  Expanded(child: Text(v.isToday ? 'СЕГОДНЯ · СРЕДНЕЕ' : '${d.day} · СРЕДНЕЕ', style: FW.over.copyWith(color: W.ink2))),
                  Text(mean == null ? '—' : ruDecimal(mean), style: FW.n17.copyWith(color: W.ink)),
                ],
              ),
              const SizedBox(height: S.x2),
              if (mean != null) WcStressStack([low, med, high]),
              const SizedBox(height: S.x2),
              Row(
                children: [
                  for (final (label, m, col) in [('Низкий', low, W.stressLow), ('Умеренный', med, W.stressMed), ('Высокий', high, W.stressHigh)])
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mean == null ? '—' : hmOf(m), style: FW.n15.copyWith(color: W.ink)),
                          const SizedBox(height: 3),
                          Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: col, borderRadius: WR.rTiny)), const SizedBox(width: 5), Flexible(child: Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: FW.tiny.copyWith(color: W.ink3, letterSpacing: .4)))]),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: S.x2 + 2),
              Text(
                mean != null
                    ? (scope == 0 ? 'Стресс за день, включая сон и активности. Измерено ${hmOf(((summary['covered_sec'] as num?) ?? 0) / 60)}.' : scope == 1 ? 'Без отмеченных тренировок, заметного движения и интервалов сна.' : 'Во время интервалов сна OpenStrap, включая дремоту.')
                    : status == 'need_quiet_reference'
                    ? 'Пока мало спокойных участков: ${v.stressModel['reference_minutes'] ?? 0} из 60 минут, ${v.stressModel['reference_hours'] ?? 0} из 3 разных часов. Носите браслет и синхронизируйте записи.'
                    : status == 'ready'
                    ? 'Для этого раздела нет подходящих измерений. Нулевой стресс не подставляется.'
                    : 'Нужны записи пульса и движения с браслета. Синхронизируйте его; сводного CSV WHOOP недостаточно.',
                style: FW.hint.copyWith(color: W.ink3),
              ),
            ],
          ),
        ),
        WhCard(
          onTap: () => nav.go('stress-trends'),
          child: Row(children: [const WhIcon('trend', size: 20), const SizedBox(width: S.x3), Expanded(child: Text('Тренды стресса и ночной индекс', style: FW.b1.copyWith(color: W.ink))), const WhIcon('navigation_forward', size: 12, color: W.ink4)]),
        ),
        WhBigButton('Дыхательная сессия', icon: 'stress_monitor_low', onTap: () => nav.go('breathing')),
        if (v.stressModel['reference_bpm'] is num) WhNote('Опорный пульс дня ${ruDecimal(v.stressModel['reference_bpm'] as num)} уд/мин · график по 5 минут · шкала 0–3 с зонами WHOOP (<1 низкий, 1–2 умеренный, ≥2 высокий); сама оценка — собственная модель активации пульса, не формула WHOOP.'),
      ],
    );
  }
}
