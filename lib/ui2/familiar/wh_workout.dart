// Activity detail — WHOOP layout over `getWorkout(id)`: strain, steps, the HR
// trace, HRR zones as cards, then the OpenStrap summary and edit/delete.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../grammar.dart';
import '../screens/home_screen.dart' show repoOf;
import '../screens/workout_screen.dart' show openFamiliarWorkout, familiarActivityName;
import '../theme.dart';
import 'wh_data.dart';
import 'wh_home.dart' show activityIconOf;
import 'wh_widgets.dart';
import 'whoop_charts.dart';

class WhWorkout extends StatefulWidget {
  final String id;
  final Map<String, dynamic> row;
  final WhView view;
  const WhWorkout({super.key, required this.id, required this.row, required this.view});
  @override
  State<WhWorkout> createState() => _WhWorkoutState();
}

class _WhWorkoutState extends State<WhWorkout> {
  Map<String, dynamic>? w;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final repo = repoOf(context);
    if (repo == null) {
      setState(() => loading = false);
      return;
    }
    try {
      final got = await repo.getWorkout(widget.id);
      if (mounted) setState(() => w = got);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final r = {...widget.row, ...?w};
    final type = r['type']?.toString();
    final name = familiarActivityName(c, type);
    final start = (r['start_ts'] as num?)?.toInt(), end = (r['end_ts'] as num?)?.toInt();
    final durSec = start != null && end != null && end > start ? end - start : ((r['duration_min'] as num?)?.toDouble() ?? 0) * 60;
    final hr = [for (final e in r['hr'] as List? ?? const []) if (e is Map) (e['v'] as num?)?.toDouble()];
    final maxHr = (r['max_hr'] as num?)?.toDouble() ?? (hr.whereType<double>().isEmpty ? null : hr.whereType<double>().reduce((a, b) => a > b ? a : b));
    final top = maxHr == null ? 200.0 : ((maxHr / 25).ceil() * 25).toDouble().clamp(125, 220);
    final ticks = [for (var t = top - 100; t <= top; t += 25) t.toDouble()];
    final zoneMin = [for (final x in r['whoop_zone_min'] as List? ?? const []) (x as num).toDouble()];
    final lower = [for (final x in r['whoop_zone_lower_bpm'] as List? ?? const []) (x as num).toDouble()];
    final fallbackZones = [for (final x in r['zone_min'] as List? ?? const []) (x as num).toDouble()];
    final zones = zoneMin.length == 5 ? zoneMin : fallbackZones.length == 5 ? fallbackZones : const <double>[];
    final zoneTotal = zones.fold(0.0, (a, b) => a + b);
    final strain = (r['whoop_strain'] as num?)?.toDouble() ?? (r['strain'] as num?)?.toDouble();
    final steps = (r['steps'] as num?)?.toInt();
    final whoopZones = zoneMin.length == 5;
    return Scaffold(
      backgroundColor: W.bg,
      body: SafeArea(
        child: Column(
          children: [
            WhNavbar(
              title: name,
              titleWidget: Row(
                children: [
                  WhIcon(activityIconOf(type), size: 22, color: W.ink),
                  const SizedBox(width: S.x2 + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name.toUpperCase(), style: FW.h5.copyWith(color: W.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${clockOf(start)} – ${clockOf(end)}${start == null ? '' : ' · ${dayShort(DateTime.fromMillisecondsSinceEpoch(start * 1000))}'}', style: FW.hint.copyWith(color: W.ink2)),
                      ],
                    ),
                  ),
                ],
              ),
              right: Pressable(onTap: () => openFamiliarWorkout(c, widget.row), semanticLabel: 'Подробности OpenStrap', child: const WhIcon('dot_menu', size: 18, color: W.ink)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(S.x4, S.x1, S.x4, S.x10),
                children: [
                  if (loading) const LinearProgressIndicator(color: W.action, backgroundColor: W.card2),
                  Row(
                    children: [
                      Expanded(child: _Stat(value: strain == null ? '—' : ruDecimal(strain), label: 'Нагрузка активности', color: W.strain, delta: null)),
                      Expanded(child: _Stat(value: steps == null ? '—' : groupThousands(steps), label: 'Шаги за активность', color: W.ink, delta: null)),
                    ],
                  ),
                  const SizedBox(height: S.x2),
                  if (hr.length >= 2)
                    WcBox(WcHrAreaPainter(vals: hr, yTicks: ticks, startLabel: clockOf(start), endLabel: clockOf(end), strokeWidth: 1.4), height: 190)
                  else
                    Padding(padding: const EdgeInsets.symmetric(vertical: S.x4), child: Text(loading ? 'Загружаю запись пульса…' : 'Записи пульса за эту активность нет: браслет не был на руке или данные ещё не синхронизированы.', style: FW.hint.copyWith(color: W.ink3))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(S.x1, S.x2, S.x1, S.x2),
                    child: Row(
                      children: [
                        Container(width: 14, height: 14, decoration: BoxDecoration(border: Border.all(color: W.ink4, width: 1.5), borderRadius: WR.rTiny)),
                        const SizedBox(width: S.x2),
                        Text('ТИПИЧНЫЙ ДИАПАЗОН', style: FW.over.copyWith(color: W.ink2)),
                        const Spacer(),
                        Text('ДЛИТЕЛЬНОСТЬ', style: FW.over.copyWith(color: W.ink2)),
                        const SizedBox(width: S.x2),
                        _Secs(durSec.toDouble()),
                      ],
                    ),
                  ),
                  if (zones.length == 5)
                    for (var z = 5; z >= 1; z--)
                      WhCard(
                        padding: const EdgeInsets.fromLTRB(S.x3 + 2, S.x1, S.x3 + 2, S.x1),
                        margin: const EdgeInsets.only(bottom: S.x2),
                        child: WcHatchRow(
                          label: 'Зона $z',
                          sub: lower.length == 5 ? (z == 5 ? '${lower[4].round()}+ уд/мин' : '${lower[z - 1].round()}–${(lower[z].round() - 1)} уд/мин') : null,
                          pct: zoneTotal <= 0 ? 0 : (zones[z - 1] / zoneTotal * 100).round(),
                          color: W.zones[z - 1],
                          value: _Secs(zones[z - 1] * 60),
                        ),
                      )
                  else
                    WhCard(child: Text('Минуты по зонам появятся вместе с записью пульса.', style: FW.hint.copyWith(color: W.ink3))),
                  const SizedBox(height: S.x2),
                  WhCard(
                    child: Row(
                      children: [
                        for (final (v, l) in [((r['avg_hr'] as num?)?.round(), 'Средний пульс'), (maxHr?.round(), 'Макс. пульс'), ((r['calories'] as num?)?.round(), 'Калории')])
                          Expanded(child: Column(children: [Text(v == null ? '—' : '$v', style: FW.n28.copyWith(color: W.ink)), const SizedBox(height: S.x1 + 2), Text(l.toUpperCase(), style: FW.tiny.copyWith(color: W.ink2, fontWeight: FontWeight.w700, letterSpacing: .8), textAlign: TextAlign.center)])),
                      ],
                    ),
                  ),
                  WhCard(
                    child: Column(
                      children: [
                        WhKv('Источник пульса', (r['device_family'] ?? 'браслет').toString()),
                        WhKv('Тип записи', r['source'] == 'manual' ? 'Вручную, по записанному пульсу' : 'Авто', ),
                        WhKv('Зоны', whoopZones ? 'по резерву пульса 50/60/70/80/90 %' : 'зоны OpenStrap', last: true),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: WhPill('Изменить', icon: 'pencil', outline: true, onTap: () => openFamiliarWorkout(c, widget.row))),
                      const SizedBox(width: S.x2 + 2),
                      Expanded(child: WhPill('Удалить', icon: 'delete', outline: true, onTap: () => _delete(c))),
                    ],
                  ),
                  WhNote(whoopZones ? 'Нагрузка активности — та же формула, что и для дня, по секундам этой записи.' : 'Показаны данные OpenStrap: WHOOP-нагрузка появится, когда известны возраст, пол и 28-дневный пульс покоя.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext c) async {
    final ok = await showDialog<bool>(
      context: c,
      builder: (dc) => AlertDialog(
        backgroundColor: W.card,
        title: Text('Удалить активность?', style: FW.t3.copyWith(color: W.ink)),
        content: Text('Запись пульса останется, удалится только сама активность.', style: FW.body.copyWith(color: W.ink2)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dc).pop(false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.of(dc).pop(true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true || !c.mounted) return;
    final repo = c.read<AppState>().repo;
    await repo?.deleteWorkout(widget.id);
    if (c.mounted) Navigator.of(c).pop();
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  final Color color;
  final String? delta;
  const _Stat({required this.value, required this.label, required this.color, this.delta});
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Text(value, style: FW.n28.copyWith(color: color)), if (delta != null) ...[const SizedBox(width: S.x1 + 2), Text(delta!, style: FW.n10.copyWith(color: W.action))]]),
      const SizedBox(height: S.x1 + 2),
      Text(label.toUpperCase(), style: FW.over.copyWith(color: W.ink2)),
    ],
  );
}

class _Secs extends StatelessWidget {
  final double seconds;
  const _Secs(this.seconds);
  @override
  Widget build(BuildContext c) {
    final s = seconds.round();
    return Text.rich(TextSpan(children: [TextSpan(text: '${s ~/ 3600}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}', style: FW.n17.copyWith(color: W.ink)), TextSpan(text: ':${(s % 60).toString().padLeft(2, '0')}', style: FW.n11.copyWith(color: W.ink))]));
  }
}
