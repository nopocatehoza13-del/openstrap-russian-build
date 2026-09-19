// Supplemental presentation copy for strings upstream has not put in ARB yet.
// Stored source names, import keys, protocol data and diagnostic details stay intact.
import 'package:flutter/widgets.dart';

bool profileIsRussian(BuildContext context) =>
    Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

String profileText(BuildContext context, String text) =>
    russianProfileText(text, russian: profileIsRussian(context));

String? profileNullableText(BuildContext context, String? text) =>
    text == null ? null : profileText(context, text);

String russianProfileText(String text, {required bool russian}) {
  if (!russian) return text;
  final exact = russianProfileLabels[text];
  if (exact != null) return exact;
  if (text.contains(' + ')) {
    final parts = text.split(' + ');
    if (parts.every(russianProfileLabels.containsKey)) {
      return parts.map((s) => russianProfileLabels[s]!).join(' + ');
    }
  }
  if (text.endsWith(' · wrist optical')) {
    return '${text.substring(0, text.length - 'wrist optical'.length)}оптический датчик на запястье';
  }
  String? result;
  void rule(String pattern, String Function(RegExpMatch) render) {
    if (result != null) return;
    final m = RegExp(pattern).firstMatch(text);
    if (m != null) result = render(m);
  }

  rule(r'^(\d+) min early$', (m) => 'до ${m[1]} мин раньше');
  rule(
    r'^(\d+) min before wake time$',
    (m) => 'за ${m[1]} мин до времени подъёма',
  );
  rule(
    r'^Reset (.+) to the default order$',
    (m) => 'Восстановить стандартный порядок источников: ${m[1]}',
  );
  rule(r'^about (\d+) h left$', (m) => 'осталось около ${m[1]} ч');
  rule(r'^about (\d+) days left$', (m) => 'осталось около ${m[1]} дн.');
  rule(
    r'^(\d+) charges? logged(, up to (\d+) mV)?$',
    (m) =>
        'Подключений к зарядке: ${m[1]}${m[3] == null ? '' : ', напряжение до ${m[3]} мВ'}',
  );
  rule(r'^(\d+)m$', (m) => '${m[1]} мин');
  rule(r'^(\d+)h$', (m) => '${m[1]} ч');
  rule(
    r'^([\d.]+) (B|KB|MB|GB|TB)$',
    (m) =>
        '${m[1]} ${const {'B': 'Б', 'KB': 'КБ', 'MB': 'МБ', 'GB': 'ГБ', 'TB': 'ТБ'}[m[2]]}',
  );
  rule(r'^(-?\d+) dBm$', (m) => '${m[1]} дБм');
  rule(r'^(\d+) bpm$', (m) => '${m[1]} уд/мин');
  rule(
    r'^That device answered, but it does not expose the (.+) data this needs \(missing (.+)\)\. Nothing was saved\.$',
    (m) =>
        'Устройство ответило, но не предоставляет нужные данные (${russianProfileText(m[1]!, russian: true)}; отсутствуют: ${m[2]}). Ничего не сохранено.',
  );
  rule(r'^…(.+) · (-?\d+) dBm$', (m) => '…${m[1]} · ${m[2]} дБм');
  return result ?? text;
}

