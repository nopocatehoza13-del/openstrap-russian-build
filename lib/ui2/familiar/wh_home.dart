// Home and Health tabs of the Familiar (WHOOP-parity) surface, over the real
// repository through FamiliarData. Layout follows design/whoop-mock-v6.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/day_label.dart';
import '../../state/app_state.dart';
import '../grammar.dart';
import '../profile/devices.dart';
import '../revision.dart';
import '../screens/home_screen.dart' show repoOf;
import '../screens/log_workout.dart';
import '../screens/workout_screen.dart' show openFamiliarActivityPicker, familiarActivityName;
import '../theme.dart';
import 'data.dart';
import 'wh_data.dart';
import 'wh_nav.dart';
import 'wh_widgets.dart';
import 'whoop_charts.dart';

/// Familiar presentation over the real Flutter repository, not a WebView.
class FamiliarDashboard extends StatefulWidget {
  final bool health;
  final FamiliarData? data;
  const FamiliarDashboard({super.key, this.health = false, this.data});
  @override
  State<FamiliarDashboard> createState() => _FamiliarDashboardState();
}

class _FamiliarDashboardState extends State<FamiliarDashboard> with RevisionReload {
  late DateTime date = DateTime.now();
  FamiliarData? data;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    data = widget.data;
    if (data == null) reload();
  }

  @override
  void reload() {
    if (widget.data != null) return;
    final token = beginRead(#familiar);
    final repo = repoOf(context);
    if (repo == null) return;
    final app = context.read<AppState>();
    setState(() {
      loading = true;
      error = null;
    });
    FamiliarData.load(repo, date, batteryPct: app.device.batteryPct, charging: app.device.charging == true)
        .then((value) {
          if (!mounted || !stillNewest(#familiar, token)) return;
          setState(() {
            data = value;
            loading = false;
          });
        })
        .catchError((Object e) {
          if (!mounted || !stillNewest(#familiar, token)) return;
          setState(() {
            loading = false;
            error = 'Не удалось прочитать данные. Повторите загрузку.';
          });
        });
  }

  Future<void> open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) reload();
  }

  void changeDay(int delta) {
    setState(() {
      date = DateTime(date.year, date.month, date.day + delta);
      data = null;
    });
    reload();
  }

  @override
  Widget build(BuildContext c) {
    final d = data ?? FamiliarData(day: dayLabelOf(date));
    final v = WhView(d, date);
    final nav = WhNav(c, v, onReturn: () {
      if (mounted) reload();
    });
    return ColoredBox(
      color: W.bg,
      child: RefreshIndicator(
        color: W.action,
        backgroundColor: W.card,
        onRefresh: () async {
          final app = c.read<AppState>();
          try {
            await app.syncNow();
          } finally {
            if (mounted) reload();
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(S.x4, S.x1, S.x4, S.x10),
          children: [
            _TopBar(
              title: widget.health ? 'ЗДОРОВЬЕ' : null,
              dayLabel: v.isToday ? 'Сегодня' : dowShort(date),
              canForward: !v.isToday,
              onPrev: loading ? null : () => changeDay(-1),
              onNext: v.isToday || loading ? null : () => changeDay(1),
              onDate: widget.health
                  ? null
                  : () async {
                      final picked = await showDatePicker(context: c, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (picked != null && mounted) {
                        setState(() {
                          date = picked;
                          data = null;
                        });
                        reload();
                      }
                    },
              battery: d.batteryPct,
              onBattery: () => open(const MyDevices()),
            ),
            if (loading) const LinearProgressIndicator(color: W.action, backgroundColor: W.card2),
            if (error != null)
              WhCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(error!, style: FW.body.copyWith(color: W.ink)),
                    const SizedBox(height: S.x2),
                    WhPill('Повторить', icon: 'refresh', onTap: reload),
                  ],
                ),
              ),
            if (widget.health) ..._healthTab(c, v, nav) else ..._homeTab(c, v, nav),
          ],
        ),
      ),
    );
  }

  // ── HOME ──────────────────────────────────────────────────────────────────
  List<Widget> _homeTab(BuildContext c, WhView v, WhNav nav) {
    final d = v.d;
    final obs = v.observations();
    final sleepPct = v.sleepPerf;
    return [
      Center(child: Padding(padding: const EdgeInsets.fromLTRB(0, S.x1, 0, S.x3 + 2), child: Text('WHOOD', style: FW.wordmark.copyWith(color: W.ink4)))),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: WcRing(label: 'Сон', value: sleepPct == null ? '—' : '${sleepPct.round()}', suffix: sleepPct == null ? null : '%', fraction: sleepPct == null ? null : sleepPct / 100, color: W.sleep, onTap: () => nav.go('sleep'))),
          Expanded(child: WcRing(label: 'Восстановление', value: v.recovery == null ? '—' : '${v.recovery!.round()}', suffix: v.recovery == null ? null : '%', fraction: v.recovery == null ? null : v.recovery! / 100, color: W.recovery3(v.recovery), onTap: () => nav.go('recovery'))),
          Expanded(child: WcRing(label: 'Нагрузка', value: v.strain == null ? '—' : ruDecimal(v.strain), fraction: v.strain == null ? null : v.strain! / 21, color: W.strain, onTap: () => nav.go('strain'))),
        ],
      ),
      const SizedBox(height: S.x4 + 2),
      if (obs.isNotEmpty)
        WhObservationCard(
          key: ValueKey('obs-${obs.first.id}'),
          eyebrow: 'Наблюдение · ${v.isToday ? 'сегодня' : dowShort(date)}, ${obs.first.time}',
          text: '${obs.first.title}\n${obs.first.text}',
          link: obs.first.link,
          onLink: () => nav.go(obs.first.target),
          badge: WhCountBadge(obs.length),
          onDismiss: () => setState(() => dismissObservation(obs.first.id)),
        ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _MiniCard(
              title: 'Монитор здоровья',
              badge: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: (v.monitorMeasured > 0 && v.monitorInRange == v.monitorMeasured ? W.action : W.neg).withValues(alpha: .15), borderRadius: WR.rBar),
                child: Center(child: WhIcon(v.monitorMeasured > 0 && v.monitorInRange == v.monitorMeasured ? 'checkmark' : 'attention', size: 11, color: v.monitorMeasured > 0 && v.monitorInRange == v.monitorMeasured ? W.action : W.neg)),
              ),
              status: v.monitorMeasured == 0 ? 'Нет данных' : v.monitorInRange == v.monitorMeasured ? 'В норме' : 'Отклонение',
              statusColor: v.monitorMeasured == 0 ? W.ink3 : v.monitorInRange == v.monitorMeasured ? W.action : W.neg,
              sub: '${v.monitorInRange}/${v.monitorTotal} показателей',
              onTap: () => nav.go('health-monitor'),
            ),
          ),
          const SizedBox(width: S.x3),
          Expanded(
            child: _MiniCard(
              title: 'Монитор стресса',
              badge: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: (v.stressNow == null ? W.track : W.stress3(v.stressNow!)).withValues(alpha: .18), borderRadius: WR.rBar),
                child: Center(child: Text(v.stressNow == null ? '—' : ruDecimal(v.stressNow), style: FW.n11.copyWith(color: v.stressNow == null ? W.ink3 : W.stress3(v.stressNow!)))),
              ),
              status: v.stressNow == null ? 'Нет данных' : v.stressNow! < 1 ? 'Низкий' : v.stressNow! < 2 ? 'Умеренный' : 'Высокий',
              statusColor: v.stressNow == null ? W.ink3 : W.stress3(v.stressNow!),
              sub: v.stressNowTs == null ? 'нужны записи пульса' : clockOf(v.stressNowTs),
              onTap: () => nav.go('stress'),
            ),
          ),
        ],
      ),
      WhSection(
        'Мой день',
        right: Pressable(
          onTap: () => open(const LogWorkout()),
          semanticLabel: 'Добавить активность',
          child: Container(width: 30, height: 30, decoration: BoxDecoration(color: W.ink, borderRadius: WR.rBar), child: const Center(child: WhIcon('add', size: 16, color: W.onLight))),
        ),
      ),
      Pressable(
        onTap: () => nav.go('observations'),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: S.x3 + 2),
          margin: const EdgeInsets.only(bottom: S.x3),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [W.card3, W.card2, W.card]), borderRadius: WR.rChip),
          child: Row(
            children: [
              const WhIcon('advice', size: 16, color: W.ink),
              const SizedBox(width: S.x2 + 2),
              Text('Наблюдения за день', style: FW.b1.copyWith(color: W.ink)),
              const SizedBox(width: S.x2),
              Text('${v.allObservations().length}', style: FW.sub.copyWith(color: W.ink2)),
              const Spacer(),
              const WhIcon('navigation_forward', size: 12, color: W.ink4),
            ],
          ),
        ),
      ),
      WhCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WhCardHead('Активности за день', right: Pressable(onTap: () => nav.go('activity-day'), semanticLabel: 'Все активности', child: const WhIcon('trend', size: 14, color: W.ink4))),
            if (d.sleep['duration_min'] is num)
              _ActivityRow(icon: 'sleep', tag: hmOf(d.sleep['duration_min'] as num), name: 'Сон', start: clockOf((d.sleep['onset_ts'] as num?)?.toInt()), end: clockOf((d.sleep['wake_ts'] as num?)?.toInt()), color: W.sleep, onTap: () => nav.go('sleep')),
            for (final row in d.activities)
              _ActivityRow(
                icon: activityIconOf(row['type']?.toString()),
                tag: ruDecimal((row['whoop_strain'] as num?) ?? (row['strain'] as num?)),
                name: familiarActivityName(c, row['type']?.toString()),
                start: clockOf((row['start_ts'] as num?)?.toInt()),
                end: clockOf((row['end_ts'] as num?)?.toInt()),
                color: W.strain,
                onTap: () => nav.workout(row),
              ),
            if (d.activities.isEmpty && d.sleep['duration_min'] is! num)
              Padding(padding: const EdgeInsets.symmetric(vertical: S.x3), child: Text('На этот день записей нет. Синхронизируйте браслет или добавьте активность.', style: FW.body.copyWith(color: W.ink2))),
            const SizedBox(height: S.x1),
            Row(
              children: [
                Expanded(child: WhPill('Добавить', icon: 'add', onTap: () => open(const LogWorkout()))),
                const SizedBox(width: S.x2 + 2),
                Expanded(child: WhPill('Начать', icon: 'start_activity', onTap: () => openFamiliarActivityPicker(c).then((_) => mounted ? reload() : null))),
              ],
            ),
          ],
        ),
      ),
      if (v.isToday)
        WhCard(
          onTap: () => nav.go('tonight'),
          child: Row(
            children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: W.sleep.withValues(alpha: .18), borderRadius: WR.rBar), child: const Center(child: WhIcon('bedtime', size: 18, color: W.sleep))),
              const SizedBox(width: S.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('СОН СЕГОДНЯ', style: FW.label.copyWith(color: W.ink2)),
                    const SizedBox(height: 3),
                    Text(_tonightLine(v), style: FW.b1.copyWith(color: W.ink)),
                    Text(v.needTonightMin == null ? 'Потребность появится после первой ночи с браслетом' : 'Потребность ${hmOf(v.needTonightMin)} · цель ${v.sleepGoalPct} %', style: FW.hint.copyWith(color: W.ink3)),
                  ],
                ),
              ),
              const WhIcon('navigation_forward', size: 12, color: W.ink4),
            ],
          ),
        ),
      WhSection('Мои показатели', right: Pressable(onTap: () => nav.go('all-metrics'), child: Row(children: [const WhIcon('customize', size: 12, color: W.ink), const SizedBox(width: S.x1 + 2), Text('НАСТРОИТЬ', style: FW.over.copyWith(color: W.ink))]))),
      WhCard(
        padding: const EdgeInsets.symmetric(horizontal: S.x4, vertical: S.x1),
        child: Column(
          children: [
            for (final row in _dashboardRows(v)) WhRow(icon: row.icon, label: row.label, value: row.value, prev: row.prev, dir: row.dir, goodIsUp: row.goodIsUp, onTap: () => nav.go(row.target)),
          ],
        ),
      ),
      const WhSection('Дневник'),
      WhCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WhCardHead('Мой дневник', right: Pressable(onTap: () => nav.go('journal'), semanticLabel: 'Открыть дневник', child: const WhIcon('navigation_forward', size: 14, color: W.ink4))),
            _JournalWeek(days: v.journalDays, end: date),
            WhPill('Влияние привычек', icon: 'advice', onTap: () => nav.go('journal-insights')),
          ],
        ),
      ),
      const WhNote('Отсутствующие данные показываются как «—». Расчёты по опубликованным формулам WHOOP; см. «Как считается» на каждом экране.'),
    ];
  }

  String _tonightLine(WhView v) {
    final need = v.needTonightMin;
    if (need == null) return 'Планировщик сна';
    final wake = v.wakePrefMin >= 0 ? v.wakePrefMin : (v.wakeTs == null ? 7 * 60 : DateTime.fromMillisecondsSinceEpoch(v.wakeTs! * 1000).hour * 60 + DateTime.fromMillisecondsSinceEpoch(v.wakeTs! * 1000).minute);
    final bed = ((wake - need * v.sleepGoalPct / 100) % 1440 + 1440) % 1440;
    String clk(num m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).round().toString().padLeft(2, '0')}';
    return 'Лечь до ${clk(bed)} · подъём ${clk(wake)}';
  }

  List<({String icon, String label, String value, String? prev, String dir, bool goodIsUp, String target})> _dashboardRows(WhView v) {
    String f0(double? x) => x == null ? '—' : x.round().toString();
    final rows = <({String icon, String label, String value, String? prev, String dir, bool goodIsUp, String target})>[
      (icon: 'hrv', label: 'Вариабельность ритма', value: f0(v.hrv), prev: v.hrvRange == null ? null : f0(v.hrvRange!.median), dir: dirOf(v.hrv, v.hrvRange?.median), goodIsUp: true, target: 'trend-hrv'),
      (icon: 'rhr', label: 'Пульс в покое', value: f0(v.rhr), prev: v.rhrRange == null ? null : f0(v.rhrRange!.median), dir: dirOf(v.rhr, v.rhrRange?.median, lowerBetter: true), goodIsUp: true, target: 'trend-resting_hr'),
      (icon: 'sleep_performance', label: 'Показатель сна', value: v.sleepPerf == null ? '—' : '${v.sleepPerf!.round()}%', prev: v.rangeOfKey('whoop_sleep_perf') == null ? null : '${v.rangeOfKey('whoop_sleep_perf')!.median.round()}%', dir: dirOf(v.sleepPerf, v.rangeOfKey('whoop_sleep_perf')?.median), goodIsUp: true, target: 'trend-sleepperf'),
      (icon: 'respiratory_rate', label: 'Частота дыхания', value: ruDecimal(v.resp), prev: v.respRange == null ? null : ruDecimal(v.respRange!.median), dir: dirOf(v.resp, v.respRange?.median, eps: .3), goodIsUp: false, target: 'trend-respiratory_rate'),
      (icon: 'steps', label: 'Шаги', value: groupThousands(v.steps), prev: v.stepsRange == null ? null : groupThousands(v.stepsRange!.median), dir: dirOf(v.steps, v.stepsRange?.median), goodIsUp: true, target: 'trend-steps'),
      (icon: 'restorative_sleep', label: 'Восстанавливающий сон', value: hmOf(v.restorativeMin), prev: v.rangeOfKey('deep') == null || v.rangeOfKey('rem') == null ? null : hmOf(v.rangeOfKey('deep')!.median + v.rangeOfKey('rem')!.median), dir: dirOf(v.restorativeMin, v.rangeOfKey('deep') == null || v.rangeOfKey('rem') == null ? null : v.rangeOfKey('deep')!.median + v.rangeOfKey('rem')!.median), goodIsUp: true, target: 'trend-restorative'),
      (icon: 'time_in_bed', label: 'Время в постели', value: hmOf(v.inBedMin), prev: null, dir: 'eq', goodIsUp: true, target: 'trend-tib'),
    ];
    return rows;
  }

  // ── HEALTH ────────────────────────────────────────────────────────────────
  List<Widget> _healthTab(BuildContext c, WhView v, WhNav nav) {
    final age = v.age;
    final pace = v.pace;
    final on = pace == null ? null : ((pace + 1) / 4 * 39).round().clamp(0, 39);
    return [
      Pressable(
        onTap: () => nav.go('healthspan'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: S.x2),
          child: WcOrb(
            size: 210,
            big: age == null ? '—' : ruDecimal(age),
            caption: 'Возраст организма',
            delta: age == null || v.chrono == null ? (v.chrono == null ? 'укажите возраст в профиле' : 'нужно 3 фактора за 30 дней') : age <= v.chrono! ? 'на ${ruDecimal(v.chrono! - age)} года моложе' : 'на ${ruDecimal(age - v.chrono!)} года старше',
            deltaColor: age == null || v.chrono == null ? W.ink3 : age <= v.chrono! ? W.young : W.neg,
          ),
        ),
      ),
      WhCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WhCardHead('Темп старения', right: pace == null ? null : WhStatus(pace <= 1 ? 'медленнее календаря' : 'быстрее календаря', tone: pace <= 1 ? 2 : 1, icon: pace <= 1 ? 'caret_down' : 'caret_up')),
            Row(
              children: [
                const WhIcon('slow_pace_of_aging', size: 14, color: W.ink3),
                const SizedBox(width: S.x1),
                Text('Медленно', style: FW.sub.copyWith(color: W.ink2)),
                const Spacer(),
                Text(pace == null ? '—' : '${ruDecimal(pace)}x', style: FW.n20.copyWith(color: W.ink)),
                const Spacer(),
                Text('Быстро', style: FW.sub.copyWith(color: W.ink2)),
                const SizedBox(width: S.x1),
                const WhIcon('fast_pace_of_aging', size: 14, color: W.ink3),
              ],
            ),
            const SizedBox(height: S.x2),
            SizedBox(
              height: 36,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 40; i++)
                    Expanded(child: Container(height: i == on ? 36 : 22, margin: const EdgeInsets.only(right: 2), decoration: BoxDecoration(color: i == on ? W.ink4 : W.track, borderRadius: const BorderRadius.all(Radius.circular(1))))),
                ],
              ),
            ),
            const SizedBox(height: S.x1 + 2),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final t in ['-1,0x', '1,0x', '3,0x']) Text(t, style: FW.axisNum.copyWith(color: W.axis))]),
            const SizedBox(height: S.x3 + 2),
            WhPill('Открыть Healthspan', onTap: () => nav.go('healthspan')),
          ],
        ),
      ),
      const WhLivePulse(),
      WhCard(
        onTap: () => nav.go('stress'),
        child: Row(
          children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: (v.stressNow == null ? W.track : W.stress3(v.stressNow!)).withValues(alpha: .18), borderRadius: WR.rBar), child: Center(child: WhIcon('stress_monitor', size: 18, color: v.stressNow == null ? W.ink3 : W.stress3(v.stressNow!)))),
            const SizedBox(width: S.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Монитор стресса', style: FW.b1.copyWith(color: W.ink)),
                  Text(v.stressNow == null ? 'Нужны записи пульса и движения' : 'Сейчас ${ruDecimal(v.stressNow)} · ${v.stressNow! < 1 ? 'низкий' : v.stressNow! < 2 ? 'умеренный' : 'высокий'}${v.stressMin('all', 'high') != null ? ' · высокого за день ${hmOf(v.stressMin('all', 'high'))}' : ''}', style: FW.hint.copyWith(color: W.ink3)),
                ],
              ),
            ),
            const WhIcon('navigation_forward', size: 12, color: W.ink4),
          ],
        ),
      ),
      WhCard(
        onTap: () => nav.go('health-monitor'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WhCardHead('Монитор здоровья', chevron: true),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in v.monitor)
                  Expanded(
                    child: Column(
                      children: [
                        WhIcon(m.icon, size: 22),
                        const SizedBox(height: S.x1 + 2),
                        Text(m.value == null ? '—' : m.value!.toStringAsFixed(m.key == 'resp' || m.key == 'temp' ? 1 : 0).replaceAll('.', ','), style: FW.n15.copyWith(color: W.ink)),
                        Text(m.key == 'spo2' ? 'SpO₂ %' : m.unit, style: FW.tiny.copyWith(color: W.ink3), textAlign: TextAlign.center),
                        const SizedBox(height: S.x1 + 2),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(color: (m.level == 2 ? W.action : m.level == 1 ? W.neg : W.ink3).withValues(alpha: m.level < 0 ? .08 : .15), borderRadius: WR.rBar),
                          child: Center(child: m.level < 0 ? Text('—', style: FW.tiny.copyWith(color: W.ink3)) : WhIcon(m.level == 2 ? 'checkmark' : 'attention', size: 9, color: m.level == 2 ? W.action : W.neg)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: S.x3),
            Text('${v.monitorInRange} из ${v.monitorMeasured} в вашем диапазоне${v.tempC == null ? ' · температура: нет измерения в °C' : ''}', style: FW.hint.copyWith(color: W.ink3)),
          ],
        ),
      ),
      WhMenu([
        WhMenuItem('Тренды и все показатели', subtitle: 'ВСР, пульс, дыхание, SpO₂, температура', icon: 'trend', onTap: () => nav.go('all-metrics')),
        WhMenuItem('Что изменилось', subtitle: 'ночной обзор находок', icon: 'report', onTap: () => nav.go('what-changed')),
        WhMenuItem('Импорт и резервные копии', subtitle: 'CSV WHOOP, экспорт', icon: 'data', onTap: () => nav.go('extra-data')),
      ]),
    ];
  }
}

