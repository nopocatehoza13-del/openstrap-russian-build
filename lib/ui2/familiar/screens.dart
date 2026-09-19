import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/day_label.dart';
import '../../state/app_state.dart';
import '../../state/prefs.dart';
import '../activity/day_strain.dart';
import '../grammar.dart';
import '../profile/alarm.dart';
import '../profile/data.dart';
import '../profile/devices.dart';
import '../profile/profile.dart';
import '../profile/settings.dart';
import '../revision.dart';
import '../screens/health_screen.dart';
import '../screens/home_screen.dart';
import '../screens/log_workout.dart';
import '../screens/metric_detail.dart';
import '../screens/nutrition_screen.dart';
import '../screens/readiness_detail.dart';
import '../screens/sleep_detail.dart';
import '../screens/wellness_screen.dart';
import '../screens/workout_screen.dart';
import '../theme.dart';
import 'data.dart';
import 'widgets.dart';

/// Familiar presentation over the real Flutter repository, not a WebView.
class FamiliarDashboard extends StatefulWidget {
  final bool health;
  final FamiliarData? data;
  const FamiliarDashboard({super.key, this.health = false, this.data});
  @override
  State<FamiliarDashboard> createState() => _FamiliarDashboardState();
}

class _FamiliarDashboardState extends State<FamiliarDashboard>
    with RevisionReload {
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
    setState(() {
      loading = true;
      error = null;
    });
    FamiliarData.load(repo, date)
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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
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
    final p = P.of(c), d = data ?? FamiliarData(day: dayLabelOf(date));
    final h = d.home;
    final now = dayLabelOf(date) == todayLabel();
    final sleepPct =
        h.sleepNeedMin.value != null &&
            h.sleepNeedMin.value! > 0 &&
            h.sleepMin.value != null
        ? h.sleepMin.value! / h.sleepNeedMin.value! * 100
        : null;
    return RefreshIndicator(
      onRefresh: () async {
        final app = c.read<AppState>();
        try {
          await app.syncNow();
        } finally {
          if (mounted) reload();
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, S.x10),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'dirty bastard',
                  style: F.t2.copyWith(color: p.ink),
                ),
              ),
              Pressable(
                semanticLabel: 'Браслет и подключение',
                onTap: () => open(const MyDevices()),
                child: Icon(Icons.watch_outlined, color: p.ink2),
              ),
              Pressable(
                semanticLabel: 'Профиль',
                onTap: () => open(const ProfileHome()),
                child: Icon(Icons.account_circle_outlined, color: p.ink2),
              ),
            ],
          ),
          const SizedBox(height: S.x3),
          if (widget.health)
            Text('ЗДОРОВЬЕ', style: F.over.copyWith(color: p.ink2))
          else
            Row(
              children: [
                Pressable(
                  semanticLabel: 'Предыдущий день',
                  onTap: loading ? null : () => changeDay(-1),
                  child: Icon(Icons.chevron_left, color: p.ink2),
                ),
                Expanded(
                  child: Pressable(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: c,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null && mounted) {
                        setState(() {
                          date = picked;
                          data = null;
                        });
                        reload();
                      }
                    },
                    child: Text(
                      now ? 'СЕГОДНЯ' : dayLabelOf(date),
                      textAlign: TextAlign.center,
                      style: F.over.copyWith(color: p.ink),
                    ),
                  ),
                ),
                Pressable(
                  semanticLabel: 'Следующий день',
                  onTap: now || loading ? null : () => changeDay(1),
                  child: Icon(
                    Icons.chevron_right,
                    color: now ? p.ink3 : p.ink2,
                  ),
                ),
              ],
            ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            FamiliarPanel(
              child: Column(
                children: [
                  Text(error!, style: F.body),
                  FamiliarButton('Повторить', Icons.refresh, onTap: reload),
                ],
              ),
            ),
          const SizedBox(height: S.x3),
          if (!widget.health) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FamiliarRing(
                    label: 'СОН',
                    value: sleepPct == null
                        ? '—'
                        : '${number(sleepPct.clamp(0, 100))}%',
                    subtitle: hours(h.sleepMin.value),
                    fraction: sleepPct == null ? null : sleepPct / 100,
                    color: C.purple,
                    onTap: () => open(SleepDetail(day: d.day)),
                  ),
                ),
                const SizedBox(width: S.x3),
                Expanded(
                  child: FamiliarRing(
                    label: 'ВОССТАНОВЛ.',
                    value: h.readiness.value == null
                        ? '—'
                        : '${number(h.readiness.value)}%',
                    subtitle: 'из 100',
                    fraction: h.readiness.value?.toDouble() == null
                        ? null
                        : h.readiness.value!.toDouble() / 100,
                    color: recoveryColor(h.readiness.value),
                    onTap: () => open(
                      now
                          ? const ReadinessDetail()
                          : ReadinessDetail(
                              dayLabel: d.day,
                              data: ReadinessData(
                                readiness: h.readiness,
                                series: datedSeries(d.recovery, date, 90),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: S.x3),
                Expanded(
                  child: FamiliarRing(
                    label: 'НАГРУЗКА',
                    value: number(h.strain.value, 1),
                    subtitle: 'из 21',
                    fraction: h.strain.value?.toDouble() == null
                        ? null
                        : h.strain.value!.toDouble() / 21,
                    color: C.blue,
                    onTap: () => open(DayStrainDetail(day: d.day)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: S.x5),
            if (sleepPct == null)
              Text(
                'Процент сна появится, когда будет рассчитана ваша потребность во сне.',
                style: F.cap.copyWith(color: p.ink3),
              ),
            if (now) ...[
              const SizedBox(height: S.x3),
              FamiliarHealthMonitor(
                data: d,
                onTap: () => open(FamiliarMonitorDetail(data: d)),
              ),
              FamiliarStressCard(
                data: d,
                onTap: () => open(FamiliarStressDetail(data: d)),
              ),
            ],
            FamiliarPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FamiliarHeading(
                    'АКТИВНОСТИ ЗА ДЕНЬ',
                    onTap: () => open(const FamiliarActivities()),
                  ),
                  if (d.sleep['duration_min'] is num)
                    _activityRow(
                      c,
                      Icons.bedtime_outlined,
                      'Сон',
                      '${clockTs(d.sleep['onset_ts'])} — ${clockTs(d.sleep['wake_ts'])}',
                      hours(d.sleep['duration_min'] as num?),
                      () => open(SleepDetail(day: d.day)),
                      C.purple,
                    ),
                  for (final row in d.activities)
                    _activityRow(
                      c,
                      Icons.directions_run,
                      familiarActivityName(c, row['type']?.toString()),
                      '${clockTs(row['start_ts'])} · ${hours(row['duration_min'] as num?)}',
                      number(row['strain'] as num?, 1),
                      () => openFamiliarWorkout(c, row),
                      C.blue,
                    ),
                  if (d.activities.isEmpty && d.sleep['duration_min'] is! num)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: S.x4),
                      child: Text(
                        'На этот день записей нет. Синхронизируйте браслет или добавьте активность.',
                        style: F.cap.copyWith(color: p.ink2),
                      ),
                    ),
                  const SizedBox(height: S.x3),
                  Row(
                    children: [
                      Expanded(
                        child: FamiliarButton(
                          'Добавить',
                          Icons.add,
                          onTap: () => open(const LogWorkout()),
                        ),
                      ),
                      const SizedBox(width: S.x2),
                      Expanded(
                        child: FamiliarButton(
                          'Начать',
                          Icons.play_arrow,
                          filled: true,
                          onTap: () => openFamiliarActivityPicker(c).then((_) {
                            if (mounted) reload();
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            FamiliarStrainRecovery(data: d, end: date),
            if (now)
              FamiliarPanel(
                onTap: () => open(FamiliarSleepPlanner(data: d)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FamiliarHeading(
                      'ПЛАН СНА',
                      onTap: () => open(FamiliarSleepPlanner(data: d)),
                    ),
                    Text(
                      hours(h.sleepNeedMin.value),
                      style: F.n34.copyWith(color: p.ink),
                    ),
                    const SizedBox(height: S.x2),
                    Text(
                      h.sleepNeedMin.value == null
                          ? 'Потребность ещё не рассчитана. Можно заранее выбрать время подъёма.'
                          : 'Ваша рассчитанная потребность · настройте время подъёма',
                      style: F.cap.copyWith(color: p.ink2),
                    ),
                  ],
                ),
              ),
            FamiliarPanel(
              child: Column(
                children: [
                  _metricRow(
                    c,
                    'Шаги',
                    number(h.steps.value),
                    () => open(const MetricDetail('steps')),
                  ),
                  _metricRow(
                    c,
                    'Энергия за день',
                    h.caloriesTotal.value == null
                        ? '—'
                        : '${number(h.caloriesTotal.value)} ккал',
                    () => open(const MetricDetail('calories')),
                  ),
                ],
              ),
            ),
            FamiliarButton(
              'Все показатели и тенденции',
              Icons.insights,
              onTap: () => open(const FamiliarAllHealth()),
            ),
          ] else ...[
            FamiliarAgeCard(
              data: d,
              onTap: () => open(FamiliarAgeDetail(data: d)),
            ),
            FamiliarHealthMonitor(
              data: d,
              onTap: () => open(FamiliarMonitorDetail(data: d)),
            ),
            FamiliarStressCard(
              data: d,
              onTap: () => open(FamiliarStressDetail(data: d)),
            ),
            FamiliarPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FamiliarHeading('ИСТОРИЯ И ПОКАЗАТЕЛИ'),
                  _metricRow(
                    c,
                    'Тенденции, витальные показатели и анализы',
                    '',
                    () => open(const FamiliarAllHealth()),
                  ),
                  _metricRow(
                    c,
                    'Импорт и резервные копии',
                    '',
                    () => open(const DataScreen()),
                  ),
                ],
              ),
            ),
            Text(
              'Расчёты OpenStrap отличаются от WHOOP. ЭКГ и давление этой сборкой не рассчитываются.',
              style: F.cap.copyWith(color: p.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

Color recoveryColor(num? v) => readinessBand(v).color;
Widget _metricRow(
  BuildContext c,
  String label,
  String value,
  VoidCallback onTap,
) => Pressable(
  onTap: onTap,
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: S.x3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: F.body.copyWith(color: P.of(c).ink)),
        ),
        Text(value, style: F.head.copyWith(color: P.of(c).ink)),
        const SizedBox(width: S.x2),
        Icon(Icons.chevron_right, size: 18, color: P.of(c).ink3),
      ],
    ),
  ),
);
Widget _activityRow(
  BuildContext c,
  IconData icon,
  String name,
  String sub,
  String value,
  VoidCallback tap,
  Color color,
) => Pressable(
  onTap: tap,
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: S.x3),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(S.x2),
          decoration: BoxDecoration(
            color: P.of(c).wash(color),
            borderRadius: R.rSm,
          ),
          child: Icon(icon, color: P.of(c).on(color), size: 23),
        ),
        const SizedBox(width: S.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: F.head.copyWith(color: P.of(c).ink)),
              Text(sub, style: F.cap.copyWith(color: P.of(c).ink2)),
            ],
          ),
        ),
        Text(value, style: F.cap.copyWith(color: P.of(c).ink)),
        Icon(Icons.chevron_right, size: 18, color: P.of(c).ink3),
      ],
    ),
  ),
);

