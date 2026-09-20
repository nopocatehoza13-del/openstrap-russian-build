// One router for every Familiar link target — observation cards, rows and
// menus all name a target string, and this turns it into a screen push.
import 'package:flutter/material.dart';

import '../profile/alarm.dart';
import '../profile/data.dart';
import '../profile/devices.dart';
import '../profile/profile.dart';
import '../profile/settings.dart';
import '../screens/calm_breathing.dart';
import '../screens/health_screen.dart';
import '../screens/journal_compose.dart';
import '../screens/metric_detail.dart';
import '../screens/nutrition_screen.dart';
import '../screens/sleep_detail.dart';
import '../screens/wellness_screen.dart';
import '../screens/what_changed.dart';
import '../screens/workout_screen.dart' show openFamiliarActivityPicker, openFamiliarWorkout, WorkoutScreen;
import '../theme.dart';
import 'wh_data.dart';
import 'wh_healthspan.dart';
import 'wh_more.dart';
import 'wh_recovery_strain.dart';
import 'wh_sleep.dart';
import 'wh_stress.dart';
import 'wh_trend.dart';
import 'wh_workout.dart';

class WhNav {
  final BuildContext c;
  final WhView v;
  final VoidCallback? onReturn;
  WhNav(this.c, this.v, {this.onReturn});

  Future<void> push(Widget w) async {
    await Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => w));
    onReturn?.call();
  }

  Future<void> workout(Map<String, dynamic> row) async {
    final id = row['id'];
    if (id is String) {
      await push(WhWorkout(id: id, row: row, view: v));
    } else {
      await openFamiliarWorkout(c, row);
      onReturn?.call();
    }
  }

  Future<void> go(String target) async {
    if (target.startsWith('trend-')) return push(WhTrend(target.substring(6), view: v));
    switch (target) {
      case 'sleep':
      case 'sleep-last':
        return push(WhSleep(view: v));
      case 'sleep-edit':
        return push(SleepDetail(day: v.d.day));
      case 'recovery':
        return push(WhRecovery(view: v));
      case 'strain':
        return push(WhStrain(view: v));
      case 'stress':
        return push(FamiliarStressDetail(data: v.d));
      case 'stress-trends':
        return push(const MetricDetail('stress'));
      case 'breathing':
        return push(const CalmBreathing());
      case 'health-monitor':
        return push(FamiliarMonitorDetail(data: v.d));
      case 'healthspan':
      case 'age-method':
        return push(FamiliarAgeDetail(data: v.d));
      case 'tonight':
        return push(FamiliarSleepPlanner(data: v.d));
      case 'observations':
      case 'findings':
        return push(WhObservationsScreen(view: v));
      case 'journal':
        return push(JournalCompose(date: v.isToday ? null : v.d.day));
      case 'journal-insights':
        return push(const _Wrapped('Влияние привычек', WellnessScreen()));
      case 'activity-add':
        return push(const _Wrapped('Активности', WorkoutScreen()));
      case 'activity-day':
      case 'all-workouts':
        return push(const _Wrapped('Активности', WorkoutScreen()));
      case 'activity-start':
        await openFamiliarActivityPicker(c);
        onReturn?.call();
        return;
      case 'all-metrics':
        return push(const _Wrapped('Все показатели', HealthScreen()));
      case 'what-changed':
      case 'report':
        return push(WhatChangedScreen(day: v.d.day));
      case 'nutrition':
        return push(const _Wrapped('Питание', NutritionScreen()));
      case 'extra-data':
        return push(const DataScreen());
      case 'device':
        return push(const MyDevices());
      case 'alarm':
        return push(const AlarmScreen());
      case 'profile':
        return push(const ProfileHome());
      case 'edit-profile':
        return push(const EditProfile());
      case 'notifications':
        return push(const NotificationSettings());
      case 'appearance':
        return push(const MoreSettings());
      case 'sleep-need':
        return push(WhSleep(view: v));
      default:
        return push(WhTrend('hrv', view: v));
    }
  }
}

class _Wrapped extends StatelessWidget {
  final String title;
  final Widget body;
  const _Wrapped(this.title, this.body);
  @override
  Widget build(BuildContext c) => Scaffold(backgroundColor: W.bg, appBar: AppBar(title: Text(title), backgroundColor: W.bg), body: body);
}
