// Presentation-only Russian for dynamic observations and shipped catalogues.
// Never translate identifiers, persisted values, user-authored labels or notes.
import '../ai/nightly_sweep.dart';
import '../compute/findings.dart';
import '../data/journal_fields.dart';
import '../data/lab_catalogue.dart';
import '../data/med_store.dart';

bool observationsUseRussian(String? locale) =>
    locale?.toLowerCase().split(RegExp('[-_]')).first == 'ru';

String observationCopy(String english, String russian, String? locale) =>
    observationsUseRussian(locale) ? russian : english;

/// Labels emitted by the pinned analytics chronotype formatter; no re-banding.
String chronotypeObservationLabel(String label, String? locale) =>
    !observationsUseRussian(locale)
    ? label
    : const {
            'early type': 'Ранний тип',
            'moderate early type': 'Умеренно ранний тип',
            'slight early type': 'Ближе к раннему типу',
            'intermediate type': 'Промежуточный тип',
            'moderate evening type': 'Умеренно вечерний тип',
            'slight evening type': 'Ближе к вечернему типу',
            'evening type': 'Вечерний тип',
          }[label] ??
          label;

String stressObservationLabel(String label, String? locale) =>
    !observationsUseRussian(locale)
    ? label
    : const {
            'low': 'Низкий',
            'normal': 'Обычный',
            'elevated': 'Повышенный',
            'high': 'Высокий',
            'Low': 'Низкий',
            'Normal': 'Обычный',
            'Elevated': 'Повышенный',
            'High': 'Высокий',
          }[label] ??
          label;

const _journalNames = {
  'mood': 'Настроение',
  'sleep_quality': 'Качество сна',
  'energy': 'Энергия',
  'stress': 'Стресс',
  'soreness': 'Боль в мышцах',
  'water_ml': 'Вода',
  'caffeine_mg': 'Кофеин',
  'alcohol_units': 'Алкоголь',
  'screens_min': 'Экранное время перед сном',
  'weight_kg': 'Вес',
  'caffeine_last_min': 'Время последнего приёма кофеина',
};

String journalFieldLabel(JournalFieldSpec spec, String? locale) => spec.custom
    ? spec.label
    : journalInsightField(spec.key, spec.label, locale);

String journalInsightField(String key, String fallback, String? locale) =>
    observationsUseRussian(locale) ? _journalNames[key] ?? fallback : fallback;

const _tags = {
  'caffeine': 'Кофеин',
  'alcohol': 'Алкоголь',
  'late meal': 'Поздний приём пищи',
  'stress': 'Стресс',
  'poor sleep': 'Плохой сон',
  'travel': 'Поездка',
  'screens late': 'Экраны допоздна',
  'meds': 'Препараты',
  'sick': 'Болезнь',
  'sauna': 'Сауна',
  'cold plunge': 'Погружение в холодную воду',
  'social': 'Общение',
  'workout': 'Тренировка',
  'rest day': 'День отдыха',
};

/// Keys are retained by the caller for selection/save; only chip text changes.
String journalTagLabel(String tag, String? locale) =>
    observationsUseRussian(locale) ? _tags[tag] ?? tag : tag;

String observationUnit(String unit, String? locale) {
  if (!observationsUseRussian(locale)) return unit;
  return const {
        'bpm': 'уд/мин',
        'br/min': 'дых./мин',
        'SD': 'ст. откл.',
        'ms': 'мс',
        'ms²': 'мс²',
        'min': 'мин',
        'minutes': 'мин',
        'h': 'ч',
        'hours': 'ч',
        's': 'с',
        'sec': 'с',
        'ml': 'мл',
        'mL': 'мл',
        'mg': 'мг',
        'g': 'г',
        'kg': 'кг',
        'lb': 'фунт',
        'lbs': 'фунт',
        'unit': 'ед.',
        'units': 'ед.',
        'g/dL': 'г/дл',
        'ng/mL': 'нг/мл',
        'mg/dL': 'мг/дл',
        'µIU/mL': 'мкМЕ/мл',
        'mIU/L': 'мМЕ/л',
        'ng/dL': 'нг/дл',
        'µg/dL': 'мкг/дл',
        'pg/mL': 'пг/мл',
        'mg/L': 'мг/л',
        'U/L': 'Ед/л',
        'mL/min/1.73m²': 'мл/мин/1,73 м²',
        'min past midnight': 'мин после полуночи',
      }[unit] ??
      unit;
}

