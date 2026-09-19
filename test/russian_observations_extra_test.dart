import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/ai/nightly_sweep.dart';
import 'package:openstrap_edge/compute/findings.dart';
import 'package:openstrap_edge/data/journal_fields.dart';
import 'package:openstrap_edge/data/lab_catalogue.dart';
import 'package:openstrap_edge/data/med_store.dart';
import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/l10n/ru_observations_extra.dart';
import 'package:openstrap_edge/ui2/screens/findings_log.dart';
import 'package:openstrap_edge/ui2/screens/health_screen.dart';
import 'package:openstrap_edge/ui2/screens/journal_compose.dart';
import 'package:openstrap_edge/ui2/screens/wellness_screen.dart';
import 'package:openstrap_edge/ui2/screens/what_changed.dart';
import 'package:openstrap_edge/ui2/ui2.dart';

Widget host(Widget child, {String language = 'ru'}) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildTheme(Brightness.light),
  home: Scaffold(body: child),
);

const _rhr = SweepFinding(
  key: 'rhr',
  text:
      'resting heart rate 62 bpm — the highest in 28 days (usually 48 bpm–54 bpm)',
  z: 3.1,
  high: true,
);
const _sleep = SweepFinding(
  key: 'tst_min',
  text: 'time asleep 5h 17m — below your usual range (usually 7h 0m–8h 31m)',
  z: -2.7,
  high: false,
);

