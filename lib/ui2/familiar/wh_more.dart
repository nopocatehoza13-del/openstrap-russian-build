// “Ещё”, “Настройки” and the observations feed in WHOOP styling.
import 'package:flutter/material.dart';
import 'package:personal_analytics/whoop_observations.dart';

import '../../data/day_label.dart';
import '../profile/alarm.dart';
import '../profile/data.dart';
import '../profile/devices.dart';
import '../profile/profile.dart';
import '../profile/settings.dart';
import '../screens/health_screen.dart';
import '../screens/nutrition_screen.dart';
import '../screens/wellness_screen.dart';
import '../screens/what_changed.dart';
import '../screens/workout_screen.dart';
import '../theme.dart';
import 'wh_data.dart';
import 'wh_nav.dart';
import 'wh_widgets.dart';

Future<void> _push(BuildContext c, Widget w) => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => w));

Widget _wrap(String title, Widget body) => Scaffold(backgroundColor: W.bg, appBar: AppBar(title: Text(title), backgroundColor: W.bg), body: body);

class FamiliarAllHealth extends StatelessWidget {
  const FamiliarAllHealth({super.key});
  @override
  Widget build(BuildContext c) => _wrap('Все показатели', const HealthScreen());
}

class FamiliarActivities extends StatelessWidget {
  const FamiliarActivities({super.key});
  @override
  Widget build(BuildContext c) => _wrap('Активности', const WorkoutScreen());
}

class FamiliarMore extends StatelessWidget {
  const FamiliarMore({super.key});
  @override
  Widget build(BuildContext c) => ColoredBox(
    color: W.bg,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(S.x4, S.x1, S.x4, S.x10),
      children: [
        SizedBox(height: 44, child: Center(child: Text('ЕЩЁ', style: FW.h4.copyWith(color: W.ink)))),
        Container(
          margin: const EdgeInsets.only(bottom: S.x3),
          padding: const EdgeInsets.all(S.x4),
          decoration: BoxDecoration(color: W.card, borderRadius: WR.rCard),
          child: Row(
            children: [
              Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, color: W.card3), child: const Center(child: WhIcon('profile', size: 22, color: W.ink))),
              const SizedBox(width: S.x3),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Мой профиль', style: FW.b1.copyWith(color: W.ink)), Text('возраст, пол, рост, вес и цели', style: FW.hint.copyWith(color: W.ink2))])),
              const WhIcon('navigation_forward', size: 12, color: W.ink4),
            ],
          ),
        ),
        WhMenu([
          WhMenuItem('Тренировки, зоны пульса и история', subtitle: 'Все записи, зоны, автодетект', icon: 'hr_zone_training', onTap: () => _push(c, const FamiliarActivities())),
          WhMenuItem('Питание и дневник еды', subtitle: 'Калории, макросы, вода', icon: 'calories', onTap: () => _push(c, _wrap('Питание', const NutritionScreen()))),
          WhMenuItem('Самочувствие, дневник и привычки', subtitle: 'Записи, настроение, влияние привычек', icon: 'feedback', onTap: () => _push(c, _wrap('Самочувствие', const WellnessScreen()))),
          WhMenuItem('Все показатели и анализы', subtitle: 'Тренды, циркадный ритм, ЭКГ-скрин', icon: 'trend', onTap: () => _push(c, const FamiliarAllHealth())),
          WhMenuItem('Что изменилось', subtitle: 'Ночной обзор находок', icon: 'report', onTap: () => _push(c, const WhatChangedScreen())),
        ]),
        WhMenu([
          WhMenuItem('Импорт WHOOP, экспорт, резервная копия', subtitle: 'CSV, SQLite, HealthKit', icon: 'data', onTap: () => _push(c, const DataScreen())),
          WhMenuItem('Браслет и источники данных', subtitle: 'WHOOP 5.0 / MG, нагрудные датчики', icon: 'strap', onTap: () => _push(c, const MyDevices())),
          WhMenuItem('Будильник браслета', subtitle: 'Вибрация по времени', icon: 'strap_settings', onTap: () => _push(c, const AlarmScreen())),
        ]),
        const WhNote('Уникальные функции OpenStrap собраны здесь, а не во вкладке «Сообщество».'),
      ],
    ),
  );
}

