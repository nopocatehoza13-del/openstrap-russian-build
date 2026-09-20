// Healthspan (age + pace + factors) and the Health Monitor detail.
import 'package:flutter/material.dart';

import '../grammar.dart';
import '../screens/metric_detail.dart';
import '../theme.dart';
import 'data.dart';
import 'wh_data.dart';
import 'wh_home.dart' show WcOrb, WhLivePulse;
import 'wh_nav.dart';
import 'wh_widgets.dart';
import 'whoop_charts.dart';

/// Factor scales for the Healthspan bars: (lo, hi, formatter, unit hint).
({double lo, double hi, String Function(double) f}) factorScale(String key) => switch (key) {
  'sleep_hours' => (lo: 5, hi: 9, f: (v) => '${hmOf(v * 60)} ч'),
  'sleep_consistency' => (lo: 40, hi: 100, f: (v) => '${v.round()}%'),
  'steps' => (lo: 3000, hi: 12000, f: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '')} тыс.' : '${v.round()}'),
  'zones_1_3' => (lo: 0, hi: 300, f: (v) => hmOf(v)),
  'zones_4_5' => (lo: 0, hi: 150, f: (v) => hmOf(v)),
  'strength' => (lo: 0, hi: 150, f: (v) => hmOf(v)),
  'vo2max' => (lo: 25, hi: 60, f: (v) => v.round().toString()),
  'resting_hr' => (lo: 75, hi: 45, f: (v) => v.round().toString()),
  'lean_mass' => (lo: 65, hi: 90, f: (v) => '${v.round()}%'),
  _ => (lo: 0, hi: 1, f: (v) => v.toStringAsFixed(1)),
};

String factorTitle(String key) => switch (key) {
  'sleep_hours' => 'Часы сна',
  'sleep_consistency' => 'Регулярность сна',
  'steps' => 'Шаги',
  'zones_1_3' => 'Зоны 1–3, в неделю',
  'zones_4_5' => 'Зоны 4–5, в неделю',
  'strength' => 'Силовые, в неделю',
  'vo2max' => 'VO₂ max',
  'resting_hr' => 'Пульс в покое',
  'lean_mass' => 'Безжировая масса',
  _ => key,
};

String factorTrend(String key) => switch (key) {
  'sleep_hours' => 'trend-hours',
  'sleep_consistency' => 'trend-consistency',
  'steps' => 'trend-steps',
  'zones_1_3' => 'trend-zones13',
  'zones_4_5' => 'trend-zones45',
  'resting_hr' => 'trend-resting_hr',
  _ => 'trend-hrv',
};

String factorIcon(String key) => switch (key) {
  'strength' => 'strength_training',
  'vo2max' => 'vo2_max',
  'lean_mass' => 'lean_body_mass',
  'zones_4_5' => 'hr_zone_4_5',
  'zones_1_3' => 'hr_zone_3',
  'steps' => 'steps',
  'resting_hr' => 'rhr',
  'sleep_hours' => 'hours_of_sleep',
  _ => 'consistency',
};