String journalFieldValue(JournalFieldSpec spec, double value, String? locale) {
  if (spec.custom || !observationsUseRussian(locale)) {
    return spec.formatWithUnit(value);
  }
  final unit = observationUnit(spec.unit, locale);
  return unit.isEmpty ? spec.format(value) : '${spec.format(value)} $unit';
}

String journalOutcomeLabel(String key, String fallback, String? locale) =>
    observationsUseRussian(locale)
    ? const {
            'readiness': 'Восстановление',
            'rmssd': 'ВСР',
            'rhr': 'Пульс в покое',
            'efficiency': 'Эффективность сна',
          }[key] ??
          fallback
    : fallback;

String medicationDoseLabel(MedDef def, String? locale) {
  if (!observationsUseRussian(locale)) return def.doseLabel;
  if (def.doseValue == null && def.doseUnit.isEmpty) return 'По назначению';
  final unit = observationUnit(def.doseUnit, locale);
  final value = def.doseValue;
  if (value == null) return unit;
  final n = value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();
  return unit.isEmpty ? n : '$n $unit';
}

String findingTitle(Finding f, String? locale) {
  if (!observationsUseRussian(locale)) return f.title;
  return switch (f.kind) {
    FindingKind.illness => 'Возможное начало болезни',
    FindingKind.anomaly => 'Необычные ночные показатели',
    FindingKind.tempElevated => 'Температура кожи повышена',
    FindingKind.irregularRhythm => 'Нерегулярный сердечный ритм — скрининг',
    FindingKind.lowReadiness => 'Сегодня низкая готовность к нагрузке',
    FindingKind.rhrShift => 'Изменилась динамика пульса в покое',
  };
}

String findingDetail(Finding f, String? locale) {
  if (!observationsUseRussian(locale)) return f.detail;
  return switch (f.kind) {
    FindingKind.illness =>
      'В последние ночи пульс в покое повышен, а ВСР снижена.',
    FindingKind.anomaly =>
      'Ночные показатели отклоняются от вашего исходного уровня.',
    FindingKind.tempElevated =>
      'Устойчивое повышение относительно вашего исходного уровня '
          'может быть признаком болезни.',
    FindingKind.irregularRhythm =>
      'Сегодня интервалы между ударами сердца выглядели '
          'нерегулярными. Это скрининг, а не диагноз. Если есть симптомы, обратитесь к врачу.',
    FindingKind.lowReadiness =>
      'Показатели восстановления ниже вашего обычного диапазона. '
          'Снизьте нагрузку.',
    FindingKind.rhrShift =>
      'Ваш пульс в покое заметно '
          '${f.risen == false ? 'снизился' : 'повысился'} относительно недавнего исходного уровня.',
  };
}

/// Presentation at the notification boundary, whose event carries strings.
/// Match the shared Finding formatter exactly, including an aggregate bullet;
/// arbitrary prose and diagnostic messages are not rewritten.
String findingObservationText(String text, String? locale) {
  if (!observationsUseRussian(locale)) return text;
  final known = <String, String>{};
  for (final kind in FindingKind.values) {
    for (final risen in [true, false]) {
      final f = Finding(kind, '', risen: risen);
      known[f.title] = findingTitle(f, locale);
      known[f.detail] = findingDetail(f, locale);
      known['• ${f.title} — ${f.detail}'] =
          '• ${findingTitle(f, locale)} — ${findingDetail(f, locale)}';
    }
  }
  return text.split('\n').map((line) => known[line] ?? line).join('\n');
}

