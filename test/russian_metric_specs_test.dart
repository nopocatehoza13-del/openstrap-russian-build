import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/l10n/app_localizations_en.dart';
import 'package:openstrap_edge/l10n/app_localizations_ru.dart';
import 'package:openstrap_edge/ui2/screens/home_screen.dart';
import 'package:openstrap_edge/ui2/screens/metric_detail.dart';
import 'package:openstrap_edge/ui2/theme.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fonts = Directory('assets/fonts/Manrope')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.ttf'));
    // Use the actual app font rather than Ahem's square test glyphs.
    // Flutter on desktop also asks for the native family name for some labels.
    for (final family in ['Manrope', '.SF Pro Text']) {
      final loader = FontLoader(family);
      for (final font in fonts) {
        loader.addFont(font.readAsBytes().then(ByteData.sublistView));
      }
      await loader.load();
    }
  });

  test('Russian catalogue preserves canonical units and all behavior fields', () {
    final ru = AppLocalizationsRu();
    final en = AppLocalizationsEn();
    for (final key in [
      'resting_hr', 'hrv', 'readiness', 'resp_rate', 'sleep', 'efficiency',
      'deep', 'rem', 'steps', 'calories', 'strain', 'trimp', 'stress', 'dip',
      'hrr', 'lf_hf', 'hrv_cv', 'brv', 'nap_min', 'active_min', 'wear',
      'skin_temp', 'unknown_metric',
    ]) {
      final original = specOf(key);
      final translated = localizedMetricSpec(original, ru);
      expect(translated.chartKey, original.chartKey, reason: key);
      expect(translated.unit, original.unit, reason: key);
      expect(translated.color, original.color, reason: key);
      expect(translated.icon, original.icon, reason: key);
      expect(translated.higherBetter, original.higherBetter, reason: key);
      expect(translated.requires, original.requires, reason: key);
      expect(translated.citation, original.citation, reason: key);
      expect(translated.suppress == null, original.suppress == null, reason: key);
      expect(translated.suppressFix == null, original.suppressFix == null,
          reason: key);
      expect(identical(localizedMetricSpec(original, en), original), isTrue);
      expect(identical(localizedMetricSpec(original, null), original), isTrue);
    }
    final ready = localizedMetricSpec(specOf('readiness'), ru);
    expect(ready.chartKey, 'recovery');
    expect(ready.title, 'Готовность к нагрузке');
    expect(localizedMetricSpec(specOf('skin_temp'), ru).method,
        contains('Перевода в градусы нет'));
    expect(localizedMetricSpec(specOf('hrv'), ru).method, contains('не ВСР по ЭКГ'));
    expect(localizedMetricSpec(specOf('deep'), ru).method,
        contains('низкой уверенностью'));
  });

  test('Russian display retains the original rounding and precision', () {
    for (final unit in ['bpm', 'ms', '%', 'br/min', 'steps', 'kcal', '', '°']) {
      for (final value in [0.0, 9.24, 17.65, 71.6, 1234.7, -12.4]) {
        expect(metricDisplayValue(unit, value, locale: 'ru'),
            metricValue(unit, value), reason: '$unit $value');
      }
    }
    expect(metricDisplayValue('bpm', 71.6, locale: 'ru'), '72');
    expect(metricDisplayValue('ms', 46.4, locale: 'ru'), '46');
    expect(metricDisplayValue('br/min', 14.36, locale: 'ru'), '14.4');
    expect(metricDisplayValue('min', null, locale: 'ru'), '');
  });

  test('Russian duration suffixes do not alter time values or duplicate units', () {
    expect(metricDisplayValue('min', 443, locale: 'ru'), '7 ч 23 мин');
    expect(metricDisplayValue('min', 60, locale: 'ru_RU'), '1 ч 00 мин');
    expect(metricDisplayValue('min', 9.6, locale: 'ru-RU'), '10 мин');
    expect(metricDisplayValue('min', 443), '7h 23m');
    expect(metricDisplayValue('min', 443, locale: 'en'), '7h 23m');
    expect(metricDisplayAxisMinutes(443, locale: 'ru'), '7 ч 23 мин');
    expect(metricDisplayAxisMinutes(60, locale: 'ru'), '1 ч');
    expect(metricDisplayAxisMinutes(30, locale: 'ru'), '30 мин');
    expect(metricDisplayAxisMinutes(60), '1h');
    expect(metricDisplayUnit('min', locale: 'ru'), 'мин');
    expect(metricDisplayUnit('min', locale: 'ru', besideValue: true), '');
    expect(metricDisplayUnit('bpm', locale: 'ru'), 'уд/мин');
    expect(metricDisplayUnit('ms', locale: 'ru'), 'мс');
    expect(metricDisplayUnit('score', locale: 'ru'), 'баллы');
    expect(metricDisplayUnit('bpm', locale: 'en'), 'bpm');
  });

  testWidgets('Russian sleep detail renders a duration rather than raw minutes',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final points = [
      for (var i = 0; i < 30; i++)
        (
          t: DateTime(now.year, now.month, now.day - (29 - i), 12)
                  .millisecondsSinceEpoch ~/
              1000,
          v: 443.0,
        ),
    ];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(Brightness.light),
      home: MetricDetail('sleep',
          data: MetricData(series: points, daysAvailable: 30)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('7 ч 23 мин'), findsWidgets);
    expect(find.text('443'), findsNothing);
    expect(find.textContaining('мин мин'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