class FamiliarAgeDetail extends StatelessWidget {
  final FamiliarData data;
  const FamiliarAgeDetail({super.key, required this.data});
  @override
  Widget build(BuildContext c) {
    final v = WhView(data, DateTime.tryParse(data.day) ?? DateTime.now());
    final nav = WhNav(c, v);
    final age = v.age, chrono = v.chrono, pace = v.pace;
    final on = pace == null ? null : ((pace + 1) / 4 * 39).round().clamp(0, 39);
    final factors = v.ageFactors;
    final end = v.date;
    final startW = DateTime(end.year, end.month, end.day - 6);
    return WhPage(
      title: 'Healthspan',
      subtitle: 'по опубликованной модели WHOOP',
      children: [
        Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: S.x1), child: Text('${startW.day} – ${end.day} ${ruMonthsGen[end.month - 1]}'.toUpperCase(), style: FW.label.copyWith(color: W.ink)))),
        WcOrb(
          size: 300,
          big: age == null ? '—' : ruDecimal(age),
          caption: 'Возраст организма',
          delta: age == null || chrono == null ? (chrono == null ? 'укажите возраст в профиле' : 'нужно ≥3 факторов за 30 дней') : age <= chrono ? 'на ${ruDecimal(chrono - age)} года моложе' : 'на ${ruDecimal(age - chrono)} года старше',
          deltaColor: age == null || chrono == null ? W.ink3 : age <= chrono ? W.young : W.neg,
        ),
        Padding(
          padding: const EdgeInsets.only(top: S.x4),
          child: Column(
            children: [
              Row(children: [const WhIcon('slow_pace_of_aging', size: 14, color: W.ink3), const SizedBox(width: S.x1), Text('Медленно', style: FW.sub.copyWith(color: W.ink2)), const Spacer(), Text(pace == null ? '—' : '${ruDecimal(pace)}x', style: FW.n20.copyWith(color: W.ink)), const Spacer(), Text('Быстро', style: FW.sub.copyWith(color: W.ink2)), const SizedBox(width: S.x1), const WhIcon('fast_pace_of_aging', size: 14, color: W.ink3)]),
              const SizedBox(height: S.x2),
              SizedBox(height: 36, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [for (var i = 0; i < 40; i++) Expanded(child: Container(height: i == on ? 36 : 22, margin: const EdgeInsets.only(right: 2), decoration: BoxDecoration(color: i == on ? W.ink4 : W.track, borderRadius: const BorderRadius.all(Radius.circular(1)))))])),
              const SizedBox(height: S.x1 + 2),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final t in ['-1,0x', '1,0x', '3,0x']) Text(t, style: FW.axisNum.copyWith(color: W.axis))]),
            ],
          ),
        ),
        const SizedBox(height: S.x4),
        WhCard(
          tip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pace == null ? 'Темп старения появится через 4 недели данных' : pace <= 0.9 ? 'Стабильно и здорово' : pace <= 1.1 ? 'В темпе календаря' : 'Быстрее календаря', style: FW.b1.copyWith(color: W.ink)),
              const SizedBox(height: S.x1 + 2),
              Text(
                pace == null
                    ? 'Темп сравнивает возраст организма сейчас и 28 дней назад: 1,0x — как календарь, ниже — медленнее.'
                    : factors.isEmpty
                    ? 'Темп ${ruDecimal(pace)}x за последние четыре недели.'
                    : 'Темп ${ruDecimal(pace)}x за четыре недели. Больше всего влияет ${ageFactorName(factors.first['key'].toString())} (${((factors.first['years'] as num?) ?? 0) > 0 ? '+' : ''}${ruDecimal(factors.first['years'] as num?)} г).',
                style: FW.body.copyWith(color: W.ink2),
              ),
              const SizedBox(height: S.x2 + 2),
              Text('КАК РАССЧИТАНО →', style: FW.label.copyWith(color: W.ink)),
            ],
          ),
        ),
        WhSection('Факторы', right: Text('${factors.length} из 9 с данными', style: FW.sub.copyWith(color: W.ink3))),
        if (factors.isNotEmpty)
          WhCard(
            padding: const EdgeInsets.fromLTRB(S.x4, 0, S.x4, S.x2),
            child: Column(
              children: [
                for (final f in factors)
                  Builder(
                    builder: (_) {
                      final key = f['key'].toString();
                      final sc = factorScale(key);
                      final val = (f['value'] as num?)?.toDouble() ?? 0;
                      final pos = ((val - sc.lo) / (sc.hi - sc.lo) * 100).clamp(0, 100).toDouble();
                      final years = (f['years'] as num?)?.toDouble() ?? 0;
                      return WcFactorBar(
                        label: factorTitle(key),
                        p30: pos,
                        p6: pos,
                        v30: sc.f(val),
                        v6: '',
                        lo: sc.f(sc.lo),
                        hi: sc.f(sc.hi),
                        years: years,
                        text: years <= 0 ? factorGood(key) : factorImprove(key),
                        good: years <= 0,
                        onTrend: () => nav.go(factorTrend(key)),
                      );
                    },
                  ),
              ],
            ),
          ),
        if (v.ageMissing.isNotEmpty)
          WhCard(
            padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x1),
            child: Column(
              children: [
                for (final k in v.ageMissing)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: S.x2 + 2),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: W.line2))),
                    child: Row(children: [WhIcon(factorIcon(k), size: 20), const SizedBox(width: S.x3), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(factorTitle(k).toUpperCase(), style: FW.over.copyWith(color: W.ink)), Text('нет данных · не влияет на оценку', style: FW.hint.copyWith(color: W.ink2))])), const WhStatus('—', tone: -1)]),
                  ),
              ],
            ),
          ),
        const WhNote('Модель из white paper WHOOP 2025: девять факторов → относительный риск → Δвозраст = 10·ln(HR); кривые риска по опубликованным исследованиям (Cappuccio 2010, Windred 2023, Paluch 2022, Garcia 2023, Momma 2022, Mandsager 2018, Jensen 2013, Srikanthan 2014) с усадкой 0,5 за корреляцию факторов и потолком ±3 года на фактор. Не WHOOP Age и не медицинский показатель.'),
      ],
    );
  }
}