const _sweepNames = {
  'readiness': ('readiness', 'Готовность к нагрузке'),
  'rhr': ('resting heart rate', 'Пульс в покое'),
  'rmssd': ('HRV', 'ВСР'),
  'strain': ('strain', 'Нагрузка'),
  'steps': ('steps', 'Шаги'),
  'tst_min': ('time asleep', 'Время сна'),
  'efficiency': ('sleep efficiency', 'Эффективность сна'),
};

String _measuredText(String text, String? locale) {
  if (!observationsUseRussian(locale)) return text;
  return text
      .replaceAllMapped(RegExp(r'(?<=\d)h\b'), (_) => ' ч')
      .replaceAllMapped(RegExp(r'(?<=\d)m\b'), (_) => ' мин')
      .replaceAll(RegExp(r'\bbpm\b'), 'уд/мин')
      .replaceAll(RegExp(r'\bms\b'), 'мс');
}

/// Translates only the known formatter contract from nightly_sweep.dart.
/// Numeric evidence, bounds, day window and directional claim stay unchanged.
/// Future/unrecognised formatter output is preserved, never guessed.
String sweepFindingText(SweepFinding f, String? locale) {
  if (!observationsUseRussian(locale)) return f.text;
  final names = _sweepNames[f.key];
  if (names == null || !f.text.startsWith('${names.$1} ')) return f.text;
  final split = f.text.indexOf(' — ');
  if (split < 0) return f.text;
  final value = _measuredText(
    f.text.substring(names.$1.length + 1, split),
    locale,
  );
  final tail = f.text.substring(split + 3);
  final extreme = RegExp(
    r'^the (highest|lowest) in (\d+) days \(usually (.+)\)$',
  ).firstMatch(tail);
  if (extreme != null) {
    final dir = extreme[1] == 'highest' ? 'максимум' : 'минимум';
    return '${names.$2}: $value — $dir за ${extreme[2]} дн. '
        '(обычно ${_measuredText(extreme[3]!, locale)})';
  }
  final outside = RegExp(
    r'^(above|below) your usual range \(usually (.+)\)$',
  ).firstMatch(tail);
  if (outside == null) return f.text;
  final dir = outside[1] == 'above' ? 'выше' : 'ниже';
  return '${names.$2}: $value — $dir вашего обычного диапазона '
      '(обычно ${_measuredText(outside[2]!, locale)})';
}

String? sweepPairingText(List<SweepFinding> findings, String? locale) {
  if (!observationsUseRussian(locale)) return sweepPairing(findings);
  if (findings.length < 2) return null;
  String name(SweepFinding f) => sweepFindingText(f, locale).split(' — ').first;
  return '${name(findings[0])} и ${name(findings[1])} — оба показателя вышли '
      'за ваш обычный диапазон в один день. Это стоит заметить, '
      'но наличие связи между ними не установлено';
}

String roughNightDescriptor(String text, String? locale) {
  if (!observationsUseRussian(locale)) return text;
  return const {
        'a rougher night than usual for you — your body worked harder overnight':
            'ночь была тяжелее обычного — ночью организм работал с большей нагрузкой',
        'a slightly off night': 'ночь немного отличалась от обычной',
        'a typical night for you': 'обычная для вас ночь',
      }[text] ??
      text;
}

