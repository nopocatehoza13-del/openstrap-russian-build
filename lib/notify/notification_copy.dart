// Translate only shipped notification templates, at the final presentation boundary.
// The event, routing, ids, dedupe keys, gates and scheduling times are untouched.
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/ru_observations_extra.dart' show findingObservationText;

Future<String> notificationLanguage() async {
  String? override;
  try {
    override = (await SharedPreferences.getInstance()).getString(
      'locale_override',
    );
  } catch (_) {
    // A headless/test engine may have no preferences channel yet.
  }
  if (override != null && override.isNotEmpty) {
    return override.split(RegExp('[-_]')).first;
  }
  try {
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    return locales.isEmpty ? 'en' : locales.first.languageCode;
  } catch (_) {
    return 'en';
  }
}

String notificationText(String text, {required String language}) {
  if (language.split(RegExp('[-_]')).first != 'ru') return text;
  text = findingObservationText(text, language);
  final exact = russianNotificationLabels[text];
  if (exact != null) return exact;
  String? result;
  void rule(String pattern, String Function(RegExpMatch) render) {
    if (result != null) return;
    final match = RegExp(pattern).firstMatch(text);
    if (match != null) result = render(match);
  }

  rule(
    r'^Your band is at (\d+)%\. Charge it soon\.$',
    (m) => 'Заряд браслета — ${m[1]}%. Скоро потребуется зарядка.',
  );
  rule(
    r'^Recovery (\d+)(, slept (\d+)h (\d+)m)?\.$',
    (m) =>
        'Восстановление: ${m[1]}${m[3] == null ? '' : ', сон: ${m[3]} ч ${m[4]} мин'}.',
  );
  rule(
    r'^You hit about (\d+) steps — at or above your (\d+) goal\.$',
    (m) =>
        'Пройдено около ${m[1]} шагов — цель в ${m[2]} шагов достигнута или превышена.',
  );
  rule(
    r'^Your bedtime is around (\d{2}:\d{2})\. Start slowing down\.$',
    (m) =>
        'Обычно вы ложитесь около ${m[1]}. Пора постепенно готовиться ко сну.',
  );
  rule(
    r'^No new data for about (\d+) hours\. Open OpenStrap to reconnect — background sync may have stalled\.$',
    (m) =>
        'Новых данных нет уже около ${m[1]} ч. Откройте OpenStrap для повторного подключения: возможно, фоновая синхронизация остановилась.',
  );
  rule(
    r'^Nothing above resting effort has been recorded for (\d+) minutes\. If the session is over, finish it from the Workout tab\.$',
    (m) =>
        'За последние ${m[1]} мин нагрузка не поднималась выше уровня покоя. Если тренировка закончилась, завершите её на вкладке «Тренировка».',
  );
  rule(
    r'^We spotted ~([\d.]+) min of elevated activity\. Tap to log it\.$',
    (m) =>
        'Обнаружено около ${m[1]} мин повышенной активности. Нажмите, чтобы записать тренировку.',
  );
  rule(
    r'^(\d+) things to look at$',
    (m) => 'Поводов обратить внимание: ${m[1]}',
  );
  rule(
    r"^At ([\d.]+)%/h it runs out around (\d{2}:\d{2}) — before you wake\. Charge it now to keep tonight's sleep\.$",
    (m) =>
        'При расходе ${m[1]}%/ч заряд закончится примерно в ${m[2]} — до вашего пробуждения. Зарядите браслет сейчас, чтобы не прерывать запись сна.',
  );
  rule(
    r"^At ([\d.]+)%/h it runs out around (\d{2}:\d{2}), just after your usual wake time — about (\d+)% left when you get up\. Charge it now to keep tonight's sleep\.$",
    (m) =>
        'При расходе ${m[1]}%/ч заряд закончится примерно в ${m[2]}, вскоре после обычного времени подъёма. К пробуждению останется около ${m[3]}%. Зарядите браслет сейчас, чтобы не прерывать запись сна.',
  );
  rule(
    r'^At ([\d.]+)%/h it runs out around (\d{2}:\d{2}), after your usual wake time\.$',
    (m) =>
        'При расходе ${m[1]}%/ч заряд закончится примерно в ${m[2]}, после вашего обычного времени подъёма.',
  );
  // Unknown user/AI-authored content and original technical details are not
  // rewritten using guesses or substring substitutions.
  return result ?? text;
}

const russianNotificationLabels = <String, String>{
  'Charging': 'Идёт зарядка',
  'Low battery': 'Низкий заряд',
  'Your recovery is ready': 'Оценка восстановления готова',
  'Step goal reached': 'Цель по шагам достигнута',
  'Time to move': 'Пора подвигаться',
  'You’ve been in a typing posture for over 90 minutes without walking.':
      'Вы больше 90 минут находитесь в позе, характерной для работы за клавиатурой, без ходьбы.',
  "You've been still for a couple of hours.":
      'Вы почти не двигались последние пару часов.',
  'Charge your strap before bed': 'Зарядите браслет перед сном',
  'Alarm not confirmed': 'Будильник не подтверждён',
  'The band did not confirm this alarm — check the strap.':
      'Браслет не подтвердил установку будильника — проверьте его.',
  'Alarm': 'Будильник',
  'Your strap alarm just fired.': 'На браслете сработал будильник.',
  'Still working out?': 'Тренировка ещё идёт?',
  "Your band hasn't synced in a while": 'Браслет давно не синхронизировался',
  'Did you work out?': 'Это была тренировка?',
  'No alarm set for tonight': 'Будильник на ближайшее утро не установлен',
  'You have no wake alarm armed for tonight.':
      'На ближайшее утро у вас не включён будильник.',
  'Medication': 'Приём лекарства',
  'A dose is due.': 'Пора принять лекарство.',
  'How was today?': 'Как прошёл день?',
  'Mood, energy, stress — a minute of it.':
      'Настроение, энергия, стресс — уделите минуту записи в дневнике.',
  'Water': 'Вода',
  'Tap to log a glass.': 'Нажмите, чтобы записать стакан воды.',
  'Wind down': 'Подготовка ко сну',
  'Your week in review': 'Итоги недели',
  'Device alerts': 'Уведомления устройства',
  'Band battery and charging': 'Заряд батареи и зарядка браслета',
  'Health alerts': 'Уведомления о здоровье',
  'Illness, unusual physiology and temperature signals':
      'Признаки болезни и необычные изменения физиологических показателей и температуры',
  'Recovery': 'Восстановление',
  'Daily recovery readiness from your own data':
      'Ежедневная оценка восстановления по вашим данным',
  'Reminders': 'Напоминания',
  'Wind-down, movement nudges, goals and weekly recaps':
      'Подготовка ко сну, разминки, цели и итоги недели',
};