class FamiliarSettings extends StatelessWidget {
  const FamiliarSettings({super.key});
  @override
  Widget build(BuildContext c) => ColoredBox(
    color: W.bg,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(S.x4, S.x1, S.x4, S.x10),
      children: [
        SizedBox(height: 44, child: Center(child: Text('НАСТРОЙКИ', style: FW.h4.copyWith(color: W.ink)))),
        WhMenu([
          WhMenuItem('Мой профиль', icon: 'profile', onTap: () => _push(c, const ProfileHome())),
          WhMenuItem('Возраст, рост, вес и цели', icon: 'weight', subtitle: 'нужны для нагрузки, зон и возраста организма', onTap: () => _push(c, const EditProfile())),
          WhMenuItem('Мои устройства', icon: 'strap', onTap: () => _push(c, const MyDevices())),
        ]),
        WhMenu([
          WhMenuItem('Уведомления и напоминания', icon: 'notifications', onTap: () => _push(c, const NotificationSettings())),
          WhMenuItem('Оформление, язык и единицы', icon: 'languages', subtitle: 'Русский · °C · 24 ч', onTap: () => _push(c, const MoreSettings())),
          WhMenuItem('Данные, импорт и резервные копии', icon: 'data', onTap: () => _push(c, const DataScreen())),
          WhMenuItem('Будильник', icon: 'strap_settings', onTap: () => _push(c, const AlarmScreen())),
          WhMenuItem('Приватность', icon: 'privacy', subtitle: 'данные хранятся локально, без облака', onTap: () => _push(c, const MoreSettings())),
        ]),
        const WhNote('Личная сборка на основе OpenStrap. Данные хранятся на телефоне. Перед обновлением сохраните резервную копию.'),
      ],
    ),
  );
}

/// The full feed for the day, grouped by time, each card dismissable.
class WhObservationsScreen extends StatefulWidget {
  final WhView view;
  const WhObservationsScreen({super.key, required this.view});
  @override
  State<WhObservationsScreen> createState() => _WhObservationsScreenState();
}

class _WhObservationsScreenState extends State<WhObservationsScreen> {
  @override
  Widget build(BuildContext c) {
    final v = widget.view;
    final nav = WhNav(c, v);
    final all = v.allObservations();
    final gone = dismissedObservations();
    final live = [for (final o in all) if (!gone.contains(o.id)) o];
    final dismissed = [for (final o in all) if (gone.contains(o.id)) o];
    return WhPage(
      title: 'Наблюдения',
      subtitle: v.isToday ? 'сегодня, ${dayLabelOf(v.date)}' : dayLabelOf(v.date),
      children: [
        if (all.isEmpty) WhCard(child: Text('Наблюдений пока нет: они появляются из ночных данных, нагрузки, стресса, дневника и браслета. Синхронизируйте браслет утром.', style: FW.body.copyWith(color: W.ink2))),
        for (final o in live)
          WhObservationCard(
            eyebrow: '${_kindName(o.kind)} · ${o.time}',
            text: '${o.title}\n${o.text}',
            link: o.link,
            onLink: () => nav.go(o.target),
            badge: Container(width: 24, height: 24, decoration: BoxDecoration(color: (o.tone == 1 ? W.action : o.tone == 2 ? W.neg : W.ink4).withValues(alpha: .15), borderRadius: WR.rBar), child: Center(child: WhIcon(o.tone == 1 ? 'checkmark' : o.tone == 2 ? 'attention' : 'tiny_information', size: 11, color: o.tone == 1 ? W.action : o.tone == 2 ? W.neg : W.ink4))),
            onDismiss: () => setState(() => dismissObservation(o.id)),
          ),
        if (dismissed.isNotEmpty) ...[
          const WhSection('Закрытые'),
          for (final o in dismissed) Opacity(opacity: .55, child: WhObservationCard(eyebrow: '${_kindName(o.kind)} · ${o.time}', text: '${o.title}\n${o.text}', link: o.link, onLink: () => nav.go(o.target))),
        ],
        const WhNote('Наблюдения строятся по правилам из измеренных данных: правило молчит, пока нет его входа. Ничего не отправляется в облако.'),
      ],
    );
  }
}

String _kindName(ObservationKind k) => switch (k) {
  ObservationKind.recovery => 'Восстановление',
  ObservationKind.sleep => 'Сон',
  ObservationKind.strain => 'Нагрузка',
  ObservationKind.stress => 'Стресс',
  ObservationKind.health => 'Монитор здоровья',
  ObservationKind.healthspan => 'Healthspan',
  ObservationKind.journal => 'Дневник',
  ObservationKind.device => 'Браслет',
  ObservationKind.weekly => 'Итоги недели',
};
