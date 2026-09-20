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

  // ── v8 ──
  test('v8: unified morning report replaces the two summaries and is push-worthy', () {
    final obs = buildObservations(ObservationInput(now: now, recovery: 76, hrv: 64, hrvLo: 52, hrvHi: 71, sleepPerf: 85, tstMin: 462, needMin: 495, hoursVsNeed: 93, targetLo: 10, targetHi: 14));
    final m = obs.singleWhere((o) => o.kind == ObservationKind.morning);
    expect(m.title, 'Восстановление 76 % · сон 85 %');
    expect(m.text, contains('Зелёная зона: ВСР 64 мс в вашем диапазоне 52–71'));
    expect(m.text, contains('Сон оптимальный: 7 ч 42 мин из 8:15'));
    expect(m.text, contains('Цель нагрузки на сегодня 10,0–14,0'));
    expect(m.push, isTrue);
    expect(m.priority, 99);
    expect(obs.any((o) => o.id.startsWith('recovery.summary')), isFalse);
    expect(obs.any((o) => o.id.startsWith('sleep.summary')), isFalse);
    final split = buildObservations(ObservationInput(now: now, recovery: 76, sleepPerf: 85, tstMin: 462, unifiedMorning: false));
    expect(split.any((o) => o.id.startsWith('recovery.summary')), isTrue);
    expect(split.any((o) => o.id.startsWith('sleep.summary')), isTrue);
    expect(split.any((o) => o.kind == ObservationKind.morning), isFalse);
  });
  test('v8: night detail — lowest HR, latency, nap, time in bed, alarm plan', () {
    final obs = buildObservations(ObservationInput(
      now: now,
      nightHrMin: 46,
      nightHrMinAtMinOfDay: 3 * 60 + 12,
      nightHrMinBaseline: 49,
      latencyMin: 42,
      latencyTypicalMin: 12,
      napMin: 35,
      needTonightMin: 470,
      inBedMin: 540,
      tstMin: 450,
      alarmTomorrowMinOfDay: 7 * 60,
      wokeBeforeAlarmMin: 20,
    ));
    String titleOf(String rule) => obs.singleWhere((o) => o.id.startsWith(rule)).title;
    expect(titleOf('sleep.night_hr_min'), 'Пульс ночью опускался до 46 в 03:12');
    expect(obs.singleWhere((o) => o.id.startsWith('sleep.night_hr_min')).tone, 1);
    expect(titleOf('sleep.latency_long'), 'Долго засыпали: 42 мин');
    expect(titleOf('sleep.nap'), 'Дрёма 35 мин зачтена');
    expect(titleOf('sleep.tib_vs_sleep'), 'В постели 9 ч, спали 7 ч 30 мин');
    expect(titleOf('sleep.alarm_plan'), 'Будильник на 07:00: отбой до 00:20 для 85 %');
    expect(titleOf('sleep.woke_before_alarm'), 'Проснулись за 20 минут до будильника');
    final high = buildObservations(ObservationInput(now: now, nightHrMin: 54, nightHrMinAtMinOfDay: 5 * 60, nightHrMinBaseline: 49));
    expect(high.single.tone, 2);
    expect(high.single.text, contains('не опустился до нормы'));
  });
  test('v8: records, social jetlag and a night without data', () {
    final obs = buildObservations(ObservationInput(
      now: now,
      recordNights: 20,
      tstMin: 520,
      sleepRecordPrevMax: 500,
      recovery: 91,
      recoveryRecordPrevMax: 88,
      restorativeMin: 240,
      restorativeRecordPrevMax: 230,
      weekendBedShiftMin: 95,
      noNightData: true,
      noNightReason: 'Браслет разряжен',
    ));
    expect(obs.map((o) => o.title), containsAll(['Самый долгий сон за 20 дней', 'Лучшее восстановление за 20 дней', 'Рекорд восстанавливающего сна', 'В выходные отбой на 1 ч 35 мин позже, чем в будни', 'Ночь без данных']));
    expect(obs.singleWhere((o) => o.id.startsWith('sleep.no_night')).text, startsWith('Браслет разряжен.'));
    final thin = buildObservations(ObservationInput(now: now, recordNights: 10, tstMin: 520, sleepRecordPrevMax: 500));
    expect(thin.any((o) => o.id.startsWith('sleep.record')), isFalse);
  });
  test('v8: wear gap, activity summary, new max HR, calories, rest days', () {
    final obs = buildObservations(ObservationInput(
      now: now,
      wearGapMin: 130,
      wearGapStartMinOfDay: 14 * 60 + 20,
      wearGapEndMinOfDay: 16 * 60 + 30,
      wornMin: 900,
      lastActivityName: 'Бег',
      lastActivityStrain: 12.4,
      lastActivityDurationMin: 48,
      lastActivityZoneMin: [5, 12, 20, 9, 2],
      lastActivityAvgHr: 152,
      lastActivityMaxHr: 178,
      lastActivityPrevStrain: 11.1,
      lastActivityEndMinOfDay: 18 * 60 + 5,
      maxHrNew: 187,
      maxHrPrev: 184,
      caloriesToday: 2900,
      caloriesWeekAvg: 2300,
    ));
    String titleOf(String rule) => obs.singleWhere((o) => o.id.startsWith(rule)).title;
    expect(titleOf('device.wear_gap'), 'Браслет не на руке 2 ч 10 мин');
    expect(obs.singleWhere((o) => o.id.startsWith('device.wear_gap')).text, contains('С 14:20 до 16:30'));
    expect(titleOf('strain.activity_summary'), '«Бег»: нагрузка 12,4 за 48 мин');
    final a = obs.singleWhere((o) => o.id.startsWith('strain.activity_summary'));
    expect(a.text, contains('Зоны: 1 — 5 мин, 2 — 12 мин, 3 — 20 мин, 4 — 9 мин, 5 — 2 мин.'));
    expect(a.text, contains('Пульс 152 средний, 178 макс.'));
    expect(a.text, contains('Прошлая такая же: 11,1.'));
    expect(a.time, '18:05');
    expect(a.push, isTrue);
    expect(titleOf('strain.max_hr_new'), 'Новый максимум пульса: 187 уд/мин');
    expect(titleOf('strain.calories').replaceAll(RegExp(r'\s'), ' '), 'Калорий за день 2 900 — на 26 % больше обычного');
    final morningObs = buildObservations(ObservationInput(now: DateTime(2026, 9, 21, 9), restDays: 2, recovery: 80));
    expect(morningObs.map((o) => o.title), contains('Два дня без тренировок при зелёном восстановлении'));
    final noNew = buildObservations(ObservationInput(now: now, maxHrNew: 184, maxHrPrev: 184));
    expect(noNew, isEmpty);
  });
  test('v8: vitals — rising RHR, respiratory rate alone, band SpO₂, skin temperature', () {
    final a = buildObservations(ObservationInput(now: now, rhr: 56, rhrBaseline: 53, rhrRisingDays: 3, resp: 16.4, respHi: 15.2, respAboveStreak: 2));
    expect(a.singleWhere((o) => o.id.startsWith('recovery.rhr_rising')).title, 'Пульс покоя растёт третий день подряд');
    expect(a.singleWhere((o) => o.id.startsWith('health.resp_high')).title, 'Дыхание выше нормы вторую ночь подряд');
    final b = buildObservations(ObservationInput(now: now, spo2: 93, spo2Lo: 94, spo2Source: 'band', spo2Samples: 41, skinTempC: 33.9, skinTempDevC: 0.4));
    final sp = b.singleWhere((o) => o.id.startsWith('health.spo2_band'));
    expect(sp.title, 'SpO₂ ночью 93 % — ниже нормы');
    expect(sp.text, contains('замеров: 41'));
    expect(sp.tone, 2);
    expect(b.singleWhere((o) => o.id.startsWith('health.skin_temp_dev')).title, 'Температура кожи на 0,4 °C выше вашей нормы');
    final imported = buildObservations(ObservationInput(now: now, spo2: 97, spo2Lo: 94, spo2Source: 'import'));
    expect(imported.any((o) => o.id.startsWith('health.spo2_band')), isFalse);
  });
  test('v8: patterns and the monthly Healthspan step', () {
    final obs = buildObservations(ObservationInput(
      now: DateTime(2026, 10, 2, 9), // a Friday, 2nd of the month
      patternDays: 24,
      hardDayRecovery: 48,
      easyDayRecovery: 63,
      weekdayLow: 'пятница',
      weekdayLowIndex: DateTime.friday,
      weekdayLowDelta: -12,
      weekdayN: 6,
      hrvCv7: .31,
      hrvCv30: .12,
      whoopAge: 31.4,
      ageDelta30: -0.4,
      ageTopChangeFactor: 'часы сна',
      ageTopChangeYears: -0.3,
    ));
    expect(obs.map((o) => o.title), containsAll([
      'После тяжёлых дней восстановление 48 % против 63 %',
      'Сегодня пятница: восстановление обычно ниже на 12',
      'ВСР скачет: разброс за неделю вдвое выше обычного',
      'За месяц возраст организма −0,4 года',
    ]));
    final other = buildObservations(ObservationInput(now: DateTime(2026, 10, 1, 9), weekdayLow: 'пятница', weekdayLowIndex: DateTime.friday, weekdayLowDelta: -12, weekdayN: 6));
    expect(other.any((o) => o.id.startsWith('weekly.pattern_weekday')), isFalse);
  });
  test('v8: push eligibility follows kPushRules', () {
    final obs = buildObservations(ObservationInput(now: now, batteryPct: 15, journalTracked: true, journalStreak: 3));
    expect(obs.singleWhere((o) => o.id.startsWith('device.battery')).push, isTrue);
    expect(obs.singleWhere((o) => o.id.startsWith('journal.fill')).push, isFalse);
  });
}