class FamiliarHealthMonitor extends StatelessWidget {
  final FamiliarData data;
  final VoidCallback onTap;
  const FamiliarHealthMonitor({
    super.key,
    required this.data,
    required this.onTap,
  });
  @override
  Widget build(BuildContext c) {
    final h = data.health, p = P.of(c);
    // Only explicitly imported absolute measurements may be labelled °C or %.
    // Relative optical and thermal signals remain absent in this compact card.
    final values = [
      number(h.resp.value, 1),
      number(data.oxygenPercent),
      number(data.home.rhr.value),
      number(h.hrv.value),
      number(data.temperature, 1),
    ];
    const labels = ['Дыхание', 'SpO₂', 'Покой', 'ВСР', 'Темп.'];
    final units = ['/мин', '%', 'уд/мин', 'мс', data.temperatureUnit];
    const icons = [
      Icons.air,
      Icons.water_drop_outlined,
      Icons.favorite_border,
      Icons.monitor_heart_outlined,
      Icons.thermostat,
    ];
    return FamiliarPanel(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FamiliarHeading('МОНИТОР ЗДОРОВЬЯ', onTap: onTap),
          const SizedBox(height: S.x2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Column(
                    children: [
                      Icon(icons[i], size: 18, color: p.ink2),
                      const SizedBox(height: S.x2),
                      Text(labels[i], style: F.over.copyWith(color: p.ink2)),
                      const SizedBox(height: S.x2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          values[i],
                          style: F.n24.copyWith(color: p.ink),
                        ),
                      ),
                      Text(units[i], style: F.over.copyWith(color: p.ink3)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: S.x3),
          Text(
            'Ночь: ${data.nightDay.isEmpty ? 'нет данных' : data.nightDay} · подробнее →',
            style: F.cap.copyWith(color: p.ink2),
          ),
          Text(
            data.temperatureC == null
                ? '— нет измерения в нужных единицах'
                : 'Температура и SpO₂ из экспорта WHOOP',
            style: F.over.copyWith(color: p.ink3),
          ),
        ],
      ),
    );
  }
}

