import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/l10n/app_localizations_ru.dart';
import 'package:openstrap_edge/ui2/grammar.dart';
import 'package:openstrap_edge/ui2/screens/cycle_screen.dart';

void main() {
  test('Russian cycle counters handle teens and compound numbers', () {
    final l = AppLocalizationsRu();
    for (final n in [1, 21, 101]) {
      expect(completedCycleUnit(n, l), 'полный цикл');
    }
    for (final n in [2, 3, 4, 22, 23, 24]) {
      expect(completedCycleUnit(n, l), 'полных цикла');
    }
    for (final n in [0, 5, 11, 12, 14, 25, 111, 114]) {
      expect(completedCycleUnit(n, l), 'полных циклов');
    }
    expect(completedCycleUnit(1, null), 'complete cycle');
    expect(completedCycleUnit(2, null), 'complete cycles');
  });

  test('Coverage uses Russian genitive and preserves other locales', () {
    expect(consistencyCountLabel(1, 'days', russian: true), 'из 1 дня');
    expect(consistencyCountLabel(2, 'days', russian: true), 'из 2 дней');
    expect(consistencyCountLabel(11, 'days', russian: true), 'из 11 дней');
    expect(consistencyCountLabel(21, 'days', russian: true), 'из 21 дня');
    expect(consistencyCountLabel(1, 'доз', russian: true), 'из 1 дозы');
    expect(consistencyCountLabel(2, 'доз', russian: true), 'из 2 доз');
    expect(consistencyCountLabel(21, 'показателей', russian: true),
        'из 21 показателя');
    expect(consistencyCountLabel(3, 'days'), 'of 3 days');
    expect(consistencyCountLabel(3, 'doses'), 'of 3 doses');
  });

  testWidgets('Russian coverage renders no English denominator', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: Consistency(2, 7, 'Дни с данными', Colors.green),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('из 7 дней'), findsOneWidget);
    expect(find.textContaining('of 7'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