class _TopBar extends StatelessWidget {
  final String? title;
  final String dayLabel;
  final bool canForward;
  final VoidCallback? onPrev, onNext, onDate, onBattery;
  final double? battery;
  const _TopBar({this.title, required this.dayLabel, required this.canForward, this.onPrev, this.onNext, this.onDate, this.battery, this.onBattery});
  @override
  Widget build(BuildContext c) => SizedBox(
    height: 44,
    child: Row(
      children: [
        const SizedBox(width: 60),
        Expanded(
          child: title != null
              ? Center(child: Text(title!, style: FW.h4.copyWith(color: W.ink)))
              : Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: S.x1),
                    decoration: BoxDecoration(color: W.card, borderRadius: WR.rPill),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Pressable(onTap: onPrev, semanticLabel: 'Предыдущий день', child: const SizedBox(width: 28, height: 28, child: Center(child: WhIcon('navigation_backward', size: 12, color: W.ink)))),
                        Pressable(onTap: onDate, child: Padding(padding: const EdgeInsets.symmetric(horizontal: S.x2), child: Text(dayLabel.toUpperCase(), style: FW.label.copyWith(color: W.ink)))),
                        Pressable(onTap: onNext, semanticLabel: 'Следующий день', child: SizedBox(width: 28, height: 28, child: Center(child: WhIcon('navigation_forward', size: 12, color: canForward ? W.ink : W.ink3)))),
                      ],
                    ),
                  ),
                  ),
                ),
        ),
        SizedBox(
          width: 60,
          child: Pressable(
            onTap: onBattery,
            semanticLabel: 'Браслет',
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (battery != null) ...[const WhIcon('tiny_charging', size: 10, color: W.action), const SizedBox(width: 2), Text('${battery!.round()}%', style: FW.b2.copyWith(color: W.ink)), const SizedBox(width: S.x1)],
                  const WhIcon('strap', size: 18, color: W.ink),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MiniCard extends StatelessWidget {
  final String title, status, sub;
  final Widget badge;
  final Color statusColor;
  final VoidCallback onTap;
  const _MiniCard({required this.title, required this.badge, required this.status, required this.statusColor, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext c) => WhCard(
    onTap: onTap,
    padding: const EdgeInsets.all(S.x3 + 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(title.toUpperCase(), style: FW.over.copyWith(color: W.ink))), const WhIcon('navigation_forward', size: 11, color: W.ink4)]),
        const SizedBox(height: S.x3 + 2),
        Row(
          children: [
            badge,
            const SizedBox(width: S.x2 + 1),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status.toUpperCase(), style: FW.over.copyWith(color: statusColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(sub, style: FW.tiny.copyWith(color: W.ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ActivityRow extends StatelessWidget {
  final String icon, tag, name, start, end;
  final Color color;
  final VoidCallback onTap;
  const _ActivityRow({required this.icon, required this.tag, required this.name, required this.start, required this.end, required this.color, required this.onTap});
  @override
  Widget build(BuildContext c) => Pressable(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: S.x2),
      padding: const EdgeInsets.fromLTRB(S.x2, S.x2, S.x2 + 2, S.x2),
      decoration: BoxDecoration(color: W.card2, borderRadius: WR.rChip),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 38,
            decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.all(Radius.circular(9))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [WhIcon(icon, size: 15, color: W.ink), const SizedBox(width: 5), Text(tag, style: FW.n15.copyWith(color: W.ink))]),
          ),
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

class _JournalWeek extends StatelessWidget {
  final Set<String> days;
  final DateTime end;
  const _JournalWeek({required this.days, required this.end});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.fromLTRB(S.x1, S.x2, S.x1, S.x3 + 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 6; i >= 0; i--)
          Builder(
            builder: (_) {
              final d = DateTime(end.year, end.month, end.day - i);
              final on = days.contains(dayLabelOf(d));
              return Column(
                children: [
                  Text(ruDow[d.weekday - 1].toUpperCase(), style: FW.tiny.copyWith(color: W.ink2, fontWeight: FontWeight.w700, letterSpacing: .9)),
                  const SizedBox(height: S.x2),
                  Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? W.action : W.card3), child: on ? const Center(child: WhIcon('checkmark', size: 11, color: W.onLight)) : null),
                ],
              );
            },
          ),
      ],
    ),
  );
}

/// The live pulse card: value, last readings as an area, zone bar. Owns the
/// realtime stream only while its tab is visible — `TickerMode` (set by
/// AppShell per tab) flips the retain/release, so a hidden Health tab does not
/// keep the band streaming.
class WhLivePulse extends StatefulWidget {
  final double? zone1Bpm;
  const WhLivePulse({super.key, this.zone1Bpm});
  @override
  State<WhLivePulse> createState() => _WhLivePulseState();
}

class _WhLivePulseState extends State<WhLivePulse> {
  AppState? _owner;
  bool _held = false;

  AppState? _app(BuildContext c) {
    try {
      return c.read<AppState>();
    } on ProviderNotFoundException {
      return null; // fixture tests and the gallery have no AppState
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    final app = _app(context);
    if (app == null) return;
    if (visible && !_held) {
      _owner = app..retainLiveHrView();
      _held = true;
    } else if (!visible && _held) {
      _owner?.releaseLiveHrView();
      _held = false;
    }
  }

  @override
  void dispose() {
    if (_held) _owner?.releaseLiveHrView();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final has = _app(c) != null;
    final hr = has ? c.select<AppState, int?>((a) => a.liveHr) : null;
    if (has) c.select<AppState, int>((a) => a.liveHrTraceRev);
    final trace = has ? c.read<AppState>().liveHrTrace() : const <int>[];
    final vals = <double?>[for (final v in trace) v.toDouble()];
    final zone = hr == null || widget.zone1Bpm == null ? 0 : hr >= widget.zone1Bpm! ? 1 : 0;
    return WhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text('ПУЛЬС', style: FW.label.copyWith(color: W.ink))), Text(hr == null ? 'нет потока' : 'сейчас · браслет подключён', style: FW.hint.copyWith(color: W.ink3))]),
          const SizedBox(height: S.x2),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(hr == null ? '—' : '$hr', style: FW.n44.copyWith(color: W.ink)), const SizedBox(width: S.x1), Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('уд/мин', style: FW.hint.copyWith(color: W.ink3)))]),
          const SizedBox(height: S.x1),
          if (vals.length >= 2)
            WcBox(WcHrAreaPainter(vals: vals, color: W.liveHr, yTicks: const [40, 80, 120, 160], startLabel: '−${vals.length} изм.', endLabel: 'сейчас', strokeWidth: 1.4), height: 104)
          else
            Padding(padding: const EdgeInsets.symmetric(vertical: S.x3), child: Text(hr == null ? 'Живой пульс появится, когда браслет на руке и подключён. Ночной пульс покоя считается отдельно.' : 'Собираю первые показания…', style: FW.hint.copyWith(color: W.ink3))),
          const SizedBox(height: S.x2),
          WcZoneBar(zone),
          const SizedBox(height: S.x2),
          Text(hr == null ? 'Зоны считаются по резерву пульса: 50/60/70/80/90 % между покоем и максимумом' : zone == 0 ? 'Покой · ниже зоны 1${widget.zone1Bpm == null ? '' : ' (зона 1 от ${widget.zone1Bpm!.round()} уд/мин)'}' : 'Зона 1 и выше', style: FW.hint.copyWith(color: W.ink3)),
        ],
      ),
    );
  }
}

