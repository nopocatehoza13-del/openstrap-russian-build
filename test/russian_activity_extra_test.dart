import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/l10n/ru_activity_extra.dart';
import 'package:openstrap_edge/ui2/activity/catalogue.dart';
import 'package:openstrap_edge/ui2/activity/picker.dart';
import 'package:openstrap_edge/ui2/activity/poster.dart';
import 'package:openstrap_edge/ui2/activity/share.dart';
import 'package:openstrap_edge/ui2/activity/summary.dart';
import 'package:openstrap_edge/ui2/ui2.dart';

Widget _app(Widget child, {String locale = 'ru'}) => MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(Brightness.light),
      home: child,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fonts = Directory('assets/fonts/Manrope').listSync().whereType<File>()
        .where((file) => file.path.endsWith('.ttf')).toList();
    for (final family in ['Manrope', '.SF Pro Text']) {
      final loader = FontLoader(family);
      for (final font in fonts) {
        loader.addFont(font.readAsBytes().then(ByteData.sublistView));
      }
      await loader.load();
    }
  });

  test('Every catalogue display label is Russian; identifiers stay canonical', () {
    for (final group in activityLibrary) {
      expect(group.displayName('ru'), isNot(group.name), reason: group.name);
      expect(group.displayName('en'), group.name);
      for (final a in group.items) {
        final key = a.typeKey;
        final met = a.met;
        final archetype = archOf(a);
        final calories = a.kcal(72, 30);
        expect(a.displayName('ru'), matches(RegExp('[А-Яа-яЁё]')), reason: a.name);
        expect(a.displayName('en'), a.name);
        expect(a.displayName(), a.name);
        expect(activityByName(key), same(a));
        expect(a.typeKey, key);
        expect(a.met, met);
        expect(archOf(a), archetype);
        expect(a.kcal(72, 30), calories);
      }
    }
    expect(activityByName('running')!.name, 'Running');
    expect(activityByName('running')!.typeKey, 'running');
    expect(ruActivityText('weight_training', locale: 'ru'), 'Силовая тренировка');
    expect(ruActivityText('weight_training', locale: 'en'), 'weight_training');
    expect(activityByName('general_workout')!.met, isNull);
    expect(activityByName('general_workout')!.kcal(72, 30), isNull);
    for (final e in exerciseLibrary) {
      expect(e.displayLabel('ru'), matches(RegExp('[А-Яа-яЁё]')), reason: e.label);
      expect(e.displayLabel('en'), e.label);
      expect(exerciseByKey(e.key), same(e));
      for (final muscle in e.muscles.keys) {
        expect(ruActivityText(muscle, locale: 'ru'), isNot(muscle));
      }
    }
    expect(exerciseByKey('bench_press')!.muscles,
        {'chest': .6, 'triceps': .25, 'shoulders': .15});
  });

  test('All platform-imported sport titles have Russian display names', () {
    for (final type in HealthWorkoutActivityType.values) {
      final title = type.name.split('_').map((word) =>
          word[0] + word.substring(1).toLowerCase()).join(' ');
      expect(ruActivityText(title, locale: 'ru'), matches(RegExp('[А-Яа-яЁё]')),
          reason: type.name);
      expect(ruActivityText(title, locale: 'en'), title);
    }
  });

  test('Russian search accepts ё/е and retains English lookup', () {
    expect(activityNameMatches('Running', 'бег', locale: 'ru'), isTrue);
    expect(activityNameMatches('Indoor bike', 'ТРЕНАЖЕР', locale: 'ru'), isTrue);
    expect(activityNameMatches('Running', 'runn', locale: 'ru'), isTrue);
    expect(activityNameMatches('Running', 'бег', locale: 'en'), isFalse);
  });

  test('Formatted values preserve precision, missing values and canonical keys', () {
    const fixtures = {
      '14.65 km': '14.65 км', '1,234 kcal': '1,234 ккал',
      '34 bpm in 60 s': '34 уд/мин за 60 с', '34 bpm in 60': '34 уд/мин за 60',
      '7 of 10': '7 из 10', '48.7 ml/kg/min': '48.7 мл/кг/мин',
      '04:52 /mi': '04:52 /милю', '+642 m elevation': '+642 м набора высоты',
      '1 laps': '1 отрезок', '22 laps': '22 отрезка', '11 laps': '11 отрезков',
      '—': '—', '': '', '00:48': '00:48',
    };
    for (final f in fixtures.entries) {
      expect(ruActivityText(f.key, locale: 'ru'), f.value);
      expect(ruActivityText(f.key, locale: 'en'), f.key);
      expect(ruActivityText(f.key, locale: 'de'), f.key);
    }
    final start = DateTime(2026, 9, 19, 17, 5);
    expect(posterDate(start, locale: 'ru'), '19 сентября 2026 • 17:05');
    expect(posterDate(start, locale: 'en'), 'Sep 19, 2026 • 5:05 PM');
    final r = ActivityResult(activityByName('running')!, start: start,
        duration: const Duration(minutes: 40), distanceKm: 8.2, calories: 420);
    expect(shareHero(r, null).$2, 'km');
    expect(shareStats(r, null).map((s) => s.$1), contains('Calories'));
    expect(sessionStats(r, null).map((s) => s.$1), contains('Calories'));
    expect(splitStatUnit('420 kcal'), ('420', 'kcal'));
  });

  testWidgets('Actual picker searches in Russian and returns the original Activity',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Activity? picked;
    await tester.pumpWidget(_app(ActivityPicker(onPick: (_, a) => picked = a)));
    await tester.pumpAndSettle();
    expect(find.text('Кардио'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'велотренажер');
    await tester.pumpAndSettle();
    expect(find.text('Велотренажёр'), findsOneWidget);
    expect(find.text('Indoor bike'), findsNothing);
    await tester.tap(find.text('Велотренажёр'));
    expect(picked, same(activityByName('indoor_bike')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Russian poster and session stats localize data-driven labels',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = ActivityResult(activityByName('running')!,
        start: DateTime(2026, 9, 19, 17, 5),
        duration: const Duration(minutes: 40),
        distanceKm: 8.2, calories: 420, avgHr: 148, hrr60: 34, rpe: 7);
    await tester.pumpWidget(_app(Scaffold(body: Center(child: PosterCard(r)))));
    await tester.pumpAndSettle();
    expect(find.text('БЕГ'), findsOneWidget);
    expect(find.text('КАЛОРИИ'), findsOneWidget);
    expect(find.text('ккал'), findsOneWidget);
    expect(find.text('км'), findsOneWidget);
    expect(find.text('19 сентября 2026 • 17:05'), findsOneWidget);
    expect(find.text('Calories'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(_app(Scaffold(body:
        SingleChildScrollView(child: SessionStats(r)))));
    await tester.pumpAndSettle();
    expect(find.text('ВОССТАНОВЛЕНИЕ ПУЛЬСА'), findsOneWidget);
    expect(find.text('34 уд/мин за 60'), findsOneWidget);
    expect(find.text('7 из 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sports sets are сеты, not strength подходы', (tester) async {
    final r = ActivityResult(activityByName('tennis')!,
        start: DateTime(2026, 9, 19), duration: const Duration(minutes: 40),
        gameScore: const [(6, 3), (6, 4)]);
    await tester.pumpWidget(_app(Scaffold(body: SessionStats(r))));
    await tester.pumpAndSettle();
    expect(find.text('СЕТЫ'), findsOneWidget);
    expect(find.text('ПОДХОДЫ'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