void main() {
  group('Russian observations preserve canonical data', () {
    test(
      'all built-in journal names and standard units translate only for ru',
      () {
        expect(kJournalFields, hasLength(10));
        for (final spec in kJournalFields) {
          for (final locale in ['ru', 'ru_RU', 'ru-RU']) {
            expect(
              journalFieldLabel(spec, locale),
              matches(RegExp('[А-Яа-яЁё]')),
              reason: spec.key,
            );
          }
          expect(journalFieldLabel(spec, 'en'), spec.label);
          expect(journalFieldLabel(spec, null), spec.label);
          expect(journalFieldLabel(spec, 'de'), spec.label);
          expect(journalFieldValue(spec, 2, 'en'), spec.formatWithUnit(2));
        }
        final caffeine = kJournalFieldsByKey['caffeine_mg']!;
        expect(journalFieldValue(caffeine, 125, 'ru'), '125 мг');
        expect(caffeine.key, 'caffeine_mg');
        expect(caffeine.label, 'Caffeine');
        expect(caffeine.unit, 'mg');
        expect(caffeine.step, 25);
        expect(
          journalInsightField('caffeine_last_min', 'Last caffeine', 'ru'),
          'Время последнего приёма кофеина',
        );
      },
    );

    test(
      'custom journal names and units are user content, not catalogue text',
      () {
        const custom = JournalFieldSpec(
          key: 'custom_salt',
          label: 'My salt',
          kind: JournalFieldKind.dose,
          unit: 'cups',
          max: 20,
          step: .5,
          custom: true,
        );
        expect(journalFieldLabel(custom, 'ru'), 'My salt');
        expect(journalFieldValue(custom, 1.5, 'ru'), '1.5 cups');
        expect(
          journalInsightField(custom.key, custom.label, 'ru'),
          custom.label,
        );
        expect(
          journalInsightField('future_field', 'Future label', 'ru'),
          'Future label',
        );
      },
    );

    test(
      'all shipped tags translate but saved keys and unknown tags do not change',
      () {
        const tags = [
          'caffeine',
          'alcohol',
          'late meal',
          'stress',
          'poor sleep',
          'travel',
          'screens late',
          'meds',
          'sick',
          'sauna',
          'cold plunge',
          'social',
          'workout',
          'rest day',
        ];
        for (final tag in tags) {
          expect(journalTagLabel(tag, 'ru'), matches(RegExp('[А-Яа-яЁё]')));
          expect(journalTagLabel(tag, 'en'), tag);
        }
        expect(journalTagLabel('my event', 'ru'), 'my event');
        expect(tags.first, 'caffeine');
      },
    );

    test(
      'medication copy translates no-dose state and standard units, not names',
      () {
        const directed = MedDef(key: 'm1', label: 'User medication');
        const dose = MedDef(
          key: 'm2',
          label: 'My magnesium',
          doseValue: 12.5,
          doseUnit: 'mg',
        );
        const custom = MedDef(
          key: 'm3',
          label: 'My supplement',
          doseValue: 2,
          doseUnit: 'scoops',
        );
        expect(medicationDoseLabel(directed, 'ru'), 'По назначению');
        expect(medicationDoseLabel(directed, 'en'), 'As directed');
        expect(medicationDoseLabel(dose, 'ru'), '12.5 мг');
        expect(medicationDoseLabel(custom, 'ru'), '2 scoops');
        expect(dose.label, 'My magnesium');
        expect(dose.doseValue, 12.5);
        expect(dose.doseUnit, 'mg');
      },
    );

    test(
      'all finding kinds translated without changing medical status or direction',
      () {
        for (final kind in FindingKind.values) {
          final finding = Finding(kind, '2026-09-18');
          expect(findingTitle(finding, 'ru'), matches(RegExp('[А-Яа-яЁё]')));
          expect(findingDetail(finding, 'ru'), matches(RegExp('[А-Яа-яЁё]')));
          expect(findingTitle(finding, 'en'), finding.title);
          expect(findingDetail(finding, 'en'), finding.detail);
          expect(finding.date, '2026-09-18');
        }
        const screen = Finding(FindingKind.irregularRhythm, '2026-09-18');
        expect(findingDetail(screen, 'ru'), contains('скрининг, а не диагноз'));
        expect(
          findingDetail(screen, 'ru'),
          contains('Если есть симптомы, обратитесь к врачу'),
        );
        const down = Finding(FindingKind.rhrShift, '2026-09-18', risen: false);
        expect(findingDetail(down, 'ru'), contains('снизился'));
        expect(findingDetail(down, 'ru'), isNot(contains('повысился')));
        expect(down.risen, isFalse);
        expect(down.medical, isFalse);
      },
    );

    test(
      'notification mapping shares the finding wording and preserves unknown prose',
      () {
        const a = Finding(FindingKind.illness, '2026-09-18');
        const b = Finding(FindingKind.rhrShift, '2026-09-18', risen: false);
        final body = '• ${a.title} — ${a.detail}\n• ${b.title} — ${b.detail}';
        expect(
          findingObservationText(body, 'ru'),
          '• ${findingTitle(a, 'ru')} — ${findingDetail(a, 'ru')}\n'
          '• ${findingTitle(b, 'ru')} — ${findingDetail(b, 'ru')}',
        );
        expect(findingObservationText(body, 'en'), body);
        expect(
          findingObservationText('New diagnostic: 18', 'ru'),
          'New diagnostic: 18',
        );
      },
    );

    test('sweep extrema and usual range retain every numerical measurement', () {
      expect(
        sweepFindingText(_rhr, 'ru'),
        'Пульс в покое: 62 уд/мин — максимум за 28 дн. (обычно 48 уд/мин–54 уд/мин)',
      );
      expect(
        sweepFindingText(_sleep, 'ru'),
        'Время сна: 5 ч 17 мин — ниже вашего обычного диапазона (обычно 7 ч 0 мин–8 ч 31 мин)',
      );
      expect(sweepFindingText(_rhr, 'en'), _rhr.text);
      expect(_rhr.z, 3.1);
      expect(_rhr.high, isTrue);
      expect(_sleep.high, isFalse);
      const lower = SweepFinding(
        key: 'rmssd',
        text: 'HRV 24 ms — the lowest in 21 days (usually 39 ms–55 ms)',
        z: -3,
        high: false,
      );
      expect(
        sweepFindingText(lower, 'ru'),
        'ВСР: 24 мс — минимум за 21 дн. (обычно 39 мс–55 мс)',
      );
      const upper = SweepFinding(
        key: 'strain',
        text: 'strain 14.7 — above your usual range (usually 5.2–10.1)',
        z: 2.7,
        high: true,
      );
      expect(
        sweepFindingText(upper, 'ru'),
        'Нагрузка: 14.7 — выше вашего обычного диапазона (обычно 5.2–10.1)',
      );
    });

    test(
      'sweep pairing remains association, never a cause or measured relationship',
      () {
        expect(
          sweepPairingText([_rhr, _sleep], 'ru'),
          contains('наличие связи между ними не установлено'),
        );
        expect(sweepPairingText([_rhr, _sleep], 'ru'), contains('62 уд/мин'));
        expect(sweepPairingText([_rhr], 'ru'), isNull);
        expect(
          sweepPairingText([_rhr, _sleep], 'en'),
          sweepPairing([_rhr, _sleep]),
        );
        const unknown = SweepFinding(
          key: 'rhr',
          text: 'future format 123',
          z: 3,
          high: true,
        );
        expect(sweepFindingText(unknown, 'ru'), unknown.text);
      },
    );

    test('rough-night claims retain uncertainty and do not blame the user', () {
      expect(
        roughNightDescriptor('a typical night for you', 'ru'),
        'обычная для вас ночь',
      );
      expect(
        roughNightDescriptor(
          'a rougher night than usual for you — your body worked harder overnight',
          'ru',
        ),
        'ночь была тяжелее обычного — ночью организм работал с большей нагрузкой',
      );
      expect(roughNightFact('your HRV ran lower', 'ru'), 'ВСР была ниже');
      expect(
        roughNightFact(
          'You trained until 22:43, which often does this on its own.',
          'ru',
        ),
        contains('до 22:43'),
      );
      expect(
        roughNightFact(
          'The illness watch flagged this night too — a sustained rise against your own baseline, not a diagnosis.',
          'ru',
        ),
        contains('а не диагноз'),
      );
      expect(roughNightFact('New diagnostic', 'ru'), 'New diagnostic');
    });

    test('all chronotype categories and stress states are display-only', () {
      for (final value in [
        'early type',
        'moderate early type',
        'intermediate type',
        'moderate evening type',
        'evening type',
      ]) {
        expect(
          chronotypeObservationLabel(value, 'ru'),
          matches(RegExp('[А-Яа-я]')),
        );
        expect(chronotypeObservationLabel(value, 'en'), value);
      }
      expect(chronotypeObservationLabel('new class', 'ru'), 'new class');
      expect(
        chronotypeObservationLabel('slight evening type', 'ru'),
        'Ближе к вечернему типу',
      );
      expect(stressObservationLabel('Low', 'ru'), 'Низкий');
      for (final value in ['low', 'normal', 'elevated', 'high']) {
        expect(
          stressObservationLabel(value, 'ru'),
          matches(RegExp('[А-Яа-я]')),
        );
        expect(stressObservationLabel(value, 'en'), value);
      }
    });

    test(
      'entire shipped laboratory catalogue translates without unit conversion',
      () {
        expect(kLabMarkers, hasLength(25));
        for (final marker in kLabMarkers) {
          expect(
            labMarkerLabel(marker, 'ru'),
            matches(RegExp('[А-Яа-яЁё]')),
            reason: marker.key,
          );
          expect(labMarkerLabel(marker, 'en'), marker.label);
          expect(labMarkerUnit(marker, 'en'), marker.unit);
          expect(
            labMarkerValue(marker, 42.37, 'ru'),
            startsWith(marker.format(42.37)),
          );
          if (marker.note != null) {
            expect(labMarkerNote(marker, 'ru'), matches(RegExp('[А-Яа-яЁё]')));
            expect(labMarkerNote(marker, 'en'), marker.note);
          }
        }
        for (final category in LabCategory.values) {
          expect(
            labCategoryLabel(category, 'ru'),
            matches(RegExp('[А-Яа-яЁё]')),
          );
          expect(labCategoryLabel(category, 'en'), category.label);
        }
        final ferritin = kLabMarkersByKey['ferritin']!;
        expect(labMarkerValue(ferritin, 42, 'ru'), '42 нг/мл');
        expect(ferritin.unit, 'ng/mL');
        expect(ferritin.rangeFor('male')!.low, 30);
        expect(ferritin.rangeFor('female')!.low, 15);
      },
    );

    test(
      'custom lab label, unit, note and absence of reference interval remain intact',
      () {
        const marker = LabMarker(
          key: 'custom_x',
          label: 'My marker',
          unit: 'myU',
          category: LabCategory.blood,
          note: 'My note',
          custom: true,
        );
        expect(labMarkerLabel(marker, 'ru'), marker.label);
        expect(labMarkerUnit(marker, 'ru'), marker.unit);
        expect(labMarkerNote(marker, 'ru'), marker.note);
        expect(marker.inRange(42), isNull);
      },
    );
  });

  testWidgets(
    'actual journal FieldStepper labels and value are Russian; input unchanged',
    (tester) async {
      final field = kJournalFieldsByKey['caffeine_mg']!;
      await tester.pumpWidget(
        host(
          FieldStepper(
            spec: field,
            value: 125,
            onChanged: (_) {},
            onTime: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Кофеин'), findsOneWidget);
      expect(find.text('125 мг'), findsOneWidget);
      expect(find.text('Caffeine'), findsNothing);
      expect(find.text('125 mg'), findsNothing);
      expect(field.unit, 'mg');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('actual finding row keeps medical caveat in Russian', (
    tester,
  ) async {
    const finding = Finding(FindingKind.irregularRhythm, '2026-09-18');
    await tester.pumpWidget(host(const FindingRow(finding)));
    await tester.pumpAndSettle();
    expect(find.text(findingTitle(finding, 'ru')), findsOneWidget);
    expect(find.text(findingDetail(finding, 'ru')), findsOneWidget);
    expect(find.text(finding.title), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'actual lab result row uses Russian catalogue and keeps values/units stored',
    (tester) async {
      final result = <String, dynamic>{
        'marker': 'ferritin',
        'value': 42.0,
        'unit': 'ng/mL',
        'taken_on': '2026-09-18',
      };
      await tester.pumpWidget(
        host(
          HealthScreen(
            data: const HealthData(),
            tab: 4,
            labs: LabsData(results: [result], markers: kLabMarkers),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ферритин'), findsOneWidget);
      expect(find.text('нг/мл'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Ferritin'), findsNothing);
      expect(find.text('ng/mL'), findsNothing);
      expect(result, {
        'marker': 'ferritin',
        'value': 42.0,
        'unit': 'ng/mL',
        'taken_on': '2026-09-18',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('actual what-changed page localizes dynamic formatter evidence', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const WhatChangedScreen(
          data: WhatChangedData(
            day: '2026-09-18',
            findings: [_rhr, _sleep],
            longestHistory: 28,
            hadToday: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(sweepFindingText(_rhr, 'ru')), findsOneWidget);
    expect(find.text(sweepFindingText(_sleep, 'ru')), findsOneWidget);
    expect(find.text(_rhr.text), findsNothing);
    expect(find.text(_sleep.text), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actual journal association uses translated catalogue names', (
    tester,
  ) async {
    final row = <String, dynamic>{
      'field': 'alcohol_units',
      'field_label': 'Alcohol',
      'field_unit': 'units',
      'outcome': 'rhr',
      'outcome_label': 'Resting HR',
      'unit': 'bpm',
      'binary': true,
      'delta': 6,
      'n_with': 11,
      'n_without': 20,
      'cohens_d': .7,
    };
    await tester.pumpWidget(host(JournalFindings(rows: [row])));
    await tester.pumpAndSettle();
    final text = tester
        .widgetList<Text>(find.byType(Text))
        .map((e) => e.data ?? '')
        .join('\n');
    expect(text, contains('Алкоголь'));
    expect(text, contains('Пульс в покое'));
    expect(text, contains('6.0 уд/мин'));
    expect(text, isNot(contains('Alcohol')));
    expect(text, isNot(contains('Resting HR')));
    expect(row['field'], 'alcohol_units');
    expect(row['unit'], 'bpm');
    expect(tester.takeException(), isNull);
  });
}
