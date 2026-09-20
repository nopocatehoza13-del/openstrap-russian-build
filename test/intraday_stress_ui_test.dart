import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/ui2/familiar/data.dart';
import 'package:openstrap_edge/ui2/familiar/screens.dart';
import 'package:personal_analytics/intraday_stress.dart';
import 'familiar_ui_test.dart' show app;
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family
        in jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List) {
      final loader = FontLoader(family['family'] as String);
      for (final font in family['fonts']) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  final start = DateTime(2026, 9, 18).millisecondsSinceEpoch ~/ 1000;
  final model = scoreIntradayStress(
    minutes: [
      for (var i = 0; i < 360; i++)
        {
          't': start + i * 60,
          'n': 60,
          'hr': i < 120
              ? 50.0
              : i < 300
              ? 65.0
              : 100.0,
          'motion': 0.0,
        },
    ],
    start: start,
    end: start + 86400,
    observedUntil: start + 21600,
    sleep: [(start: start, end: start + 7200)],
    workouts: [(start: start + 18000, end: start + 21600)],
  );
  final data = FamiliarData(day: '2026-09-18', intradayStress: model);
  for (final width in [320.0, 390.0]) {
    testWidgets('real scored data, three scopes, scrubbing, $width layout', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = Size(width, 844);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(app(FamiliarStressDetail(data: data)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      for (final scope in ['ВЕСЬ ДЕНЬ', 'БЕЗ АКТИВНОСТИ', 'СОН']) {
        await t.tap(find.text(scope).first);
        await t.pumpAndSettle();
        final text = t
            .widget<Text>(find.byKey(const ValueKey('stress-summary')))
            .data!;
        expect(text, endsWith(' / 3'));
        expect(text, isNot(contains('—')));
        if (scope == 'БЕЗ АКТИВНОСТИ') expect(text, '1,5 / 3');
        if (width == 390 && Platform.isWindows) {
          await expectLater(
            find.byKey(const ValueKey('capture')),
            matchesGoldenFile(
              'familiar_goldens/stress-v6-${['ВЕСЬ ДЕНЬ', 'БЕЗ АКТИВНОСТИ', 'СОН'].indexOf(scope)}.png',
            ),
          );
        }
      }
      await t.tap(find.byKey(const ValueKey('stress-chart')));
      await t.pump();
      expect(
        t.widget<Text>(find.byKey(const ValueKey('stress-selected'))).data,
        contains(': —'),
      );
      await t.drag(find.byType(ListView).first, const Offset(0, -600));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('large text remains usable', (t) async {
    t.view.physicalSize = const Size(320, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(app(FamiliarStressDetail(data: data), scale: 1.5));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