/// Also covers a preloaded English fixture or a card loaded before locale change.
String roughNightFact(String text, String? locale) {
  if (!observationsUseRussian(locale)) return text;
  final known = const {
    'your resting heart rate ran higher': 'пульс в покое был выше',
    'your HRV ran lower': 'ВСР была ниже',
    'your heart rate dropped less overnight than it usually does':
        'ночью пульс снизился меньше обычного',
    'your skin ran warmer': 'температура кожи была выше',
    'The illness watch flagged this night too — a sustained rise against your own baseline, not a diagnosis.':
        'Наблюдение за возможной болезнью тоже отметило эту ночь: устойчивое повышение '
        'относительно вашего исходного уровня, а не диагноз.',
    'You are in the luteal phase, which lifts resting heart rate and skin temperature by itself.':
        'Сейчас лютеиновая фаза. Она сама по себе повышает пульс в покое и температуру кожи.',
    'Your skin ran warmer than your usual — a warm room does this too.':
        'Температура кожи была выше обычного. Тёплая комната тоже может это объяснить.',
  }[text];
  if (known != null) return known;
  final late = RegExp(
    r'^You trained until (.+), which often does this on its own\.$',
  ).firstMatch(text);
  return late == null
      ? text
      : 'Вы тренировались до ${late[1]}. Нередко одного этого достаточно для таких изменений.';
}

String labCategoryLabel(LabCategory category, String? locale) {
  if (!observationsUseRussian(locale)) return category.label;
  return switch (category) {
    LabCategory.blood => 'Общий анализ крови',
    LabCategory.iron => 'Обмен железа',
    LabCategory.metabolic => 'Обмен веществ',
    LabCategory.lipids => 'Липиды',
    LabCategory.hormones => 'Гормоны',
    LabCategory.vitamins => 'Витамины и минералы',
    LabCategory.inflammation => 'Воспаление',
    LabCategory.organ => 'Печень и почки',
  };
}

const _labNames = {
  'hemoglobin': 'Гемоглобин',
  'hematocrit': 'Гематокрит',
  'ferritin': 'Ферритин',
  'transferrin_saturation': 'Насыщение трансферрина',
  'hba1c': 'Гликированный гемоглобин (HbA1c)',
  'glucose_fasting': 'Глюкоза натощак',
  'insulin_fasting': 'Инсулин натощак',
  'cholesterol_total': 'Общий холестерин',
  'ldl': 'Холестерин ЛПНП',
  'hdl': 'Холестерин ЛПВП',
  'triglycerides': 'Триглицериды',
  'apob': 'Аполипопротеин B (ApoB)',
  'tsh': 'Тиреотропный гормон (ТТГ)',
  'free_t4': 'Свободный Т4',
  'testosterone_total': 'Общий тестостерон',
  'cortisol_am': 'Утренний кортизол',
  'vitamin_d': 'Витамин D (25-OH)',
  'vitamin_b12': 'Витамин B12',
  'folate': 'Фолат',
  'magnesium': 'Магний',
  'crp_hs': 'Высокочувствительный СРБ',
  'alt': 'АЛТ',
  'ast': 'АСТ',
  'creatinine': 'Креатинин',
  'egfr': 'Расчётная СКФ (eGFR)',
};

String labMarkerLabel(LabMarker marker, String? locale) =>
    !marker.custom && observationsUseRussian(locale)
    ? _labNames[marker.key] ?? marker.label
    : marker.label;

String? labMarkerNote(LabMarker marker, String? locale) {
  if (marker.custom || !observationsUseRussian(locale)) return marker.note;
  return const {
        'ferritin':
            'Повышается при воспалении, поэтому одно лишь обычное значение '
            'не исключает низких запасов железа.',
        'hba1c':
            'Отражает примерно последние три месяца, а не сегодняшний день.',
        'testosterone_total':
            'Меняется в течение дня. Для сравнения подходят утренние анализы.',
        'crp_hs':
            'Недавняя инфекция или период интенсивных тренировок могут повысить показатель.',
        'creatinine':
            'Мышечная масса повышает показатель, поэтому у некоторых спортсменов '
            'он может быть высоким и без нарушений.',
      }[marker.key] ??
      marker.note;
}

String labMarkerUnit(LabMarker marker, String? locale) =>
    marker.custom ? marker.unit : observationUnit(marker.unit, locale);

String labMarkerValue(LabMarker marker, double value, String? locale) =>
    '${marker.format(value)} ${labMarkerUnit(marker, locale)}';