const russianProfileLabels = <String, String>{
  'no data in this range': 'нет данных за этот период',
  'mmHg': 'мм рт. ст.',
  'mmol/L': 'ммоль/л',
  'mg/dL': 'мг/дл',

  "Bluetooth heart rate sensor": "Датчик пульса Bluetooth",
  "Polar sensor": "Датчик Polar",
  "Smart ring (R11M/R10M)": "Умное кольцо (R11M/R10M)",
  "Coros watch": "Часы Coros",
  "Garmin watch": "Часы Garmin",
  "DaFit / MOYOUNG watch": "Часы DaFit / MOYOUNG",
  "WearFit band": "Браслет WearFit",
  "Smart ring/band (Lefun protocol)":
      "Умное кольцо или браслет (протокол Lefun)",
  "HPlus HR band": "Браслет HPlus с датчиком пульса",
  "Fossil/Skagen Hybrid Smartwatch": "Гибридные часы Fossil/Skagen",
  "Colmi ring": "Кольцо Colmi",
  "Your main band is not paired yet. Searching for a sensor now starts Bluetooth in a way that hides the system pairing sheet until you restart the app — so pair your main band first, or expect to restart the app before you can.":
      "Основной браслет ещё не подключён. Поиск датчиков сейчас запустит Bluetooth, и системное окно подключения браслета станет недоступно до перезапуска приложения. Сначала подключите основной браслет; иначе перед его подключением придётся перезапустить приложение.",
  "That sensor did not answer. It may have gone back to sleep, or it may already be connected to another phone or app.":
      "Датчик не ответил. Возможно, он снова перешёл в спящий режим или уже подключён к другому телефону либо приложению.",
  "That device did not accept Bluetooth pairing. Nothing was saved.":
      "Устройство не приняло запрос сопряжения по Bluetooth. Ничего не сохранено.",
  "That sensor disconnected before it could be set up. Nothing was saved.":
      "Датчик отключился до завершения настройки. Ничего не сохранено.",
  "That device does not expose the service this app speaks for a Mi Band 2, 3 or 4.":
      "Устройство не предоставляет Bluetooth-сервис, через который это приложение работает с Mi Band 2, 3 и 4.",
  "The band would not accept a command. Try again with it on the charger and next to the phone.":
      "Браслет не принял команду. Поставьте его на зарядку рядом с телефоном и повторите попытку.",
  "The band stopped answering part-way through pairing. Put it on the charger, keep it next to the phone, and try again.":
      "Браслет перестал отвечать во время сопряжения. Поставьте его на зарядку рядом с телефоном и повторите попытку.",
  "The band would not accept the pairing answer.":
      "Браслет не принял ответ на запрос сопряжения.",
  "Could not connect to that device.": "Не удалось подключиться к устройству.",
  "That device does not expose the ring service this app speaks.":
      "Устройство не предоставляет Bluetooth-сервис, через который это приложение работает с кольцом.",
  "Could not connect to that ring.": "Не удалось подключиться к кольцу.",
  "The ring would not accept a command. Try again with it on the charger and next to the phone.":
      "Кольцо не приняло команду. Поставьте его на зарядку рядом с телефоном и повторите попытку.",
  "The ring stopped answering part-way through pairing. Put it on the charger, keep it next to the phone, and try again.":
      "Кольцо перестало отвечать во время сопряжения. Поставьте его на зарядку рядом с телефоном и повторите попытку.",
  "The ring would not accept the pairing answer.":
      "Кольцо не приняло ответ на запрос сопряжения.",
  "The ring took the key but is still waiting for one, which should not happen. Try pairing again.":
      "Кольцо приняло ключ, но по-прежнему ожидает его — это нештатная ситуация. Повторите сопряжение.",
  "That device does not expose the service this app speaks.":
      "Устройство не предоставляет Bluetooth-сервис, с которым работает это приложение.",
  "That device would not accept a command. Try again with it on the charger and next to the phone.":
      "Устройство не приняло команду. Поставьте его на зарядку рядом с телефоном и повторите попытку.",

  "Smart wake": "Умное пробуждение",
  "Smart wake window": "Интервал умного пробуждения",
  "Smart wake off": "Умное пробуждение выключено",
  "Smart wake on — the band still buzzes at the wake time either way":
      "Умное пробуждение включено. В любом случае браслет подаст сигнал не позднее заданного времени подъёма.",
  "Off": "Выкл.",
  "Your band": "Ваш браслет",
  "Paired sensor": "Подключённый датчик",
  "Unknown sensor": "Неизвестный датчик",
  "This phone": "Этот телефон",
  "Motion coprocessor": "Сопроцессор движения",
  "wrist optical": "оптический датчик на запястье",
  "Not stated yet": "Пока не указано",
  "Metrics that depend on the sensor use this band’s own constants, so two different bands can land on different tiers for the same physiology.":
      "Для показателей, зависящих от датчика, используются калибровочные константы именно этого браслета. Поэтому разные браслеты могут дать разные уровни оценки при одном и том же физиологическом состоянии.",
  "This band has not said which generation it is, and imported or older days never will. Metrics that depend on the sensor abstain rather than borrow another band’s numbers.":
      "Браслет пока не сообщил своё поколение. В импортированных и старых данных эта информация уже не появится. Показатели, зависящие от датчика, не рассчитываются: приложение не подставляет калибровку другого браслета.",
  "iOS can only show the system pairing sheet before the app has used Bluetooth. Close OpenStrap completely, then reopen it — the sheet appears on its own.":
      "iOS может показать системное окно подключения только до того, как приложение начнёт использовать Bluetooth. Полностью закройте OpenStrap и откройте снова — окно появится автоматически.",
  "Syncing…": "Синхронизация…",
  "Syncing the watch…": "Синхронизация часов…",
  "Synced.": "Синхронизация завершена.",
  "Already syncing.": "Синхронизация уже идёт.",
  "under an hour left": "осталось меньше часа",
  "Age": "Возраст",
  "Height (in)": "Рост (дюймы)",
  "Height (cm)": "Рост (см)",
  "Weight (lb)": "Вес (фунты)",
  "Weight (kg)": "Вес (кг)",
  "height": "рост",
  "weight": "вес",
  "sex": "пол",
  "birthday": "дата рождения",
  "age": "возраст",
  "bpm": "уд/мин",
  "cm": "см",
  "kg": "кг",
  "in": "дюймы",
  "lb": "фунты",
  "dBm": "дБм",
  "File picker": "Выбор файла",
  "Import": "Импорт",
  "Encrypted backup": "Зашифрованная резервная копия",
  "OpenStrap backup": "Резервная копия OpenStrap",
  "Raw sensor export": "Экспорт исходных данных датчика",
  "Journal CSV": "Дневник в CSV",
  "Lab results CSV": "Результаты анализов в CSV",
  "Vendor CSV export": "CSV-экспорт производителя",
  "Nothing selected": "Ничего не выбрано",
  "That file is an encrypted backup. Open it from Settings → Your data, where the passphrase can be asked for.":
      "Это зашифрованная резервная копия. Откройте её в разделе «Настройки → Ваши данные»: там можно ввести парольную фразу.",
  "OpenStrap export": "Экспорт OpenStrap",
  "OpenStrap database": "База данных OpenStrap",
  "OpenStrap encrypted backup": "Зашифрованная резервная копия OpenStrap",
  "Heart-rate sensor": "Датчик пульса",
  "Heart rate sensor": "Датчик пульса",
  "Watches & bands": "Часы и браслеты",
  "Chest straps & armbands": "Нагрудные датчики и датчики на предплечье",
  "Could not reach the board. It has to be nearby, and not connected to another app.":
      "Не удалось подключиться к устройству. Оно должно находиться рядом и не быть подключено к другому приложению.",
  "Could not reach the band. It has to be nearby, and not connected to another app.":
      "Не удалось подключиться к браслету. Устройство должно находиться рядом и не быть подключено к другому приложению.",
  "Could not reach the watch. It has to be nearby, and not connected to another app.":
      "Не удалось подключиться к часам. Устройство должно находиться рядом и не быть подключено к другому приложению.",
  "Could not reach the ring. It has to be nearby, and not connected to another app.":
      "Не удалось подключиться к кольцу. Оно должно находиться рядом и не быть подключено к другому приложению.",
  "Could not reach it. It has to be nearby, and not connected to another app.":
      "Не удалось подключиться. Устройство должно находиться рядом и не быть подключено к другому приложению.",
};

