// Presentation only. Never use these labels as metric/DB/protocol identifiers.
import 'package:flutter/widgets.dart';

String coreText(BuildContext context, String text) => ruCoreText(text,
    locale: Localizations.maybeLocaleOf(context)?.languageCode);

String ruCoreText(String text, {String? locale}) {
  if (locale?.split(RegExp('[-_]')).first != 'ru') return text;
  final exact = ruCoreLabels[text];
  if (exact != null) return exact;
  String? result;
  void rule(String pattern, String Function(RegExpMatch) render) {
    if (result != null) return;
    final m = RegExp(pattern).firstMatch(text);
    if (m != null) result = render(m);
  }
  rule(r'^(.+) was recording$', (m) => 'Источник записи: ${m[1]}');
  rule(r'^(\d+) devices were recording$', (m) => 'Источников записи: ${m[1]}');
  rule(r'^Zone (\d+)$', (m) => 'Зона ${m[1]}');
  rule(r'^Goal (.+)$', (m) => 'Цель: ${m[1]}');
  rule(r'^Latest (.+)$', (m) => 'Последнее значение: ${ruCoreText(m[1]!, locale: locale)}');
  rule(r'^Your band was off your wrist (.+) – (.+)\.$',
      (m) => 'Браслет был снят с руки с ${m[1]} до ${m[2]}.');
  rule(r'^Showing (.+)\. Tap to switch device\.$',
      (m) => 'Показаны данные: ${m[1]}. Нажмите, чтобы сменить устройство.');
  rule(r'^No beat in the last (\d+) seconds\.$',
      (m) => 'За последние ${m[1]} с данных о пульсе не поступало.');
  rule(r'^The last (\d+) readings — (.+) bpm\. Not stored; this is the live stream, not a record of your day\.$',
      (m) => 'Последних измерений: ${m[1]}. Диапазон: ${m[2]} уд/мин. Эти данные не сохраняются: это текущий поток, а не запись вашего дня.');
  rule(r'^(.+) is not a number\. Nothing was saved\.$',
      (m) => 'В поле «${ruCoreText(m[1]!, locale: locale)}» должно быть число. Изменения не сохранены.');
  rule(r'^(.+) are not numbers\. Nothing was saved\.$',
      (m) => 'В этих полях должны быть числа: ${m[1]}. Изменения не сохранены.');
  rule(r'^(.+), unavailable$', (m) => '${ruCoreText(m[1]!, locale: locale)}, недоступно');
  rule(r'^(\d+) (day|days) ago$', (m) => '${m[1]} дн. назад');
  rule(r'^(\d+) (night|nights) ago$', (m) => '${m[1]} ноч. назад');
  rule(r'^(\d+) of (\d+)$', (m) => '${m[1]} из ${m[2]}');
  rule(r'^(.+) min · shown as (.+) min$', (m) => '${m[1]} мин · на графике: ${m[2]} мин');

  rule(r'^measured in (.+)$', (m) => 'Единица измерения: ${ruCoreText(m[1]!, locale: locale)}');
  rule(r'^from (.+) to (.+)$', (m) => 'с ${m[1]} до ${m[2]}');
  rule(r'^Key: (.+)$', (m) => 'Обозначения: ${m[1]}');
  rule(r'^ranging (.+) to (.+)$', (m) => 'диапазон: от ${ruCoreText(m[1]!, locale: locale)} до ${ruCoreText(m[2]!, locale: locale)}');
  rule(r'^roughly level across (\d+) readings$', (m) => 'без заметного изменения по ${m[1]} измерениям');
  rule(r'^(up|down) (.+) across (\d+) readings$', (m) => '${m[1] == 'up' ? 'рост' : 'снижение'} на ${ruCoreText(m[2]!, locale: locale)} по ${m[3]} измерениям');
  rule(r'^Provider error \((\d+)\): (.+)$', (m) => 'Ошибка сервиса ИИ (${m[1]}): ${m[2]}');
  rule(r'^Models request failed \((\d+)\): (.+)$', (m) => 'Не удалось получить список моделей (${m[1]}): ${m[2]}');
  rule(r'^(\d+) points$', (m) {
    final n = int.parse(m[1]!);
    final word = n % 100 >= 11 && n % 100 <= 14 ? 'баллов' : n % 10 == 1 ? 'балл' : n % 10 >= 2 && n % 10 <= 4 ? 'балла' : 'баллов';
    return '${m[1]} $word';
  });
  rule(r'^Rendering (.+)…$', (m) => 'Подготавливаю визуализацию…');
  if (result != null) return result!;
  final compactMs = RegExp(r'^([+−–\-]?\d+(?:[.,]\d+)?)\s*ms(²)?$').firstMatch(text);
  if (compactMs != null) return '${compactMs[1]} мс${compactMs[2] ?? ''}';
  if (text.contains('m/s')) return text;
  // Numeric display suffixes only: no substring translation of prose, names,
  // recorded notes, URLs or canonical fields. The number stays byte-for-byte.
  if (RegExp(r'^[+−–\-\d.,%: /hmsbpkcalinrvetof≈<>±()]+$').hasMatch(text) ||
      RegExp(r'^[+−–\-\d.,: /]+ (bpm avg|bpm|ms|br/min|min|kcal|steps|points|h|s)$').hasMatch(text)) {
    return text
        .replaceAll(RegExp(r'\bbpm avg\b'), 'уд/мин в среднем')
        .replaceAll('br/min', 'дых./мин')
        .replaceAll(RegExp(r'\bbpm\b'), 'уд/мин')
        .replaceAll(RegExp(r'\bms\b'), 'мс')
        .replaceAll(RegExp(r'\bmin\b'), 'мин')
        .replaceAll(RegExp(r'\bkcal\b'), 'ккал')
        .replaceAll(RegExp(r'\bsteps\b'), 'шагов')
        .replaceAll(RegExp(r'\bpoints\b'), 'баллов')
        .replaceAllMapped(RegExp(r'(\d)h(?=\s|$)'), (m) => '${m[1]} ч')
        .replaceAllMapped(RegExp(r'(\d)m(?=\s|$)'), (m) => '${m[1]} мин')
        .replaceAll(RegExp(r'\bh\b'), 'ч')
        .replaceAll(RegExp(r'\bs\b'), 'с');
  }
  return text;
}