String factorGood(String key) => switch (key) {
  'sleep_consistency' => 'Регулярный график сна заметно улучшает долгосрочное здоровье. Так держать.',
  'sleep_hours' => 'Продолжительность сна около оптимальных 7–7,5 часов.',
  'steps' => 'Шагов больше референсных 6 000 в день: каждая тысяча снижает риск.',
  'zones_1_3' => 'Время в зонах 1–3 покрывает рекомендацию 150 минут умеренной нагрузки в неделю.',
  'zones_4_5' => 'Интенсивные минуты работают на сердечно-сосудистую форму.',
  'resting_hr' => 'Пульс в покое ниже референсных 60 уд/мин.',
  _ => 'Фактор работает в вашу пользу.',
};

String factorImprove(String key) => switch (key) {
  'sleep_consistency' => 'Отбой и подъём в одно время ±30 минут — самый быстрый способ снять эти годы.',
  'sleep_hours' => 'Средняя длительность сна отклоняется от 7–7,5 часов; проверьте потребность в планировщике.',
  'steps' => 'Меньше 6 000 шагов в день: 15 минут ходьбы добавляют около 1 500.',
  'zones_1_3' => 'До 150 минут умеренной нагрузки в неделю не хватает; быстрая ходьба уже считается.',
  'zones_4_5' => 'Пара интервальных тренировок в неделю закроет вклад этого фактора.',
  'resting_hr' => 'Пульс в покое выше 60: регулярные аэробные нагрузки и сон снижают его за несколько недель.',
  _ => 'Здесь есть куда расти.',
};

class FamiliarMonitorDetail extends StatelessWidget {
  final FamiliarData data;
  const FamiliarMonitorDetail({super.key, required this.data});
  @override
  Widget build(BuildContext c) {
    final v = WhView(data, DateTime.tryParse(data.day) ?? DateTime.now());
    const detail = {'resp': 'resp_rate', 'rhr': 'resting_hr', 'hrv': 'hrv', 'temp': 'skin_temp'};
    return WhPage(
      title: 'Монитор здоровья',
      right: const WhIcon('share', size: 18, color: W.ink),
      children: [
        const WhLivePulse(),
        Wrap(
          spacing: S.x2 + 2,
          runSpacing: S.x2 + 2,
          children: [
            for (final m in v.monitor)
              SizedBox(
                width: (MediaQuery.sizeOf(c).width - S.x4 * 2 - S.x2 - 2) / 2,
                child: Pressable(
                  onTap: detail[m.key] == null ? null : () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => MetricDetail(detail[m.key]!))),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 112),
                    padding: const EdgeInsets.all(S.x3 + 2),
                    decoration: BoxDecoration(color: W.card, borderRadius: WR.rTile),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [Expanded(child: Text(m.label.toUpperCase(), style: FW.over.copyWith(color: W.ink))), WhIcon(m.icon, size: 20)]),
                        const SizedBox(height: S.x3),
                        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(m.value == null ? '—' : m.value!.toStringAsFixed(m.key == 'resp' || m.key == 'temp' ? 1 : 0).replaceAll('.', ','), style: FW.n28.copyWith(color: W.ink)), const SizedBox(width: S.x1), Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(m.unit, style: FW.hint.copyWith(color: W.ink3)))]),
                        const SizedBox(height: S.x2),
                        WhStatus(m.level == 2 ? (m.range.contains('–') ? 'В норме · ${m.range}' : 'В норме') : m.level == 1 ? 'Вне нормы · ${m.range}' : m.key == 'temp' ? 'нет измерения в °C' : m.range, tone: m.level, icon: m.level == 2 ? 'checkmark' : m.level == 1 ? 'attention' : null),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: S.x3),
        WhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WhCardHead('Как читать'),
              Text('Норма — ваш личный диапазон между 10-м и 90-м перцентилем последних 30 ночей (у WHOOP — тоже личный диапазон). Зелёная галочка: внутри диапазона; оранжевый знак: за его пределами. Одно отклонение — повод посмотреть завтра, не тревога. ${data.temperatureC == null ? 'Температура кожи показывается только в °C из импорта WHOOP; относительный тепловой сигнал в градусы не переводится.' : ''}', style: FW.body.copyWith(color: W.ink2)),
            ],
          ),
        ),
        WhCard(
          child: Column(
            children: [
              WhKv('Ночь', data.nightDay.isEmpty ? '—' : data.nightDay),
              WhKv('Показателей измерено', '${v.monitorMeasured} из ${v.monitorTotal}'),
              WhKv('В вашем диапазоне', '${v.monitorInRange}', last: true),
            ],
          ),
        ),
      ],
    );
  }
}