const russianDeviceBlurbs = <String, String>{
  "ultrahuman":
      "Читает данные напрямую с кольца — без аккаунта и обмена ключами.",
  "pebble":
      "Только Pebble 2 и Pebble 2 SE. Пока поддерживается лишь сопряжение: данные ещё не считываются и не сохраняются.",
  "makibeshr3":
      "Устройство на базе Makibes HR3 без определённого бренда. Поддерживается сопряжение и сохранение исходных данных; показатели по ним пока не рассчитываются.",
  "id115":
      "Устройство на базе ID115 без определённого бренда. Поддерживается сопряжение и сохранение исходных данных; показатели по ним пока не рассчитываются.",
  "smaq2oss":
      "Умные часы SMA-Q2-OSS. Поддерживается сопряжение и сохранение исходных данных; показатели по ним пока не рассчитываются.",
  "xwatch":
      "Устройство на базе XWatch без определённого бренда. Поддерживается сопряжение и сохранение исходных данных; показатели по ним пока не рассчитываются.",
  "watch9":
      "Устройство на базе Watch9 без определённого бренда. Поддерживается сопряжение и сохранение исходных данных; показатели по ним пока не рассчитываются.",
  "tlw64":
      "Фитнес-браслет TLW64 или NO1 F1. Поддерживается сопряжение и сохранение исходных данных; показатели по ним пока не рассчитываются.",
  "dafit":
      "Часы семейства DaFit/MOYOUNG без определённого бренда. Поддерживается сопряжение и сохранение данных устройства; показатели по ним пока не рассчитываются.",
  "dt78":
      "Поддерживается сопряжение и сохранение исходных данных — расшифровка пока не реализована.",
  "lefun":
      "Кольцо или браслет, продающийся под разными названиями. Поддерживается сопряжение и подключение; данные пока не поступают.",
  "hplus":
      "Браслет с датчиком пульса из семейства HPlus. Поддерживается сопряжение и сохранение истории; показатели из этих данных пока не извлекаются.",
  "pinetime":
      "Поддерживается сопряжение и фоновое сохранение исходных данных. Показатели по ним пока не рассчитываются.",
  "qhybrid":
      "Первое поколение гибридных часов Fossil/Skagen, не более новые Hybrid HR. Поддерживается сопряжение и подключение; показатели пока не рассчитываются.",
  "jyou":
      "Бюджетный фитнес-браслет. Поддерживается сопряжение и сохранение исходных данных; показатели по ним пока не рассчитываются.",
};