class FamiliarMonitorDetail extends StatelessWidget {
  final FamiliarData data;
  const FamiliarMonitorDetail({super.key, required this.data});
  @override
  Widget build(BuildContext c) => FamiliarPage(
    'Монитор здоровья',
    children: [
      Text(
        'Ночные измерения. Числа показываются в исходной шкале OpenStrap, без подмены фирменными оценками WHOOP.',
        style: F.body,
      ),
      const SizedBox(height: S.x4),
      FamiliarPanel(
        child: Column(
          children: [
            _metricRow(
              c,
              'Частота дыхания',
              '${number(data.health.resp.value, 1)} /мин',
              () => go(c, const MetricDetail('resp_rate')),
            ),
            _metricRow(
              c,
              'Пульс в покое',
              '${number(data.home.rhr.value)} уд/мин',
              () => go(c, const MetricDetail('resting_hr')),
            ),
            _metricRow(
              c,
              'Вариабельность ритма',
              '${number(data.health.hrv.value)} мс',
              () => go(c, const MetricDetail('hrv')),
            ),
            _metricRow(
              c,
              'Температура кожи',
              '${number(data.temperature, 1)} ${data.temperatureUnit}',
              () => go(
                c,
                FamiliarPage(
                  'Температура кожи',
                  children: [
                    Text('${number(data.temperatureC, 1)} °C', style: F.n48),
                    const SizedBox(height: S.x4),
                    Text(
                      data.temperatureC == null
                          ? 'Измерения в °C пока нет. OpenStrap получает относительный тепловой сигнал; без калибровки его нельзя перевести в градусы. При импорте CSV WHOOP температура в °C появится здесь.'
                          : 'Дата: ${data.nightDay}. Температура в °C из CSV WHOOP. Это температура кожи, не внутренняя температура тела.',
                      style: F.body,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      FamiliarPanel(
        child: Text(
          data.oxygenPercent == null
              ? 'SpO₂ отсутствует. Относительный оптический индекс не превращается в процент насыщения крови кислородом.'
              : 'SpO₂: ${number(data.oxygenPercent)}%. Дата: ${data.nightDay}. Значение из CSV WHOOP, не новое измерение OpenStrap.',
          style: F.body,
        ),
      ),
    ],
  );
}

class FamiliarStrainRecovery extends StatefulWidget {
  final FamiliarData data;
  final DateTime end;
  const FamiliarStrainRecovery({
    super.key,
    required this.data,
    required this.end,
  });
  @override
  State<FamiliarStrainRecovery> createState() => _FamiliarStrainRecoveryState();
}

class _FamiliarStrainRecoveryState extends State<FamiliarStrainRecovery> {
  int selected = 6;
  @override
  Widget build(BuildContext c) {
    final a = datedSeries(widget.data.strain, widget.end, 7),
        b = datedSeries(widget.data.recovery, widget.end, 7),
        p = P.of(c);
    return FamiliarPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FamiliarHeading('НАГРУЗКА И ВОССТАНОВЛЕНИЕ'),
          const SizedBox(height: S.x3),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${number(a[selected], 1)} / 21',
                  style: F.t2.copyWith(color: p.on(C.blue)),
                ),
              ),
              Text(
                '${number(b[selected])} / 100',
                style: F.t2.copyWith(color: p.on(C.green)),
              ),
            ],
          ),
          FamiliarChart(first: a, second: b),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Pressable(
                    semanticLabel: 'Выбрать день ${i + 1}',
                    onTap: () => setState(() => selected = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: S.x2),
                      decoration: BoxDecoration(
                        color: i == selected ? p.card2 : null,
                        borderRadius: R.rSm,
                      ),
                      child: Text(
                        '${DateTime(widget.end.year, widget.end.month, widget.end.day - 6 + i).day}',
                        textAlign: TextAlign.center,
                        style: F.cap.copyWith(color: p.ink),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Text(
            'Синяя: нагрузка 0–21 · зелёная: восстановление 0–100. Разрыв — нет данных.',
            style: F.over.copyWith(color: p.ink3),
          ),
        ],
      ),
    );
  }
}

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
    final p = P.of(c), need = widget.data.home.sleepNeedMin.value;
    final planned = need == null ? null : (need * goal / 100).round();
    final bed = planned == null || wake < 0 ? null : (wake - planned) % 1440;
    return FamiliarPage(
      'План сна',
      children: [
        Text('СЕГОДНЯ НОЧЬЮ', style: F.over.copyWith(color: p.ink2)),
        const SizedBox(height: S.x4),
        FamiliarPanel(
          child: Column(
            children: [
              Text('ВРЕМЯ ОТБОЯ', style: F.over.copyWith(color: p.ink2)),
              const SizedBox(height: S.x3),
              Text(clockMinutes(bed), style: F.n48.copyWith(color: p.ink)),
              const SizedBox(height: S.x3),
              Text(
                bed == null
                    ? 'Выберите подъём. Расчёт отбоя появится после определения потребности во сне.'
                    : 'Расчётное время засыпания, чтобы получить ${hours(planned)} сна.',
                style: F.cap.copyWith(color: p.ink2),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        FamiliarPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FamiliarHeading('ВАША ЦЕЛЬ'),
              const SizedBox(height: S.x3),
              Wrap(
                spacing: S.x2,
                runSpacing: S.x2,
                children: [
                  for (final n in [70, 85, 100])
                    ChoiceChip(
                      label: Text('$n%'),
                      selected: goal == n,
                      onSelected: (_) {
                        setState(() => goal = n);
                        Prefs.setInt('familiar.sleepGoal', n);
                      },
                    ),
                ],
              ),
              const SizedBox(height: S.x3),
              Text(
                'Это выбранная вами доля потребности, а не рекомендация сокращать сон. 100% — полная рассчитанная потребность.',
                style: F.cap.copyWith(color: p.ink2),
              ),
              _metricRow(
                c,
                'Время подъёма',
                clockMinutes(wake < 0 ? null : wake),
                () async {
                  final t = await showTimePicker(
                    context: c,
                    initialTime: TimeOfDay(
                      hour: wake < 0 ? 7 : wake ~/ 60,
                      minute: wake < 0 ? 0 : wake % 60,
                    ),
                  );
                  if (t != null && mounted) {
                    setState(() => wake = t.hour * 60 + t.minute);
                    Prefs.setInt('familiar.wakeMinute', wake);
                  }
                },
              ),
              _metricRow(
                c,
                'Потребность во сне',
                hours(need),
                () => go(c, const SleepDetail()),
              ),
            ],
          ),
        ),
        FamiliarButton(
          'Будильник браслета',
          Icons.alarm,
          onTap: () => go(c, const AlarmScreen()),
        ),
        const SizedBox(height: S.x3),
        Text(
          'План сохраняется на телефоне. Время подъёма само по себе НЕ включает будильник: его нужно отдельно настроить и отправить на браслет.',
          style: F.cap.copyWith(color: p.ink2),
        ),
        const SizedBox(height: S.x3),
        FamiliarButton(
          'Напоминания о сне',
          Icons.notifications_outlined,
          onTap: () => go(c, const NotificationSettings()),
        ),
      ],
    );
  }
}

class FamiliarAgeCard extends StatelessWidget {
  final FamiliarData data;
  final VoidCallback onTap;
  const FamiliarAgeCard({super.key, required this.data, required this.onTap});
  @override
  Widget build(BuildContext c) => FamiliarPanel(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FamiliarHeading('ВОЗРАСТ ОРГАНИЗМА · ЭКСПЕРИМЕНТ', onTap: onTap),
        const SizedBox(height: S.x3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              number(data.age?.estimated, 1),
              style: F.n48.copyWith(color: P.of(c).ink),
            ),
            const SizedBox(width: S.x2),
            Text('лет', style: F.body.copyWith(color: P.of(c).ink2)),
          ],
        ),
        const SizedBox(height: S.x3),
        Text(
          data.age == null
              ? 'Нужны возраст в профиле и хотя бы 3 измеряемых показателя за последние 7 дней.'
              : '${data.age!.from} — ${data.age!.through} · ${data.age!.contributions.length} факторов',
          style: F.cap.copyWith(color: P.of(c).ink2),
        ),
        const SizedBox(height: S.x2),
        Text(
          'Не WHOOP Age и не медицинский показатель.',
          style: F.over.copyWith(color: P.of(c).ink3),
        ),
      ],
    ),
  );
}

