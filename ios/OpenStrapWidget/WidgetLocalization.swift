import Foundation

/// Display-only copy shared by widgets and Live Activities. Dart publishes the
/// resolved app language (including an override when iOS itself is English).
/// No measurement, absence gate, protocol key or activity identifier is altered.
enum SWL {
  static var isRussian: Bool {
    let stored = UserDefaults(suiteName: AppGroup.identifier)?.string(forKey: "widget_language")
    let code = stored ?? Locale.preferredLanguages.first ?? "en"
    return code.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first == "ru"
  }

  static func text(_ key: String, _ values: String...) -> String {
    var result = isRussian ? (ru[key] ?? key) : key
    for (index, value) in values.enumerated() {
      result = result.replacingOccurrences(of: "{\(index)}", with: value)
    }
    return result
  }

  private static let ru: [String: String] = [
    "Band": "Браслет",
    "Not connected yet": "Ещё не подключён",
    "Last known level": "Последний известный заряд",
    "Last known": "Последние данные",
    "Charging": "Заряжается",
    "Battery": "Заряд",
    "{0} {1}% · last known": "{0} {1}% · последние данные",
    "{0} not connected": "{0} не подключён",
    "Band Battery": "Заряд браслета",
    "Your band's battery level at a glance.": "Заряд браслета с первого взгляда.",
    "Recovery": "Восстановление",
    "RCV": "ВОССТ.",
    "Recovery {0}": "Восстановление: {0}",
    "Recovery · {0}": "Восстановление · {0}",
    "Strain": "Нагрузка",
    "STRAIN": "НАГРУЗКА",
    "Sleep": "Сон",
    "SLEEP": "СОН",
    "Recovery, strain and sleep at a glance.": "Восстановление, нагрузка и сон с первого взгляда.",
    "Good to go": "Готовность высокая",
    "of 21": "из 21",
    "7h 17m": "7 ч 17 мин",
    "of 7h 45m": "из 7 ч 45 мин",
    "No recent data": "Нет свежих данных",
    "Open OpenStrap and sync your band.": "Откройте OpenStrap и синхронизируйте браслет.",
    "OpenStrap · no recent data": "OpenStrap · нет свежих данных",
    "Not measured": "Нет измерений",
    "HRV": "ВСР",
    "ms": "мс",
    "bpm": "уд/мин",
    "BPM": "УД/МИН",
    "base {0}": "базовый уровень: {0}",
    "Resting HR": "Пульс в покое",
    "HRV {0} ms": "ВСР {0} мс",
    "RHR {0}": "Пульс в покое {0}",
    "Overnight": "За ночь",
    "Your baseline {0} ms": "Ваш базовый уровень: {0} мс",
    "OpenStrap · HRV not measured": "OpenStrap · ВСР не измерена",
    "Last night's HRV against your own baseline, and resting heart rate.": "Ночная ВСР относительно вашего базового уровня и пульс в покое.",
    "{0}% efficient": "Эффективность {0}%",
    "Last night": "Прошлая ночь",
    "Slept {0}": "Сон: {0}",
    "How long you slept, against the need the app has learned.": "Время сна относительно вашей потребности, определённой приложением.",
    "Finish session": "Завершить тренировку",
    "KCAL": "ККАЛ",
    "{0} kcal": "{0} ккал",
    "ZONE {0}": "ЗОНА {0}",
    "Z{0}": "З{0}",
    "WARMING UP": "РАЗМИНКА",
    "Calibrating…": "Калибровка…",
    "End session": "Завершить сеанс",
    "COHERENCE": "СОГЛАСОВАННОСТЬ",
  ]
}
