import 'package:flutter_test/flutter_test.dart';
import 'package:personal_analytics/whoop_observations.dart';

void main() {
  final now = DateTime(2026, 9, 21, 20, 30); // Monday evening
  test('empty input produces nothing — no rule fires without its measurement', () {
    expect(buildObservations(ObservationInput(now: now)), isEmpty);
  });
  test('recovery summary reads HRV range and RHR baseline', () {
    final obs = buildObservations(ObservationInput(now: now, recovery: 76, hrv: 64, hrvLo: 52, hrvHi: 71, rhr: 52, rhrBaseline: 54));
    final o = obs.singleWhere((o) => o.id.startsWith('recovery.summary'));
    expect(o.title, 'Восстановление 76 % — зелёная зона');
    expect(o.text, contains('ВСР 64 мс в вашем диапазоне 52–71'));
    expect(o.text, contains('на 2 ниже нормы'));
    expect(o.tone, 1);
    expect(o.id, 'recovery.summary.2026-09-21');
  });
  test('streak rules', () {
    final obs = buildObservations(ObservationInput(now: now, hrv: 66, hrvLo: 52, hrvHi: 71, hrvAboveStreak: 3, recovery7: [50, 70, 71, 80]));
    expect(obs.map((o) => o.title), containsAll(['ВСР выше нормы третью ночь подряд', 'Три зелёных дня подряд']));
  });
  test('illness watch needs two co-moving signals', () {
    final one = buildObservations(ObservationInput(now: now, rhr: 60, rhrBaseline: 54, monitorTotal: 5, monitorInRange: 4, monitorOutside: ['пульс в покое 60']));
    expect(one.any((o) => o.id.contains('illness_watch')), isFalse);
    expect(one.any((o) => o.id.contains('monitor_out')), isTrue);
    final two = buildObservations(ObservationInput(now: now, rhr: 60, rhrBaseline: 54, resp: 17.2, respHi: 15.4));
    expect(two.first.id, contains('illness_watch'));
    expect(two.first.priority, 95);
  });
  test('sleep: summary, debt with bedtime, tonight plan', () {
    final obs = buildObservations(ObservationInput(
      now: now,
      sleepPerf: 85,
      tstMin: 462,
      needMin: 495,
      hoursVsNeed: 93,
      consistency: 68,
      efficiency: 96,
      sleepStressPct: 2,
      debtOutstandingMin: 70,
      debtTonightMin: 35,
      needTonightMin: 495,
      wakeMinOfDay: 7 * 60,
      baselineMin: 460,
      strainAddMin: 20,
      baselineSource: 'population',
      nightsForBaseline: 2,
    ));
    final debt = obs.singleWhere((o) => o.id.contains('sleep.debt'));
    expect(debt.title, 'Недосып 1 ч 10 мин');
    expect(debt.text, contains('ложитесь до 22:45'));
    final tonight = obs.singleWhere((o) => o.id.contains('sleep.tonight'));
    expect(tonight.text, contains('норма 7:40 + нагрузка +0:20 + недосып +0:35'));
    expect(tonight.text, contains('после 3 ночей записи'));
    final summary = obs.singleWhere((o) => o.id.contains('sleep.summary'));
    expect(summary.text, contains('Вы спали 7 ч 42 мин из потребности 8:15'));
    expect(summary.text, contains('Тянут вниз'));
  });
  test('strain target rules and steps', () {
    final hit = buildObservations(ObservationInput(now: now, strain: 14.2, targetLo: 13.5, targetHi: 15.6, steps: 12459, stepGoal: 10000));
    expect(hit.map((o) => o.title), containsAll(['Цель нагрузки 13,5–15,6 достигнута', 'Цель по шагам выполнена: 12 459']));
    final under = buildObservations(ObservationInput(now: DateTime(2026, 9, 21, 17, 30), strain: 10.2, targetLo: 13.5, targetHi: 15.6));
    expect(under.first.title, 'До цели нагрузки осталось 3,3');
    final over = buildObservations(ObservationInput(now: now, strain: 18.0, targetLo: 13.5, targetHi: 15.6, recovery: 30));
    expect(over.map((o) => o.title), contains('Высокая нагрузка при красном восстановлении'));
    expect(over.map((o) => o.id), contains('strain.target_over.2026-09-21'));
  });
  test('stress and device rules', () {
    final obs = buildObservations(ObservationInput(
      now: now,
      longestHighStartMinOfDay: 9 * 60 + 5,
      longestHighDurMin: 51,
      lowStressMin: 420,
      mediumStressMin: 530,
      highStressMin: 74,
      highTypicalMin: 40,
      batteryPct: 18,
      sinceSync: const Duration(hours: 7),
    ));
    final titles = obs.map((o) => o.title).toList();
    expect(titles, contains('Самый длинный период высокого стресса — 51 минуту'));
    expect(obs.firstWhere((o) => o.id.contains('longest_high')).text, contains('начался в 09:05'.replaceFirst('н', 'Н')));
    expect(titles, contains('Стресса больше обычного: 1 ч 14 мин высокого'));
    expect(titles, contains('Заряд браслета 18 %'));
    expect(titles, contains('Нет синхронизации 7 ч'));
  });
  test('weekly summary only on Monday, journal effects need 10 days', () {
    final mon = buildObservations(ObservationInput(now: now, weekRecovery: 68, prevWeekRecovery: 64, weekStrain: 10.9, prevWeekStrain: 11.5, journalEffects: const [JournalEffect('Алкоголь', -12, 14), JournalEffect('Медитация', 6, 4)]));
    expect(mon.map((o) => o.title), contains('Итоги недели'));
    expect(mon.firstWhere((o) => o.id.contains('weekly')).text, contains('Восстановление 68 % (+4 к прошлой неделе), нагрузка 10,9 (−0,6)'));
    expect(mon.where((o) => o.kind == ObservationKind.journal && o.id.contains('effect')).length, 1);
    final tue = buildObservations(ObservationInput(now: DateTime(2026, 9, 22, 9), weekRecovery: 68, prevWeekRecovery: 64));
    expect(tue.any((o) => o.kind == ObservationKind.weekly), isFalse);
  });
  test('sorted by priority, ids unique', () {
    final obs = buildObservations(ObservationInput(now: now, recovery: 20, recovery7: [30, 20], strain: 18, targetLo: 12, targetHi: 14, batteryPct: 10));
    for (var i = 1; i < obs.length; i++) {
      expect(obs[i - 1].priority, greaterThanOrEqualTo(obs[i].priority));
    }
    expect(obs.map((o) => o.id).toSet().length, obs.length);
  });
}