class FamiliarAgeDetail extends StatelessWidget {
  final FamiliarData data;
  const FamiliarAgeDetail({super.key, required this.data});
  @override
  Widget build(BuildContext c) {
    final a = data.age;
    const names = {
      'rhr': 'Пульс в покое',
      'hrv': 'Вариабельность ритма',
      'sleep': 'Продолжительность сна',
      'consistency': 'Стабильность длительности сна',
      'steps': 'Шаги',
    };
    return FamiliarPage(
      'Возраст организма',
      children: [
        Text(
          number(a?.estimated, 1),
          style: F.n48.copyWith(color: P.of(c).ink),
        ),
        const SizedBox(height: S.x3),
        Text(
          a == null
              ? 'Пока недостаточно данных для оценки. Укажите возраст 20–90 лет и импортируйте или запишите свежие измерения.'
              : 'Календарный возраст: ${number(a.chronological)}. Период: ${a.from} — ${a.through}.',
          style: F.body,
        ),
        const SizedBox(height: S.x4),
        FamiliarPanel(
          child: Column(
            children: [
              for (final e in (a?.contributions ?? <String, double>{}).entries)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(names[e.key]!, style: F.body),
                  trailing: Text(
                    '${e.value >= 0 ? '+' : ''}${number(e.value, 1)} г.',
                    style: F.cap.copyWith(color: P.of(c).ink),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: S.x4),
                      child: Text(
                        'Дней с данными: ${a!.samples[e.key]}. Это вклад фактора в экспериментальную формулу, не доказанные «годы жизни».',
                        style: F.cap,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Text(
          'Независимая реализация описанной в NOOP пятифакторной модели. Требуются минимум три разные измеряемые величины, каждая минимум за три дня из последних семи. Вариабельность продолжительности сна не считается отдельным измерением. Нет данных — нет числа. Импорт старой истории не заменяет свежую неделю.',
          style: F.body,
        ),
        const SizedBox(height: S.x3),
        Text(
          'Оценка не клинически валидирована. Шаги и ВСР могут отсутствовать; состав факторов влияет на результат. Не сравнивайте число с WHOOP Age. Темп старения этой моделью не рассчитывается.',
          style: F.cap.copyWith(color: P.of(c).ink2),
        ),
        const SizedBox(height: S.x4),
        FamiliarButton(
          'Изменить возраст в профиле',
          Icons.person_outline,
          onTap: () => go(c, const EditProfile()),
        ),
        const SizedBox(height: S.x2),
        FamiliarButton(
          'Импортировать данные WHOOP',
          Icons.file_download_outlined,
          onTap: () => go(c, const DataScreen()),
        ),
      ],
    );
  }
}

Map<String, dynamic> _stressSummary(FamiliarData data, String scope) =>
    ((data.intradayStress['summaries'] as Map?)?[scope] as Map?)
        ?.cast<String, dynamic>() ??
    const {};

String _stressMinutes(Object? seconds) =>
    seconds is num ? '${number(seconds / 60)} мин' : '—';

class FamiliarStressCard extends StatelessWidget {
  final FamiliarData data;
  final VoidCallback onTap;
  const FamiliarStressCard({
    super.key,
    required this.data,
    required this.onTap,
  });
  @override
  Widget build(BuildContext c) {
    final summary = _stressSummary(data, 'all');
    return FamiliarPanel(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FamiliarHeading('МОНИТОР СТРЕССА', onTap: onTap),
          Text(
            '${number(summary['mean'] as num?, 1)} / 3',
            style: F.n34.copyWith(color: P.of(c).ink),
          ),
          const SizedBox(height: S.x2),
          Text(
            'Среднее за выбранный день · экспериментальная оценка',
            style: F.cap.copyWith(color: P.of(c).ink2),
          ),
          if (summary['mean'] != null)
            Text(
              'Измерений: ${_stressMinutes(summary['covered_sec'])}',
              style: F.cap.copyWith(color: P.of(c).ink2),
            ),
        ],
      ),
    );
  }
}

class FamiliarStressDetail extends StatefulWidget {
  final FamiliarData data;
  const FamiliarStressDetail({super.key, required this.data});
  @override
  State<FamiliarStressDetail> createState() => _FamiliarStressDetailState();
}

class _FamiliarStressDetailState extends State<FamiliarStressDetail> {
  int scope = 0;
  int? selected;
  @override
  Widget build(BuildContext c) {
    final d = widget.data, p = P.of(c), model = d.intradayStress;
    final key = ['all', 'rest', 'sleep'][scope],
        summary = _stressSummary(d, key);
    final points = [
      for (final v in model['points'] as List? ?? const [])
        if (v is Map) v,
    ];
    final values = [for (final v in points) (v[key] as num?)?.toDouble()];
    final chosen = selected != null && selected! < points.length
        ? points[selected!]
        : null;
    final mean = summary['mean'] as num?;
    final status = model['status'];
    return FamiliarPage(
      'Монитор стресса',
      children: [
        Text(d.day, style: F.over.copyWith(color: p.ink2)),
        const SizedBox(height: S.x3),
        Text(
          '${number(mean, 1)} / 3',
          key: const ValueKey('stress-summary'),
          style: F.n48.copyWith(color: p.ink),
        ),
        Text(
          'СРЕДНЕЕ ПО ИЗМЕРЕННЫМ УЧАСТКАМ',
          style: F.over.copyWith(color: p.ink2),
        ),
        const SizedBox(height: S.x4),
        Wrap(
          spacing: S.x2,
          runSpacing: S.x2,
          children: [
            for (var i = 0; i < 3; i++)
              ChoiceChip(
                label: Text(['Весь день', 'Без активности', 'Сон'][i]),
                selected: scope == i,
                onSelected: (_) => setState(() {
                  scope = i;
                  selected = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: S.x4),
        FamiliarPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ДИНАМИКА ЗА ДЕНЬ · 0–3',
                style: F.over.copyWith(color: p.ink2),
              ),
              const SizedBox(height: S.x2),
              Scrubber(
                key: const ValueKey('stress-chart'),
                value: selected == null
                    ? null
                    : selected! / (points.length > 1 ? points.length - 1 : 1),
                step: 1 / (points.length > 1 ? points.length - 1 : 1),
                label: 'График стресса, шкала от 0 до 3',
                onChanged: (v) {
                  if (points.isNotEmpty) {
                    setState(
                      () => selected = (v * (points.length - 1)).round().clamp(
                        0,
                        points.length - 1,
                      ),
                    );
                  }
                },
                describe: (v) {
                  if (points.isEmpty) return 'Нет данных';
                  final point =
                      points[(v * (points.length - 1)).round().clamp(
                        0,
                        points.length - 1,
                      )];
                  return '${clockTs(point['t'])}: ${number(point[key] as num?, 1)}';
                },
                child: FamiliarChart(
                  first: values,
                  maxFirst: 3,
                  color: C.yellow,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    clockTs(model['start']),
                    style: F.cap.copyWith(color: p.ink2),
                  ),
                  Expanded(
                    child: Text(
                      'Местное время',
                      textAlign: TextAlign.center,
                      style: F.cap.copyWith(color: p.ink2),
                    ),
                  ),
                  Text(
                    clockTs(model['end']),
                    style: F.cap.copyWith(color: p.ink2),
                  ),
                ],
              ),
              const SizedBox(height: S.x3),
              Text(
                chosen == null
                    ? 'Нажми на график, чтобы посмотреть интервал'
                    : '${clockTs(chosen['t'])}–${clockTs(chosen['end'])}: ${number(chosen[key] as num?, 1)}',
                key: const ValueKey('stress-selected'),
                style: F.body,
              ),
              const SizedBox(height: S.x2),
              Text(
                'Покрытие: ${mean == null ? '—' : _stressMinutes(summary['covered_sec'])} реальных измерений. Пробелы не заполняются.',
                style: F.cap.copyWith(color: p.ink2),
              ),
            ],
          ),
        ),
        const SizedBox(height: S.x4),
        FamiliarPanel(
          child: Column(
            children: [
              _stressRow(c, 'Низкий · < 1', summary['low_sec']),
              _stressRow(c, 'Умеренный · 1–2', summary['medium_sec']),
              _stressRow(c, 'Высокий · ≥ 2', summary['high_sec']),
            ],
          ),
        ),
        const SizedBox(height: S.x4),
        if (mean == null)
          Text(
            status == 'need_quiet_reference'
                ? 'Пока мало спокойных участков: ${model['reference_minutes'] ?? 0} из 60 минут, ${model['reference_hours'] ?? 0} из 3 разных часов. Носи браслет и синхронизируй записи.'
                : status == 'ready'
                ? 'Для выбранного раздела нет подходящих измерений. Нулевой стресс не подставляется.'
                : 'Нужны записи пульса и движения с браслета. Синхронизируй его; для сохранённых сырых записей доступен повторный анализ в управлении данными. Сводного CSV WHOOP недостаточно.',
            style: F.body,
          ),
        const SizedBox(height: S.x3),
        Text(
          'Собственная экспериментальная шкала, не формула WHOOP. Пульс сравнивается со спокойными участками этого же дня; по мере синхронизации оценка может меняться. Это не измерение эмоций и не диагноз.',
          style: F.cap.copyWith(color: p.ink2),
        ),
        const SizedBox(height: S.x3),
        Text(
          'Весь день включает физическую нагрузку. Без активности исключает отмеченные тренировки, заметное движение, известные интервалы сна и повышенный пульс сразу после нагрузки. Сон использует интервалы сна OpenStrap, включая дремоту, а не фиксированные часы.',
          style: F.cap.copyWith(color: p.ink2),
        ),
        if (model['reference_bpm'] is num) ...[
          const SizedBox(height: S.x3),
          Text(
            'Опорный пульс дня: ${number(model['reference_bpm'] as num, 1)} уд/мин · график по 5 минут',
            style: F.cap.copyWith(color: p.ink2),
          ),
        ],
        const SizedBox(height: S.x4),
        FamiliarButton(
          'Ночной индекс 0–100 — отдельный показатель',
          Icons.insights,
          onTap: () => go(c, const MetricDetail('stress')),
        ),
      ],
    );
  }

  Widget _stressRow(BuildContext c, String label, Object? seconds) => Padding(
    padding: const EdgeInsets.symmetric(vertical: S.x2),
    child: Row(
      children: [
        Expanded(child: Text(label, style: F.body)),
        Text(
          _stressMinutes(seconds),
          style: F.head.copyWith(color: P.of(c).ink),
        ),
      ],
    ),
  );
}

class FamiliarAllHealth extends StatelessWidget {
  const FamiliarAllHealth({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Все показатели')),
    body: const HealthScreen(),
  );
}

class FamiliarActivities extends StatelessWidget {
  const FamiliarActivities({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Активности')),
    body: const WorkoutScreen(),
  );
}

class FamiliarMore extends StatelessWidget {
  const FamiliarMore({super.key});
  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.all(S.x4),
    children: [
      Text('Ещё', style: F.t1.copyWith(color: P.of(c).ink)),
      const SizedBox(height: S.x2),
      Text(
        'Возможности OpenStrap в одном месте',
        style: F.cap.copyWith(color: P.of(c).ink2),
      ),
      const SizedBox(height: S.x5),
      FamiliarPanel(
        child: Column(
          children: [
            _metricRow(
              c,
              'Тренировки, зоны пульса и история',
              '',
              () => go(c, const FamiliarActivities()),
            ),
            _metricRow(
              c,
              'Питание и дневник еды',
              '',
              () => go(
                c,
                Scaffold(
                  appBar: AppBar(title: const Text('Питание')),
                  body: const NutritionScreen(),
                ),
              ),
            ),
            _metricRow(
              c,
              'Самочувствие, дневник и привычки',
              '',
              () => go(
                c,
                Scaffold(
                  appBar: AppBar(title: const Text('Самочувствие')),
                  body: const WellnessScreen(),
                ),
              ),
            ),
            _metricRow(
              c,
              'Все показатели и анализы',
              '',
              () => go(c, const FamiliarAllHealth()),
            ),
          ],
        ),
      ),
      FamiliarPanel(
        child: Column(
          children: [
            _metricRow(
              c,
              'Импорт WHOOP, экспорт, резервная копия',
              '',
              () => go(c, const DataScreen()),
            ),
            _metricRow(
              c,
              'Браслет и источники данных',
              '',
              () => go(c, const MyDevices()),
            ),
            _metricRow(
              c,
              'Будильник браслета',
              '',
              () => go(c, const AlarmScreen()),
            ),
          ],
        ),
      ),
    ],
  );
}

class FamiliarSettings extends StatelessWidget {
  const FamiliarSettings({super.key});
  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.all(S.x4),
    children: [
      Text('Настройки', style: F.t1.copyWith(color: P.of(c).ink)),
      const SizedBox(height: S.x5),
      FamiliarPanel(
        child: Column(
          children: [
            _metricRow(c, 'Мой профиль', '', () => go(c, const ProfileHome())),
            _metricRow(
              c,
              'Возраст, рост, вес и цели',
              '',
              () => go(c, const EditProfile()),
            ),
            _metricRow(c, 'Мои устройства', '', () => go(c, const MyDevices())),
          ],
        ),
      ),
      FamiliarPanel(
        child: Column(
          children: [
            _metricRow(
              c,
              'Уведомления и напоминания',
              '',
              () => go(c, const NotificationSettings()),
            ),
            _metricRow(
              c,
              'Оформление, язык и единицы',
              '',
              () => go(c, const MoreSettings()),
            ),
            _metricRow(
              c,
              'Данные, импорт и резервные копии',
              '',
              () => go(c, const DataScreen()),
            ),
            _metricRow(c, 'Будильник', '', () => go(c, const AlarmScreen())),
          ],
        ),
      ),
      Text(
        'dirty bastard · личная сборка на основе OpenStrap. Данные хранятся локально. Перед обновлением сохраните резервную копию.',
        style: F.cap.copyWith(color: P.of(c).ink2),
      ),
    ],
  );
}
