/// Observations — the rule-based feed that replaces WHOOP Coach on the
/// Familiar surface. Every rule reads measured inputs only; a null input
/// silently disables the rules that need it, so nothing is ever written about a
/// number the app does not have. Pure Dart: no clock, no storage, no Flutter.
///
/// The voice follows WHOOP's own notifications and Daily Outlook copy: one
/// concrete fact, its personal context (typical range / baseline / target),
/// then what to do about it.
library;

import 'dart:math' as math;

class JournalEffect {
  final String tag;

  /// Difference of the metric on tagged vs untagged days, in points of the
  /// metric (recovery %, sleep %, …), positive = better.
  final double effect;
  final int days;
  final String metric;
  const JournalEffect(this.tag, this.effect, this.days, {this.metric = 'recovery'});
}

class ObservationInput {
  final DateTime now;

  /// True when the screen is looking at today (recommendations only then).
  final bool today;

  // ── recovery ──
  final double? recovery;
  final double? hrv, hrvLo, hrvHi, hrvBaseline;
  final int hrvAboveStreak, hrvBelowStreak;
  final double? rhr, rhrBaseline, rhrLo, rhrHi;
  final double? resp, respLo, respHi;
  final double? spo2, spo2Lo;
  final double? skinTempZ;
  final List<double?> recovery7;

  // ── sleep ──
  final double? sleepPerf, hoursVsNeed, consistency, efficiency, sleepStressPct;
  final double? tstMin, needMin, needTonightMin, baselineMin, debtTonightMin, strainAddMin, debtOutstandingMin;
  final int? wakeEvents;
  final double? awakeMin;
  final double? bedMinOfDay, typicalBedMinOfDay, wakeMinOfDay;
  final double? restorativeMin, restorativeBaselineMin;
  final String? baselineSource;
  final int? nightsForBaseline;

  // ── strain ──
  final double? strain, strainYesterday, targetLo, targetHi;
  final double? z13TodayMin, z13WeekAvgMin, z45TodayMin, z45WeekAvgMin;
  final int? steps, stepGoal;
  final int activities;
  final double? activityStrainMax;
  final String? activityName;

  // ── stress ──
  final double? stressNow;
  final double? highStressMin, mediumStressMin, lowStressMin, highTypicalMin;
  final int? longestHighStartMinOfDay;
  final double? longestHighDurMin;
  final bool breathingDoneToday;

  // ── health monitor ──
  final int? monitorInRange, monitorTotal;
  final List<String> monitorOutside;

  // ── healthspan ──
  final double? whoopAge, chronoAge, pace, pacePrev;
  final String? topFactor;
  final double? topFactorYears;

  // ── journal ──
  final List<JournalEffect> journalEffects;
  final int journalStreak;
  final bool journalDoneToday;

  /// True once the journal has ever been used; the daily nudge is silent
  /// before that so an empty install is not lectured.
  final bool journalTracked;

  // ── device ──
  final double? batteryPct;
  final bool charging;
  final Duration? sinceSync;

  // ── weekly ──
  final double? weekRecovery, prevWeekRecovery, weekStrain, prevWeekStrain, weekSleepPerf, prevWeekSleepPerf;

