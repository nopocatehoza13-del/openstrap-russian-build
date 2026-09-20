import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/notify/notification_event.dart';
import 'package:openstrap_edge/notify/notification_prefs.dart';
import 'package:openstrap_edge/notify/tap_router.dart';

void main() {
  NotificationEvent obs({NotifCategory category = NotifCategory.recovery}) => NotificationEvent(
    dedupeKey: 'morning.report.2026-09-21',
    category: category,
    title: 'Восстановление 76 % · сон 85 %',
    body: 'Зелёная зона.',
    date: '2026-09-21',
    route: observationRoute('morning.report.2026-09-21'),
  );
  test('an observation route is its own class whatever the category', () {
    expect(classOf(obs()), NotifClass.observation);
    expect(classOf(obs(category: NotifCategory.health)), NotifClass.observation);
    expect(classOf(obs(category: NotifCategory.reminders)), NotifClass.observation);
    expect(routePath(obs().route!), kRouteObservations);
    expect(routeId(obs().route!), 'morning.report.2026-09-21');
  });
  test('shouldFireOs: master switch and quiet hours, no category dependence', () {
    const on = NotificationPrefs(recoveryEnabled: false, healthEnabled: false);
    expect(on.shouldFireOs(obs(), 9 * 60), isTrue);
    expect(on.shouldFireOs(obs(category: NotifCategory.health), 9 * 60), isTrue);
    expect(on.shouldFireOs(obs(), 23 * 60), isFalse); // default quiet hours 22:00–07:00
    const off = NotificationPrefs(observationsEnabled: false);
    expect(off.shouldFireOs(obs(), 9 * 60), isFalse);
    const noQuiet = NotificationPrefs(quietEnabled: false);
    expect(noQuiet.shouldFireOs(obs(), 23 * 60), isTrue);
  });
  test('defaults and copyWith', () {
    const p = NotificationPrefs();
    expect(p.observationsEnabled, isTrue);
    expect(p.observationsMorning, isTrue);
    expect(p.observationsEvening, isTrue);
    expect(p.observationsBedtime, isTrue);
    expect(p.observationsDailyCap, 4);
    final q = p.copyWith(observationsDailyCap: 6, observationsBedtime: false);
    expect(q.observationsDailyCap, 6);
    expect(q.observationsBedtime, isFalse);
    expect(q.observationsMorning, isTrue);
  });
}