/// The Healthspan orb: particle-dotted green disc with the age inside.
class WcOrb extends StatelessWidget {
  final double size;
  final String big, caption, delta;
  final Color deltaColor;
  const WcOrb({super.key, this.size = 300, required this.big, required this.caption, required this.delta, this.deltaColor = W.young});
  @override
  Widget build(BuildContext c) => Center(
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OrbPainter(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(big, style: (size >= 260 ? FW.n52 : FW.n44).copyWith(color: W.ink)),
              const SizedBox(height: S.x2),
              Text(caption.toUpperCase(), style: FW.label.copyWith(color: W.awake), textAlign: TextAlign.center),
              const SizedBox(height: S.x1 + 2),
              Text(delta, style: FW.sub.copyWith(color: deltaColor), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OrbPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final center = Offset(r, r);
    c.drawCircle(center, r, Paint()..shader = RadialGradient(colors: [W.bg, W.young.withValues(alpha: .10), W.young.withValues(alpha: .38), W.young.withValues(alpha: .08)], stops: const [0, .42, .8, 1]).createShader(Rect.fromCircle(center: center, radius: r)));
    final dot = Paint()..color = W.young.withValues(alpha: .85);
    final dot2 = Paint()..color = W.ink.withValues(alpha: .6);
    var seed = 17;
    double rnd() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    }

    for (var i = 0; i < 520; i++) {
      final a = rnd() * 6.283, rr = (0.5 + rnd() * 0.48) * r;
      final p = Offset(r + rr * _cos(a), r + rr * _sin(a));
      final k = (rr / r - 0.5) / 0.48;
      c.drawCircle(p, i % 7 == 0 ? 1.3 : 0.9, i % 5 == 0 ? dot2 : (dot..color = W.young.withValues(alpha: .25 + .7 * k)));
    }
  }

  @override
  bool shouldRepaint(_OrbPainter o) => false;
}

double _cos(double a) => _sin(a + 1.5707963);
double _sin(double a) {
  // Bhaskara-free: plain Taylor is fine for ornament dots.
  var x = a % 6.283185307;
  if (x > 3.14159265) x -= 6.283185307;
  final x2 = x * x;
  return x * (1 - x2 / 6 * (1 - x2 / 20 * (1 - x2 / 42 * (1 - x2 / 72))));
}

String activityIconOf(String? type) {
  final t = (type ?? '').toLowerCase();
  if (t.contains('run')) return 'running';
  if (t.contains('cycl') || t.contains('bike') || t.contains('вело')) return 'cycling';
  if (t.contains('walk') || t.contains('hik') || t.contains('ходь')) return 'steps';
  if (t.contains('weight') || t.contains('lift') || t.contains('strength') || t.contains('силов')) return 'weightlifting';
  if (t.contains('sleep') || t.contains('nap')) return 'sleep';
  if (t.contains('breath') || t.contains('medit')) return 'stress_monitor_low';
  return 'strain';
}