  const ObservationInput({
    required this.now,
    this.today = true,
    this.recovery,
    this.hrv,
    this.hrvLo,
    this.hrvHi,
    this.hrvBaseline,
    this.hrvAboveStreak = 0,
    this.hrvBelowStreak = 0,
    this.rhr,
    this.rhrBaseline,
    this.rhrLo,
    this.rhrHi,
    this.resp,
    this.respLo,
    this.respHi,
    this.spo2,
    this.spo2Lo,
    this.skinTempZ,
    this.recovery7 = const [],
    this.sleepPerf,
    this.hoursVsNeed,
    this.consistency,
    this.efficiency,
    this.sleepStressPct,
    this.tstMin,
    this.needMin,
    this.needTonightMin,
    this.baselineMin,
    this.debtTonightMin,
    this.strainAddMin,
    this.debtOutstandingMin,
    this.wakeEvents,
    this.awakeMin,
    this.bedMinOfDay,
    this.typicalBedMinOfDay,
    this.wakeMinOfDay,
    this.restorativeMin,
    this.restorativeBaselineMin,
    this.baselineSource,
    this.nightsForBaseline,
    this.strain,
    this.strainYesterday,
    this.targetLo,
    this.targetHi,
    this.z13TodayMin,
    this.z13WeekAvgMin,
    this.z45TodayMin,
    this.z45WeekAvgMin,
    this.steps,
    this.stepGoal,
    this.activities = 0,
    this.activityStrainMax,
    this.activityName,
    this.stressNow,
    this.highStressMin,
    this.mediumStressMin,
    this.lowStressMin,
    this.highTypicalMin,
    this.longestHighStartMinOfDay,
    this.longestHighDurMin,
    this.breathingDoneToday = false,
    this.monitorInRange,
    this.monitorTotal,
    this.monitorOutside = const [],
    this.whoopAge,
    this.chronoAge,
    this.pace,
    this.pacePrev,
    this.topFactor,
    this.topFactorYears,
    this.journalEffects = const [],
    this.journalStreak = 0,
    this.journalDoneToday = false,
    this.journalTracked = false,
    this.batteryPct,
    this.charging = false,
    this.sinceSync,
    this.weekRecovery,
    this.prevWeekRecovery,
    this.weekStrain,
    this.prevWeekStrain,
    this.weekSleepPerf,
    this.prevWeekSleepPerf,
  });
}

enum ObservationKind { recovery, sleep, strain, stress, health, healthspan, journal, device, weekly }

class Observation {
  /// Stable per day: `<kind>.<rule>.<yyyy-mm-dd>`; dismissals are keyed on it.
  final String id;
  final ObservationKind kind;
  final String title;
  final String text;

  /// Link label and route key (`sleep`, `recovery`, `strain`, `stress`,
  /// `health-monitor`, `healthspan`, `journal`, `device`, `tonight`, `breathing`).
  final String link, target;

  /// 0 neutral · 1 good · 2 attention.
  final int tone;

  /// Higher first.
  final int priority;
  final String time;
  const Observation({
    required this.id,
    required this.kind,
    required this.title,
    required this.text,
    required this.link,
    required this.target,
    this.tone = 0,
    this.priority = 50,
    this.time = '',
  });
}

String _hm(num min) => '${min.round() ~/ 60}:${(min.round() % 60).toString().padLeft(2, '0')}';
String _hmWords(num min) {
  final h = min.round() ~/ 60, m = min.round() % 60;
  if (h == 0) return '$m мин';
  if (m == 0) return '$h ч';
  return '$h ч $m мин';
}

String _clock(num minOfDay) {
  final m = ((minOfDay % 1440) + 1440) % 1440;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toInt().toString().padLeft(2, '0')}';
}

String _d1(num v) => v.toStringAsFixed(1).replaceAll('.', ',');
String _pct(num v) => '${v.round()} %';
String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _nightsGen(int n) => n == 1 ? '1 ночи' : '$n ночей';
String _days(int n) => n % 10 == 1 && n % 100 != 11 ? '$n день' : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) ? '$n дня' : '$n дней';
String _minutes(int n) => n % 10 == 1 && n % 100 != 11 ? '$n минуту' : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) ? '$n минуты' : '$n минут';
String _ordinalNight(int n) => switch (n) { 2 => 'вторую', 3 => 'третью', 4 => 'четвёртую', 5 => 'пятую', 6 => 'шестую', 7 => 'седьмую', _ => '$n-ю' };

