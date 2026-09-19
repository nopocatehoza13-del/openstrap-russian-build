import 'package:flutter/widgets.dart';

/// Presentation only. Never use translated names as workout/exercise IDs or
/// feed translated units back into calculations, storage, or filtering keys.
String activityText(BuildContext context, String text) => ruActivityText(text,
    locale: Localizations.maybeLocaleOf(context)?.languageCode);

String ruActivityText(String text, {String? locale}) {
  if (locale?.split(RegExp('[-_]')).first != 'ru') return text;
  final exact = _ru[text] ?? _caseInsensitive[text.toLowerCase()] ??
      _caseInsensitive[text.toLowerCase().replaceAll('_', ' ')];
  if (exact != null) return exact;
  final laps = RegExp(r'^(\d+) laps$').firstMatch(text);
  if (laps != null) {
    final n = int.parse(laps[1]!);
    final noun = _count(n, 'отрезок', 'отрезка', 'отрезков');
    return '$n $noun';
  }
  final elevation = RegExp(r'^([+−\-\d,.]+) m elevation$').firstMatch(text);
  if (elevation != null) return '${elevation[1]} м набора высоты';
  // Bounded suffixes emitted by the activity stat formatters, not prose or
  // user-entered activity/food names. All numeric text stays byte-for-byte.
  return text
      .replaceAll('bpm in 60', 'уд/мин за 60')
      .replaceAll('of 10', 'из 10')
      .replaceAll(RegExp(r'/mi\b'), '/милю')
      .replaceAllMapped(
          RegExp(r'\b(ml/kg/min|breaths/min|br/min|kcal|bpm|km|mi|kg|lb|ms|min|ml|g|m|s|L)\b'),
          (m) => _ru[m[0]] ?? m[0]!);
}

/// Search accepts both the display name and the original name. Matching a
/// translated label never changes the Activity instance returned by a picker.
bool activityNameMatches(String name, String query, {String? locale}) {
  final q = query.trim().toLowerCase().replaceAll('ё', 'е');
  return name.toLowerCase().contains(q) ||
      ruActivityText(name, locale: locale)
          .toLowerCase().replaceAll('ё', 'е').contains(q);
}

String _count(int n, String one, String few, String many) {
  final tens = n.abs() % 100;
  if (tens >= 11 && tens <= 14) return many;
  return switch (n.abs() % 10) { 1 => one, 2 || 3 || 4 => few, _ => many };
}

