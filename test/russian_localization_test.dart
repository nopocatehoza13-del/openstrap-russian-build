import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/l10n/app_localizations_ru.dart';
import 'package:openstrap_edge/state/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Russian catalog contains every English message and metadata key', () {
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    final ru = jsonDecode(File('lib/l10n/app_ru.arb').readAsStringSync()) as Map;
    expect(ru.keys.toSet(), en.keys.toSet());
    expect(ru['@@locale'], 'ru');
    for (final key in en.keys.where((k) => !k.startsWith('@'))) {
      expect(ru[key], isA<String>(), reason: '$key must be a string');
      expect((ru[key] as String).trim(), isNotEmpty, reason: '$key is empty');
    }
  });

  test('Russian plurals include 1, 2, 5, 11, 21, 22 and 25', () {
    final l = AppLocalizationsRu();
    expect(l.profileTitle, 'Профиль');
    expect(l.profileLanguage, 'Язык');
    expect(l.alarmInDays(1), 'Через 1 день');
    expect(l.alarmInDays(2), 'Через 2 дня');
    expect(l.alarmInDays(5), 'Через 5 дней');
    expect(l.alarmInDays(11), 'Через 11 дней');
    expect(l.alarmInDays(21), 'Через 21 день');
    expect(l.alarmInDays(22), 'Через 22 дня');
    expect(l.alarmInDays(25), 'Через 25 дней');
    expect(l.profileSourcesCount(1), '1 источник');
    expect(l.profileSourcesCount(2), '2 источника');
    expect(l.profileSourcesCount(5), '5 источников');
    expect(l.readinessDetailTitle, 'Готовность к нагрузке');
  });

  test('Russian locale persists and is supported', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await LocaleController.bootstrap();
    await controller.setCode('ru');
    expect((await LocaleController.bootstrap()).locale, const Locale('ru'));
    expect(AppLocalizations.supportedLocales, contains(const Locale('ru')));
  });

  testWidgets('Russian controls render on a narrow phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        final l = AppLocalizations.of(context)!;
        return Scaffold(
          appBar: AppBar(title: Text(l.profileTitle)),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Text(l.readinessDetailTitle),
            Text(l.pairingBondRefusedBody),
            Text(l.welcomePassphraseCreateNote),
            TextButton(onPressed: () {}, child: Text(l.pairingBondRefusedAdviceFix)),
            FilledButton(onPressed: () {}, child: Text(l.actionContinue)),
          ]),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