/// The whole feed for one day, highest priority first.
List<Observation> buildObservations(ObservationInput i) {
  final out = <Observation>[];
  final d = _day(i.now);
  final hour = i.now.hour;
  final morning = _clock(i.wakeMinOfDay ?? 7 * 60 + 30);
  void add(ObservationKind k, String rule, String title, String text, String link, String target, {int tone = 0, int priority = 50, String? time}) {
    out.add(Observation(id: '${k.name}.$rule.$d', kind: k, title: title, text: text, link: link, target: target, tone: tone, priority: priority, time: time ?? morning));
  }

  // ── RECOVERY ────────────────────────────────────────────────────────────
  if (i.recovery != null) {
    final r = i.recovery!;
    final band = r >= 67 ? 'зелёная' : r >= 34 ? 'жёлтая' : 'красная';
    final parts = <String>[];
    if (i.hrv != null && i.hrvLo != null && i.hrvHi != null) {
      final pos = i.hrv! > i.hrvHi! ? 'выше вашего диапазона ${i.hrvLo!.round()}–${i.hrvHi!.round()}' : i.hrv! < i.hrvLo! ? 'ниже вашего диапазона ${i.hrvLo!.round()}–${i.hrvHi!.round()}' : 'в вашем диапазоне ${i.hrvLo!.round()}–${i.hrvHi!.round()}';
      parts.add('ВСР ${i.hrv!.round()} мс $pos');
    }
    if (i.rhr != null && i.rhrBaseline != null) {
      final dlt = (i.rhr! - i.rhrBaseline!).round();
      parts.add('пульс в покое ${i.rhr!.round()} уд/мин${dlt == 0 ? ' на уровне нормы' : dlt < 0 ? ' на ${-dlt} ниже нормы' : ' на $dlt выше нормы'}');
    }
    final advice = r >= 67
        ? 'Организм готов к нагрузке: сегодня хороший день для тяжёлой тренировки.'
        : r >= 34
        ? 'Умеренный день: держитесь среднего диапазона нагрузки и ложитесь вовремя.'
        : 'Организм просит отдых: лёгкая активность, ранний отбой, без интенсивных тренировок.';
    add(ObservationKind.recovery, 'summary', 'Восстановление ${r.round()} % — $band зона', '${parts.isEmpty ? '' : '${parts.join(', ')}. '}$advice', 'Восстановление', 'recovery', tone: r >= 67 ? 1 : r >= 34 ? 0 : 2, priority: 90);
  }
  if (i.hrvAboveStreak >= 3 && i.hrv != null) {
    add(ObservationKind.recovery, 'hrv_streak_up', 'ВСР выше нормы ${_ordinalNight(i.hrvAboveStreak)} ночь подряд', '${i.hrv!.round()} мс${i.hrvLo != null && i.hrvHi != null ? ' при типичных ${i.hrvLo!.round()}–${i.hrvHi!.round()}' : ''}: верх вашего диапазона. Вместе с пульсом в покое${i.rhr != null ? ' ${i.rhr!.round()}' : ''} это признак хорошего восстановления и адаптации к нагрузке.', 'Тренд ВСР', 'trend-hrv', tone: 1, priority: 70);
  }
  if (i.hrvBelowStreak >= 2 && i.hrv != null) {
    add(ObservationKind.recovery, 'hrv_streak_down', 'ВСР ниже нормы ${_ordinalNight(i.hrvBelowStreak)} ночь подряд', '${i.hrv!.round()} мс${i.hrvLo != null ? ' при нижней границе ${i.hrvLo!.round()}' : ''}. Так бывает после серии тяжёлых дней, недосыпа или начала болезни. Снизьте интенсивность и добавьте сон.', 'Тренд ВСР', 'trend-hrv', tone: 2, priority: 75);
  }
  final greenStreak = _streak(i.recovery7, (v) => v >= 67);
  if (greenStreak >= 3) {
    add(ObservationKind.recovery, 'green_streak', '${greenStreak == 3 ? 'Три' : greenStreak == 4 ? 'Четыре' : greenStreak == 5 ? 'Пять' : '$greenStreak'} зелёных дня подряд', 'Серия зелёного восстановления: организм справляется с нагрузкой. Хорошее окно для прогресса в тренировках, пока сон остаётся стабильным.', 'Восстановление', 'recovery', tone: 1, priority: 55);
  }
  final redStreak = _streak(i.recovery7, (v) => v < 34);
  if (redStreak >= 2) {
    add(ObservationKind.recovery, 'red_streak', 'Красная зона ${redStreak == 2 ? 'второй' : 'третий'} день подряд', 'Два и больше красных дня подряд означают накопленную усталость. Проверьте сон, стресс и заметки в дневнике; при жаре, боли в горле или температуре это может быть болезнь.', 'Монитор здоровья', 'health-monitor', tone: 2, priority: 80);
  }
  // possible illness: RHR up, resp up, temp z up together
  final illnessSignals = <String>[];
  if (i.rhr != null && i.rhrBaseline != null && i.rhr! - i.rhrBaseline! >= 5) illnessSignals.add('пульс в покое +${(i.rhr! - i.rhrBaseline!).round()} уд/мин');
  if (i.resp != null && i.respHi != null && i.resp! > i.respHi!) illnessSignals.add('дыхание ${_d1(i.resp!)} /мин выше нормы');
  if (i.skinTempZ != null && i.skinTempZ! >= 1.5) illnessSignals.add('температура кожи заметно выше вашей нормы');
  if (i.spo2 != null && i.spo2Lo != null && i.spo2! < i.spo2Lo!) illnessSignals.add('SpO₂ ${i.spo2!.round()} % ниже нормы');
  if (illnessSignals.length >= 2) {
    add(ObservationKind.health, 'illness_watch', 'Несколько показателей отклонились одновременно', '${illnessSignals.join(', ')}. Такое сочетание часто предшествует болезни. Отдохните, пейте больше воды и следите за самочувствием; это не диагноз.', 'Монитор здоровья', 'health-monitor', tone: 2, priority: 95);
  } else if (i.monitorTotal != null && i.monitorTotal! > 0 && i.monitorInRange != null) {
    if (i.monitorOutside.isEmpty) {
      add(ObservationKind.health, 'monitor_ok', 'Все ${i.monitorTotal} показателей в вашем диапазоне', 'Дыхание, пульс в покое, ВСР${i.monitorTotal! >= 5 ? ', SpO₂ и температура' : ' и SpO₂'} в границах вашей 30-дневной нормы. Отклонений нет.', 'Монитор здоровья', 'health-monitor', tone: 1, priority: 40);
    } else {
      add(ObservationKind.health, 'monitor_out', '${i.monitorOutside.length} из ${i.monitorTotal} вне вашего диапазона', '${i.monitorOutside.join('; ')}. Одно отклонение само по себе не тревожно; посмотрите, держится ли оно завтра.', 'Монитор здоровья', 'health-monitor', tone: 2, priority: 65);
    }
  }

  // ── SLEEP ───────────────────────────────────────────────────────────────
  if (i.sleepPerf != null && i.tstMin != null) {
    final p = i.sleepPerf!;
    final lvl = p >= 85 ? 'оптимальный' : p >= 70 ? 'достаточный' : 'слабый';
    final need = i.needMin != null ? ' из потребности ${_hm(i.needMin!)}' : '';
    final weak = <String>[];
    if (i.hoursVsNeed != null && i.hoursVsNeed! < 85) weak.add('часы против потребности ${_pct(i.hoursVsNeed!)}');
    if (i.consistency != null && i.consistency! < 70) weak.add('регулярность ${_pct(i.consistency!)}');
    if (i.efficiency != null && i.efficiency! < 85) weak.add('эффективность ${_pct(i.efficiency!)}');
    if (i.sleepStressPct != null && i.sleepStressPct! > 5) weak.add('высокий стресс во сне ${_pct(i.sleepStressPct!)}');
    add(ObservationKind.sleep, 'summary', 'Показатель сна ${p.round()} % — $lvl', 'Вы спали ${_hmWords(i.tstMin!)}$need. ${weak.isEmpty ? 'Все четыре компонента в норме: часы, регулярность, эффективность и стресс во сне.' : 'Тянут вниз: ${weak.join(', ')}.'}', 'Сон', 'sleep', tone: p >= 85 ? 1 : p >= 70 ? 0 : 2, priority: 85);
  }
  if (i.debtOutstandingMin != null && i.debtOutstandingMin! >= 45 && i.today) {
    final bed = i.needTonightMin != null && i.wakeMinOfDay != null ? ' Чтобы закрыть потребность ${_hm(i.needTonightMin!)} и встать в ${_clock(i.wakeMinOfDay!)}, ложитесь до ${_clock(i.wakeMinOfDay! - i.needTonightMin!)}.' : '';
    add(ObservationKind.sleep, 'debt', 'Недосып ${_hmWords(i.debtOutstandingMin!)}', 'За последние ночи вы недоспали ${_hmWords(i.debtOutstandingMin!)} относительно своей нормы. Сегодня в потребность добавлено ${_hmWords(i.debtTonightMin ?? math.min(i.debtOutstandingMin! * .5, 90))}.$bed', 'Планировщик сна', 'tonight', tone: 2, priority: 72, time: '20:00');
  }
  if (i.hoursVsNeed != null && i.hoursVsNeed! >= 100) {
    add(ObservationKind.sleep, 'need_met', 'Потребность во сне закрыта на 100 %', 'Вы спали ${i.tstMin != null ? _hmWords(i.tstMin!) : 'достаточно'} при потребности ${i.needMin != null ? _hm(i.needMin!) : '—'}. Недосыпа нет, восстановлению это помогает больше всего.', 'Сон', 'sleep', tone: 1, priority: 45);
  }
  if (i.consistency != null) {
    if (i.consistency! < 70) {
      final shift = i.bedMinOfDay != null && i.typicalBedMinOfDay != null ? ' Вчера отбой в ${_clock(i.bedMinOfDay!)} при обычных ${_clock(i.typicalBedMinOfDay!)}.' : '';
      add(ObservationKind.sleep, 'consistency_low', 'Регулярность сна ${_pct(i.consistency!)}', 'Время отбоя и подъёма заметно гуляет относительно последних четырёх ночей.$shift Одно и то же время ±30 минут поднимает регулярность выше 80 % за неделю.', 'Тренд регулярности', 'trend-consistency', tone: 2, priority: 60);
    } else if (i.consistency! >= 85) {
      add(ObservationKind.sleep, 'consistency_high', 'Регулярность сна ${_pct(i.consistency!)}', 'Отбой и подъём почти не меняются четыре ночи подряд. Стабильный циркадный ритм — самый сильный фактор Healthspan из тех, что вы контролируете.', 'Тренд регулярности', 'trend-consistency', tone: 1, priority: 42);
    }
  }
  if (i.efficiency != null && i.efficiency! < 85 && i.awakeMin != null) {
    add(ObservationKind.sleep, 'efficiency', 'Эффективность сна ${_pct(i.efficiency!)}', 'В постели вы бодрствовали ${_hmWords(i.awakeMin!)}${i.wakeEvents != null ? ', пробуждений: ${i.wakeEvents}' : ''}. Прохладная тёмная комната и отказ от экрана за 30 минут до сна обычно поднимают эффективность выше 90 %.', 'Сон', 'sleep', tone: 2, priority: 52);
  }
  if (i.restorativeMin != null && i.restorativeBaselineMin != null && i.restorativeBaselineMin! > 0 && i.restorativeMin! < i.restorativeBaselineMin! * .8) {
    add(ObservationKind.sleep, 'restorative_low', 'Восстанавливающего сна меньше обычного', 'Глубокий + REM: ${_hm(i.restorativeMin!)} при вашей норме ${_hm(i.restorativeBaselineMin!)}. Алкоголь, поздняя еда и тяжёлая вечерняя тренировка сокращают эти стадии сильнее всего.', 'Тренд восстанавливающего сна', 'trend-restorative', tone: 2, priority: 50);
  }
  if (i.sleepStressPct != null && i.sleepStressPct! > 5) {
    add(ObservationKind.sleep, 'sleep_stress', 'Высокий стресс во сне ${_pct(i.sleepStressPct!)}', 'Больше 5 % ночи пульс держался высоко относительно вашего покоя. Часто это алкоголь, жара в спальне или поздняя тренировка.', 'Сон', 'sleep', tone: 2, priority: 48);
  }
  if (i.bedMinOfDay != null && i.typicalBedMinOfDay != null) {
    var shift = i.bedMinOfDay! - i.typicalBedMinOfDay!;
    if (shift > 720) shift -= 1440;
    if (shift < -720) shift += 1440;
    if (shift.abs() >= 60) {
      add(ObservationKind.sleep, 'bedtime_shift', 'Легли на ${_hmWords(shift.abs())} ${shift > 0 ? 'позже' : 'раньше'} обычного', 'Отбой в ${_clock(i.bedMinOfDay!)} при вашем обычном ${_clock(i.typicalBedMinOfDay!)}. Сдвиг больше часа снижает регулярность сна и на следующий день часто заметен по ВСР.', 'Регулярность', 'trend-consistency', tone: shift > 0 ? 2 : 0, priority: 44);
    }
  }
  if (i.today && i.needTonightMin != null) {
    final base = i.baselineMin != null ? 'норма ${_hm(i.baselineMin!)}' : null;
    final parts = [
      ?base,
      if (i.strainAddMin != null && i.strainAddMin! >= 5) 'нагрузка +${_hm(i.strainAddMin!)}',
      if (i.debtTonightMin != null && i.debtTonightMin! >= 5) 'недосып +${_hm(i.debtTonightMin!)}',
    ];
    final bed = i.wakeMinOfDay != null ? ' При подъёме в ${_clock(i.wakeMinOfDay!)} отбой до ${_clock(i.wakeMinOfDay! - i.needTonightMin!)} для 100 % и до ${_clock(i.wakeMinOfDay! - i.needTonightMin! * .85)} для 85 %.' : '';
    final src = i.baselineSource == 'population' ? ' Норма пока стартовая: личная появится после ${_nightsGen(math.max(1, 5 - (i.nightsForBaseline ?? 0)))} записи.' : '';
    add(ObservationKind.sleep, 'tonight', 'Сегодня потребность во сне ${_hm(i.needTonightMin!)}', '${parts.isEmpty ? '' : '${parts.join(' + ')}.'}$bed$src', 'Планировщик сна', 'tonight', priority: 58, time: '18:00');
  }

  // ── STRAIN ──────────────────────────────────────────────────────────────
  if (i.strain != null) {
    final s = i.strain!;
    final band = s >= 18 ? 'предельная' : s >= 14 ? 'высокая' : s >= 10 ? 'умеренная' : 'лёгкая';
    if (i.targetLo != null && i.targetHi != null && i.today) {
      if (s >= i.targetLo! && s <= i.targetHi!) {
        add(ObservationKind.strain, 'target_hit', 'Цель нагрузки ${_d1(i.targetLo!)}–${_d1(i.targetHi!)} достигнута', 'Нагрузка дня ${_d1(s)} — в целевом диапазоне для вашего восстановления. Дальнейшая интенсивная работа сегодня добавит усталости, а не формы.', 'Нагрузка', 'strain', tone: 1, priority: 66, time: hour >= 18 ? '18:00' : null);
      } else if (s > i.targetHi!) {
        add(ObservationKind.strain, 'target_over', 'Нагрузка выше цели: ${_d1(s)} при ${_d1(i.targetLo!)}–${_d1(i.targetHi!)}', 'Вы превысили рекомендованный диапазон на ${_d1(s - i.targetHi!)}. Сегодня потребность во сне вырастет; проверьте её в планировщике.', 'Планировщик сна', 'tonight', tone: 2, priority: 68);
      } else if (hour >= 17) {
        add(ObservationKind.strain, 'target_under', 'До цели нагрузки осталось ${_d1(i.targetLo! - s)}', 'Сейчас ${_d1(s)} при цели ${_d1(i.targetLo!)}–${_d1(i.targetHi!)}. Быстрая прогулка 30–40 минут или короткая тренировка в зонах 2–3 закроет разрыв.', 'Начать активность', 'activity-start', priority: 47, time: '17:00');
      }
    }
    if (hour >= 20 || !i.today) {
      add(ObservationKind.strain, 'summary', 'Нагрузка дня ${_d1(s)} — $band', '${i.activities > 0 ? 'Записано активностей: ${i.activities}${i.activityStrainMax != null ? ', самая тяжёлая ${_d1(i.activityStrainMax!)}' : ''}. ' : 'Без записанных активностей. '}${i.z13TodayMin != null ? 'В зонах 1–3 ${_hmWords(i.z13TodayMin!)}' : ''}${i.z45TodayMin != null && i.z45TodayMin! > 0 ? ', в зонах 4–5 ${_hmWords(i.z45TodayMin!)}' : ''}${i.z13TodayMin != null ? '.' : ''}', 'Нагрузка', 'strain', priority: 62, time: '20:00');
    }
  }
  if (i.z45TodayMin != null && i.z45WeekAvgMin != null && i.z45TodayMin! >= 15 && i.z45TodayMin! > i.z45WeekAvgMin! * 2) {
    add(ObservationKind.strain, 'z45_spike', 'Интенсивнее обычного: ${_hmWords(i.z45TodayMin!)} в зонах 4–5', 'Это больше чем вдвое выше вашего дневного среднего за неделю (${_hmWords(i.z45WeekAvgMin!)}). Восстановление завтра, скорее всего, будет ниже; планируйте лёгкий день.', 'Зоны 4–5', 'trend-zones45', tone: 0, priority: 56);
  }
  if (i.steps != null && i.stepGoal != null && i.stepGoal! > 0) {
    if (i.steps! >= i.stepGoal!) {
      add(ObservationKind.strain, 'steps_goal', 'Цель по шагам выполнена: ${_thousands(i.steps!)}', 'Больше ${_thousands(i.stepGoal!)} шагов за день. Регулярные 8–10 тысяч шагов — один из девяти факторов Healthspan.', 'Шаги', 'trend-steps', tone: 1, priority: 46, time: hour >= 12 ? null : '12:00');
    } else if (hour >= 16 && i.steps! >= i.stepGoal! * .8) {
      add(ObservationKind.strain, 'steps_close', 'До цели по шагам ${_thousands(i.stepGoal! - i.steps!)}', 'Пройдено ${_thousands(i.steps!)} из ${_thousands(i.stepGoal!)}. 15–20 минут ходьбы закроют цель.', 'Шаги', 'trend-steps', priority: 38, time: '16:00');
    }
  }
  if (i.strain != null && i.recovery != null && i.strain! >= 17 && i.recovery! < 34) {
    add(ObservationKind.strain, 'overreach', 'Высокая нагрузка при красном восстановлении', 'Нагрузка ${_d1(i.strain!)} на фоне восстановления ${i.recovery!.round()} %. Один такой день не страшен, серия ведёт к перетренированности: завтра — восстановительный день.', 'Восстановление', 'recovery', tone: 2, priority: 74);
  }

  // ── STRESS ──────────────────────────────────────────────────────────────
  if (i.longestHighStartMinOfDay != null && i.longestHighDurMin != null && i.longestHighDurMin! >= 15) {
    final share = i.highStressMin != null && i.lowStressMin != null && i.mediumStressMin != null
        ? 'Большую часть дня стресс был ${i.lowStressMin! >= i.mediumStressMin! && i.lowStressMin! >= i.highStressMin! ? 'низким' : i.mediumStressMin! >= i.highStressMin! ? 'умеренным' : 'высоким'}. '
        : '';
    add(ObservationKind.stress, 'longest_high', 'Самый длинный период высокого стресса — ${_minutes(i.longestHighDurMin!.round())}', '${share}Начался в ${_clock(i.longestHighStartMinOfDay!)} и длился ${_minutes(i.longestHighDurMin!.round())}. Если это не тренировка, отметьте в дневнике, что происходило: так проще найти источник.', 'Монитор стресса', 'stress', priority: 54, time: '17:00');
  }
  if (i.highStressMin != null && i.highTypicalMin != null && i.highStressMin! >= 30 && i.highStressMin! > i.highTypicalMin! * 1.5) {
    add(ObservationKind.stress, 'high_above_typical', 'Стресса больше обычного: ${_hmWords(i.highStressMin!)} высокого', 'Обычно в этот день недели высокого стресса у вас ${_hmWords(i.highTypicalMin!)}. ${i.breathingDoneToday ? 'Дыхательная сессия уже была сегодня.' : 'Пятиминутная дыхательная сессия снижает пульс и активацию за 2–3 минуты.'}', i.breathingDoneToday ? 'Монитор стресса' : 'Дыхательная сессия', i.breathingDoneToday ? 'stress' : 'breathing', tone: 2, priority: 57, time: '17:00');
  }
  if (i.stressNow != null && i.today && hour >= 17 && i.highStressMin != null && i.mediumStressMin != null && i.lowStressMin != null) {
    add(ObservationKind.stress, 'evening', 'Стресс за день: низкий ${_hm(i.lowStressMin!)}, умеренный ${_hm(i.mediumStressMin!)}, высокий ${_hm(i.highStressMin!)}', 'Сейчас ${_d1(i.stressNow!)} из 3. Вечером ниже 1,0 — хороший знак перед сном: ВСР ночью обычно выше.', 'Монитор стресса', 'stress', priority: 41, time: '17:00');
  }

  // ── HEALTHSPAN ──────────────────────────────────────────────────────────
  if (i.whoopAge != null && i.chronoAge != null) {
    final dlt = i.whoopAge! - i.chronoAge!;
    final paceTxt = i.pace != null ? ' Темп старения ${_d1(i.pace!)}x${i.pacePrev != null ? (i.pace! < i.pacePrev! ? ' — медленнее, чем неделю назад' : i.pace! > i.pacePrev! ? ' — быстрее, чем неделю назад' : ' — как неделю назад') : ''}.' : '';
    final factor = i.topFactor != null && i.topFactorYears != null ? ' Главный вклад: ${i.topFactor} (${i.topFactorYears! > 0 ? '+' : ''}${_d1(i.topFactorYears!)} г).' : '';
    add(ObservationKind.healthspan, 'weekly', 'Возраст организма ${_d1(i.whoopAge!)}', '${dlt <= 0 ? 'На ${_d1(-dlt)} года моложе календарного' : 'На ${_d1(dlt)} года старше календарного'}.$paceTxt$factor', 'Healthspan', 'healthspan', tone: dlt <= 0 ? 1 : 2, priority: i.now.weekday == DateTime.monday ? 64 : 36);
  }

  // ── JOURNAL ─────────────────────────────────────────────────────────────
  for (final e in i.journalEffects) {
    if (e.days < 10 || e.effect.abs() < 4) continue;
    final what = e.metric == 'sleep' ? 'показатель сна' : 'восстановление';
    add(ObservationKind.journal, 'effect_${e.tag.hashCode.toRadixString(16)}', '«${e.tag}»: $what ${e.effect > 0 ? 'выше' : 'ниже'} на ${e.effect.abs().round()} %', 'За ${_days(e.days)} с этой отметкой $what в среднем ${e.effect > 0 ? 'выше' : 'ниже'} на ${e.effect.abs().round()} %, чем без неё. Это ваша собственная статистика, не общая рекомендация.', 'Влияние привычек', 'journal-insights', tone: e.effect > 0 ? 1 : 2, priority: 43);
  }
  if (i.today && i.journalTracked && !i.journalDoneToday && hour >= 9) {
    add(ObservationKind.journal, 'fill', i.journalStreak > 0 ? 'Дневник: серия ${_days(i.journalStreak)}' : 'Заполните дневник за сегодня', i.journalStreak > 0 ? 'Отметьте сегодняшний день, чтобы не прервать серию. Через 30 дней записей появится влияние привычек на восстановление.' : 'Алкоголь, кофеин, поздняя еда, стресс — две минуты в день, и через месяц появится влияние каждой привычки на ваш сон и восстановление.', 'Дневник', 'journal', priority: 35, time: '09:00');
  }

  // ── DEVICE ──────────────────────────────────────────────────────────────
  if (i.batteryPct != null && i.batteryPct! <= 20 && !i.charging) {
    add(ObservationKind.device, 'battery', 'Заряд браслета ${i.batteryPct!.round()} %', 'На ночь может не хватить: без записи не будет сна, восстановления и ВСР. Зарядите до отбоя.', 'Браслет', 'device', tone: 2, priority: 78);
  }
  if (i.sinceSync != null && i.sinceSync!.inHours >= 6) {
    add(ObservationKind.device, 'sync', 'Нет синхронизации ${i.sinceSync!.inHours} ч', 'Данные за это время лежат на браслете. Откройте приложение рядом с ним и потяните экран вниз, чтобы забрать записи.', 'Браслет', 'device', tone: 2, priority: 60);
  }

  // ── WEEKLY (Monday) ────────────────────────────────────────────────────
  if (i.now.weekday == DateTime.monday && i.weekRecovery != null && i.prevWeekRecovery != null) {
    String dl(num a, num b, {int digits = 0}) {
      final v = a - b;
      final s = digits == 0 ? v.abs().round().toString() : _d1(v.abs());
      return v == 0 ? 'без изменений' : v > 0 ? '+$s' : '−$s';
    }

    add(ObservationKind.weekly, 'summary', 'Итоги недели', 'Восстановление ${i.weekRecovery!.round()} % (${dl(i.weekRecovery!, i.prevWeekRecovery!)} к прошлой неделе)${i.weekStrain != null && i.prevWeekStrain != null ? ', нагрузка ${_d1(i.weekStrain!)} (${dl(i.weekStrain!, i.prevWeekStrain!, digits: 1)})' : ''}${i.weekSleepPerf != null && i.prevWeekSleepPerf != null ? ', сон ${i.weekSleepPerf!.round()} % (${dl(i.weekSleepPerf!, i.prevWeekSleepPerf!)})' : ''}.', 'Тренды', 'trend-recovery', priority: 63, time: '08:00');
  }

  out.sort((a, b) => b.priority.compareTo(a.priority));
  return out;
}

int _streak(List<double?> series, bool Function(double) test) {
  var n = 0;
  for (var i = series.length - 1; i >= 0; i--) {
    final v = series[i];
    if (v == null || !test(v)) break;
    n++;
  }
  return n;
}

String _thousands(int v) {
  final s = v.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(' ');
    out.write(s[i]);
  }
  return out.toString();
}