const ruCoreLabels = <String,String>{
  'Unexpected response from provider.':'Неожиданный ответ сервиса ИИ.',
  'Empty response from provider.':'Сервис ИИ вернул пустой ответ.',
  'Add your AI key to use the journal chat.':'Добавьте свой ключ API, чтобы вести дневник с помощью ИИ.',

  'rel':'отн. ед.', 'lower than usual':'ниже обычного', 'higher than usual':'выше обычного', 'within your usual range':'в обычном для вас диапазоне',
  'AN-2554 pedometer · phone pedometer (HealthKit / Health Connect)':'Алгоритм шагомера AN-2554 · шагомер телефона (HealthKit / Health Connect)',
  'Reading your overnight RR…':'Читаю интервалы между ударами сердца за ночь…',
  'Doing the Banister math…':'Рассчитываю нагрузку по модели Банистера…',
  'Asking your heart rate a few questions…':'Изучаю данные о пульсе…',
  'Decoding last night…':'Разбираюсь в данных за прошлую ночь…',
  'Auditing 90 days of you…':'Изучаю ваши данные за 90 дней…',
  'Letting the data confess…':'Смотрю, что говорят данные…',
  'Lining up the z-scores…':'Сопоставляю отклонения от ваших обычных значений…',
  'Chasing a hunch through your HRV…':'Проверяю предположение по данным ВСР…',
  'Pulling the thread…':'Ищу взаимосвязи…',
  'Querying your data…':'Запрашиваю ваши данные…',
  'Reading your food log…':'Читаю дневник питания…',
  'Reading your medications…':'Читаю список препаратов…',
  'Plotting…':'Строю график…', 'Working…':'Обрабатываю…',
  'Log journal':'Записать в дневник', 'Log period':'Отметить начало менструации',
  'Start workout':'Начать тренировку', 'End workout':'Завершить тренировку',
  'Log food':'Записать приём пищи', 'Log how the day went':'Записать итоги дня',
  'Log a workout':'Записать тренировку', 'Add a medication':'Добавить препарат',
  'Mark a dose':'Отметить приём препарата', 'Set step goal':'Задать цель по шагам',
  'OpenStrap could not start':'Не удалось запустить OpenStrap',
  'Your data is still on this device — nothing was deleted. This is a start-up step failing, and it will fail the same way each launch until it is fixed.':'Данные по-прежнему на этом устройстве — ничего не удалено. Ошибка возникла при запуске и будет повторяться, пока её причина не устранена.',
  'No error was recorded.':'Сведения об ошибке отсутствуют.',
  'Try again':'Повторить попытку',
  'Finish the session that is still running':'Завершить текущую тренировку',
  'Session running — tap to finish':'Тренировка идёт — нажмите, чтобы завершить',
  'Session running':'Тренировка идёт',
  'Nothing selected':'Ничего не выбрано', 'No data yet':'Пока нет данных',
  'No data for this day':'Нет данных за этот день',
  'Nothing was recorded on this day.':'За этот день ничего не записано.',
  'an improvement':'улучшение', 'worse than usual':'хуже обычного',
  'trending up':'растёт', 'trending down':'снижается', 'steady':'без заметных изменений',
  'no trend yet, not enough days recorded':'для оценки динамики пока мало дней с данными',
  'HEALTH OBSERVATION':'НАБЛЮДЕНИЕ О ЗДОРОВЬЕ', 'View data':'Посмотреть данные',
  'Remove':'Удалить', 'Keep it':'Оставить', 'Back':'Назад', 'Goal':'Цель',
  'Save step goal':'Сохранить цель по шагам', 'Edit daily step goal':'Изменить цель по шагам',
  'A step goal of 500–100,000 is a real one. Nothing was saved.':'Укажите цель от 500 до 100 000 шагов. Изменения не сохранены.',
  'Today':'Сегодня', 'Yesterday':'Вчера', 'Tomorrow':'Завтра',
  'Home':'Сегодня', 'Health':'Здоровье', 'Nutrition':'Питание', 'Workout':'Тренировки', 'Wellness':'Самочувствие',
  'Awake':'Бодрствование', 'REM':'Быстрый сон', 'Light':'Лёгкий сон', 'Deep':'Глубокий сон',
  'LF power':'Мощность LF', 'HF power':'Мощность HF',
  'LIVE':'СЕЙЧАС', 'No live reading':'Нет текущих измерений',
  'No band is paired.':'Браслет ещё не сопряжён.',
  'Pair one from Profile to read live beats.':'Подключите браслет в разделе «Профиль», чтобы видеть текущий пульс.',
  'Your band is not connected.':'Браслет не подключён.',
  'Live beats need an open link — the app connects when you open it with the band in range.':'Для текущего пульса нужно соединение с браслетом. Откройте приложение, когда браслет находится рядом.',
  'The band streams while it is on your wrist and the app is open.':'Браслет передаёт текущие данные, пока он на руке, а приложение открыто.',
  'no night loaded':'данные за ночь не загружены', 'hour of day':'час суток', 'shape only':'только форма кривой',
  'no data in this range':'нет данных за этот период', 'the default source':'источник по умолчанию',
  'an import':'импорт', 'SLEEPING HR':'ПУЛЬС ВО СНЕ', 'LOWEST':'МИНИМУМ', 'BREATHING':'ДЫХАНИЕ',
  'Heart rate':'Пульс', 'HRV':'ВСР', 'Breathing':'Дыхание', 'Skin temp':'Температура кожи',
  'Through the night':'В течение ночи', 'Resting heart rate':'Пульс в покое',
  'Breathing rate':'Частота дыхания', 'Skin temperature':'Температура кожи',
  'Readiness':'Готовность к нагрузке', 'Recovery':'Восстановление', 'Strain':'Нагрузка',
  'Sleep':'Сон', 'Time asleep':'Длительность сна', 'Steps':'Шаги', 'Active energy':'Активные калории',
  'Stress':'Стресс', 'Heart-rate recovery':'Восстановление пульса', 'Wear time':'Время ношения',
  'Movement minutes':'Минуты движения', 'Not measured':'Нет измерений', 'Not enough data':'Недостаточно данных',
  'bpm':'уд/мин', 'ms':'мс', 'br/min':'дых./мин', 'min':'мин', 'kcal':'ккал',
  'steps':'шаги', 'points':'баллы', 'h':'ч', 's':'с', 'score':'баллы',
  'Request timeout (seconds)':'Ожидание ответа (секунды)',
  'The API key was cleared because the endpoint changed.':'Ключ API удалён, потому что изменился адрес сервера.',
  'A local model can take a while to load before its first reply. Default is 5 minutes (300s). Cloud providers use a fixed 2-minute timeout and are not affected by this.':'Локальной модели может потребоваться время на загрузку перед первым ответом. По умолчанию ожидание — 5 минут (300 с). Для облачных провайдеров оно фиксировано — 2 минуты; эта настройка на них не влияет.',
};
