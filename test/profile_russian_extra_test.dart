import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/l10n/ru_profile_extra.dart';
import 'package:openstrap_edge/l10n/app_localizations.dart';

void main() {
  String ru(String text) => russianProfileText(text, russian: true);
  test('profile units and named import sources localize only for Russian', () {
    expect(ru('Height (cm)'), 'Рост (см)');
    expect(ru('Weight (lb)'), 'Вес (фунты)');
    expect(ru('90m'), '90 мин');
    expect(ru('2h'), '2 ч');
    expect(
      ru('Journal CSV + Lab results CSV'),
      'Дневник в CSV + Результаты анализов в CSV',
    );
    expect(
      ru('WHOOP 5 · wrist optical'),
      'WHOOP 5 · оптический датчик на запястье',
    );
    expect(ru('Bluetooth heart rate sensor'), 'Датчик пульса Bluetooth');
    expect(russianProfileText('Height (cm)', russian: false), 'Height (cm)');
  });
  test(
    'smart wake remains an early window and hard alarm is not promised away',
    () {
      expect(ru('15 min early'), 'до 15 мин раньше');
      expect(ru('30 min before wake time'), 'за 30 мин до времени подъёма');
      expect(
        ru('Smart wake on — the band still buzzes at the wake time either way'),
        contains('не позднее заданного времени подъёма'),
      );
    },
  );
  test(
    'battery copy preserves uncertainty and charging sessions, not cycles',
    () {
      expect(ru('about 2 days left'), 'осталось около 2 дн.');
      expect(ru('1 charge logged'), 'Подключений к зарядке: 1');
      expect(
        ru('12 charges logged, up to 4180 mV'),
        'Подключений к зарядке: 12, напряжение до 4180 мВ',
      );
      expect(ru('98 bpm'), '98 уд/мин');
      expect(ru('2.3 MB'), '2.3 МБ');
    },
  );
  test('pairing preserves missing service identifiers and failure state', () {
    expect(
      ru(
        'That device answered, but it does not expose the Polar sensor data this needs (missing 12345678, abcdef00). Nothing was saved.',
      ),
      'Устройство ответило, но не предоставляет нужные данные (Датчик Polar; отсутствуют: 12345678, abcdef00). Ничего не сохранено.',
    );
    expect(
      ru(
        'That sensor disconnected before it could be set up. Nothing was saved.',
      ),
      'Датчик отключился до завершения настройки. Ничего не сохранено.',
    );
    const details = 'PlatformException(disconnected, CBErrorDomain: 6, null)';
    expect(ru(details), details);
    expect(ru('My custom WHOOP name'), 'My custom WHOOP name');
  });
  test(
    'all newly shipped device blurbs are Russian and honest about incomplete support',
    () {
      expect(russianDeviceBlurbs, hasLength(15));
      for (final entry in russianDeviceBlurbs.entries) {
        expect(entry.value, matches(RegExp('[А-Яа-я]')), reason: entry.key);
      }
      expect(
        russianDeviceBlurbs['pebble'],
        contains('не считываются и не сохраняются'),
      );
      expect(
        russianDeviceBlurbs['qhybrid'],
        contains('не более новые Hybrid HR'),
      );
      expect(
        russianDeviceBlurbs['dt78'],
        contains('расшифровка пока не реализована'),
      );
    },
  );
  testWidgets('profile display boundary uses app locale, not device language', (
    tester,
  ) async {
    Widget surface(Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ru')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(builder: (c) => Text(profileText(c, 'Smart wake'))),
    );
    await tester.pumpWidget(surface(const Locale('ru')));
    await tester.pumpAndSettle();
    expect(find.text('Умное пробуждение'), findsOneWidget);
    await tester.pumpWidget(surface(const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('Smart wake'), findsOneWidget);
  });
}