/// Local clock, no timezone conversion. The caller keeps its existing English
/// formatter when the active language is not Russian.
String russianActivityDate(DateTime t, {String separator = ' • '}) {
  const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
  return '${t.day} ${months[t.month - 1]} ${t.year}$separator'
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

final _caseInsensitive = {for (final e in _ru.entries) e.key.toLowerCase(): e.value};

const _ru = <String, String>{
  'Cardio': 'Кардио', 'Strength': 'Силовые', 'Sports': 'Виды спорта',
  'Athletics': 'Лёгкая атлетика', 'Outdoor': 'На природе',
  'Mind & body': 'Тело и осознанность', 'Everyday': 'Повседневная активность',
  'Other': 'Другое', 'Workout': 'Тренировка',
  'Running': 'Бег', 'Trail running': 'Трейлраннинг', 'Walking': 'Ходьба',
  'Hiking': 'Пеший поход', 'Cycling': 'Велоспорт', 'Indoor bike': 'Велотренажёр',
  'Rowing': 'Гребля', 'Swimming': 'Плавание', 'Elliptical': 'Эллипсоид',
  'Stair climber': 'Лестничный тренажёр', 'Treadmill': 'Беговая дорожка',
  'Jump rope': 'Прыжки со скакалкой', 'Weight training': 'Силовая тренировка',
  'Powerlifting': 'Пауэрлифтинг', 'Bodyweight': 'С собственным весом',
  'Calisthenics': 'Калистеника', 'Kettlebell': 'Тренировка с гирями',
  'CrossFit': 'Кроссфит', 'HIIT': 'Высокоинтенсивные интервалы',
  'Circuit training': 'Круговая тренировка', 'Functional': 'Функциональная тренировка',
  'Football': 'Футбол', 'Basketball': 'Баскетбол', 'Cricket': 'Крикет',
  'Tennis': 'Теннис', 'Badminton': 'Бадминтон', 'Table tennis': 'Настольный теннис',
  'Squash': 'Сквош', 'Volleyball': 'Волейбол', 'Hockey': 'Хоккей',
  'Baseball': 'Бейсбол', 'Rugby': 'Регби', 'Golf': 'Гольф', 'Bowling': 'Боулинг',
  'Boxing': 'Бокс', 'Martial arts': 'Боевые искусства', 'Wrestling': 'Борьба',
  'Climbing': 'Скалолазание', 'Sprinting': 'Спринт', 'Track intervals': 'Интервальный бег',
  'Cross country': 'Кросс', 'Hurdles': 'Бег с барьерами', 'Long jump': 'Прыжки в длину',
  'Shot put': 'Толкание ядра', 'Javelin': 'Метание копья', 'Pole vault': 'Прыжки с шестом',
  'Mountain biking': 'Горный велосипед', 'Kayaking': 'Каякинг', 'Surfing': 'Сёрфинг',
  'Paddleboard': 'Сапбординг', 'Skiing': 'Лыжи', 'Snowboarding': 'Сноуборд',
  'Skating': 'Катание на коньках и роликах', 'Horse riding': 'Верховая езда',
  'Yoga': 'Йога', 'Pilates': 'Пилатес', 'Stretching': 'Растяжка',
  'Mobility': 'Подвижность суставов', 'Tai chi': 'Тайцзи',
  'Breathwork': 'Дыхательная практика', 'Meditation': 'Медитация',
  'Housework': 'Домашние дела', 'Gardening': 'Работа в саду',
  'Dog walking': 'Прогулка с собакой', 'Childcare': 'Уход за ребёнком',
  'DIY': 'Ремонт и работа по дому', 'Shopping': 'Поход за покупками',
  'Stairs': 'Ходьба по лестнице', 'General workout': 'Другая тренировка',
  'Dancing': 'Танцы', 'Intimacy': 'Интимная близость',
  'Physiotherapy': 'Физическая реабилитация', 'Sauna': 'Сауна',
  'Cold plunge': 'Холодная купель',
  // HealthKit / Health Connect import titles; only display values, not the
  // source enum or imported record's kind. Title case is matched above.
  'American football': 'Американский футбол', 'Archery': 'Стрельба из лука',
  'Australian football': 'Австралийский футбол', 'Biking': 'Велоспорт',
  'Cardio dance': 'Танцевальная кардиотренировка',
  'Cross country skiing': 'Беговые лыжи', 'Curling': 'Кёрлинг',
  'Downhill skiing': 'Горные лыжи', 'Fencing': 'Фехтование',
  'Gymnastics': 'Гимнастика', 'Handball': 'Гандбол',
  'High intensity interval training': 'Высокоинтенсивные интервалы',
  'Kickboxing': 'Кикбоксинг', 'Racquetball': 'Ракетбол', 'Sailing': 'Парусный спорт',
  'Soccer': 'Футбол', 'Softball': 'Софтбол', 'Stair climbing': 'Ходьба по лестнице',
  'Water polo': 'Водное поло', 'Barre': 'Барре', 'Cooldown': 'Заминка',
  'Core training': 'Тренировка мышц кора', 'Cross training': 'Кросс-тренинг',
  'Disc sports': 'Спорт с летающим диском', 'Equestrian sports': 'Конный спорт',
  'Fishing': 'Рыбалка', 'Fitness gaming': 'Фитнес-игры', 'Flexibility': 'Развитие гибкости',
  'Functional strength training': 'Функциональная силовая тренировка',
  'Hand cycling': 'Ручной велоспорт', 'Hunting': 'Охота', 'Lacrosse': 'Лакросс',
  'Mind and body': 'Тело и осознанность', 'Mixed cardio': 'Смешанная кардиотренировка',
  'Paddle sports': 'Гребные виды спорта', 'Pickleball': 'Пиклбол', 'Play': 'Подвижные игры',
  'Preparation and recovery': 'Подготовка и восстановление',
  'Snow sports': 'Зимние виды спорта', 'Social dance': 'Социальные танцы',
  'Step training': 'Степ-аэробика', 'Track and field': 'Лёгкая атлетика',
  'Traditional strength training': 'Классическая силовая тренировка',
  'Water fitness': 'Аквафитнес', 'Water sports': 'Водные виды спорта',
  'Wheelchair run pace': 'Тренировка на коляске в беговом темпе',
  'Wheelchair walk pace': 'Прогулка на коляске',
  'Underwater diving': 'Подводное плавание', 'Biking stationary': 'Велотренажёр',
  'Frisbee disc': 'Фрисби', 'Guided breathing': 'Дыхание по подсказкам',
  'Ice skating': 'Катание на коньках', 'Paragliding': 'Парапланеризм',
  'Rock climbing': 'Скалолазание', 'Rowing machine': 'Гребной тренажёр',
  'Running treadmill': 'Бег на дорожке', 'Scuba diving': 'Дайвинг',
  'Snowshoeing': 'Ходьба на снегоступах',
  'Stair climbing machine': 'Лестничный тренажёр', 'Strength training': 'Силовая тренировка',
  'Swimming open water': 'Плавание на открытой воде', 'Swimming pool': 'Плавание в бассейне',
  'Walking treadmill': 'Ходьба на дорожке', 'Weightlifting': 'Тяжёлая атлетика',
  'Wheelchair': 'Активность на коляске',
  'Bench press': 'Жим лёжа', 'Incline DB press': 'Жим гантелей на наклонной скамье',
  'Cable fly': 'Сведение рук в кроссовере', 'Overhead press': 'Жим над головой',
  'Triceps pushdown': 'Разгибание рук на блоке',
  'Overhead extension': 'Разгибание рук из-за головы',
  'Barbell row': 'Тяга штанги в наклоне', 'Lat pulldown': 'Тяга верхнего блока',
  'Pull-up': 'Подтягивания', 'Barbell curl': 'Сгибание рук со штангой',
  'Back squat': 'Приседания со штангой на спине',
  'Front squat': 'Фронтальные приседания', 'Deadlift': 'Становая тяга',
  'Romanian deadlift': 'Румынская тяга', 'Hip thrust': 'Ягодичный мост с упором на скамью',
  'Leg press': 'Жим ногами', 'Plank': 'Планка',
  'Hanging leg raise': 'Подъём ног в висе',
  'chest': 'грудь', 'triceps': 'трицепс', 'shoulders': 'плечи',
  'core': 'кор', 'back': 'спина', 'biceps': 'бицепс', 'legs': 'ноги', 'glutes': 'ягодицы',
  'Time': 'Время', 'Distance': 'Расстояние', 'Pace': 'Темп', 'Steps': 'Шаги',
  'Heart rate': 'Пульс', 'Calories': 'Калории', 'Elevation': 'Набор высоты',
  'Volume': 'Тоннаж', 'Sets': 'Подходы', 'Laps': 'Отрезки', 'Reps': 'Повторения',
  'Rounds': 'Раунды', 'Poses': 'Позы', 'Breathing': 'Дыхание',
  'Hard minutes': 'Минуты высокой нагрузки', 'Strain': 'Нагрузка',
  'Avg HR': 'Средний пульс', 'Max HR': 'Максимальный пульс',
  'HR recovery': 'Восстановление пульса', 'VO2max (est.)': 'VO₂max (оценка)',
  'Your rating': 'Ваша оценка', 'Route': 'Маршрут', 'Sets and load': 'Подходы и вес',
  'Intervals': 'Интервалы', 'Flow': 'Практика', 'Effort': 'Усилие', 'Session': 'Занятие',
  'Start': 'Начало', 'minutes': 'минуты', 'seconds': 'секунды',
  'seconds per lap': 'секунд на отрезок', 'Volume of the loaded sets': 'Тоннаж подходов с весом',
  'Total volume': 'Общий тоннаж', 'Warm-up': 'Разминка', 'Easy': 'Лёгкая нагрузка',
  'Aerobic': 'Аэробная', 'Threshold': 'Пороговая', 'Max effort': 'Максимальная нагрузка',
  'kcal': 'ккал', 'bpm': 'уд/мин', 'km': 'км', 'mi': 'мили', 'kg': 'кг', 'lb': 'фунт.',
  'ms': 'мс', 'min': 'мин', 'm': 'м', 's': 'с', 'ml': 'мл', 'g': 'г', 'L': 'л',
  'br/min': 'дых/мин', 'breaths/min': 'дых/мин', 'ml/kg/min': 'мл/кг/мин',
  'unknown': 'неизвестно', 'Open Database License': 'Лицензия Open Database License',
  'Contains information from Open Food Facts, available under the Open Database License.':
      'Используются данные Open Food Facts, доступные по лицензии Open Database License.',
  '© OpenStreetMap contributors': '© Участники OpenStreetMap',
  'MET value × your weight, refined by heart rate — or heart rate alone, for an activity that carries no MET.':
      'Значение MET × ваш вес с уточнением по пульсу. Для активности без значения MET — оценка только по пульсу.',
};
