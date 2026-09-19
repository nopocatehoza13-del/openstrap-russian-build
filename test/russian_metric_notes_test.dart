import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/models/metric.dart';
import 'package:openstrap_edge/ui2/grammar.dart';

void main() {
  group('Russian metric absence notes', () {
    test('English remains the default and other locales retain the fallback', () {
      const note = 'need_baseline:have=4,need=7';
      expect(needMessageFromNote(note), 'Need 3 more nights');
      expect(needMessageFromNote(note, locale: 'en_US'), 'Need 3 more nights');
      expect(needMessageFromNote(note, locale: 'de'), 'Need 3 more nights');
      expect(whyFromNote('need_input:name=age'), contains('age is not on file'));
    });

    test('Russian night forms cover teens and compound numbers', () {
      const words = {
        1: 'ночь', 2: 'ночи', 4: 'ночи', 5: 'ночей', 11: 'ночей',
        14: 'ночей', 21: 'ночь', 22: 'ночи', 25: 'ночей',
        101: 'ночь', 111: 'ночей',
      };
      for (final entry in words.entries) {
        expect(
          needMessageFromNote('need_baseline:have=0,need=${entry.key}',
              locale: 'ru'),
          'Нужно ещё ${entry.key} ${entry.value}',
        );
      }
    });

    test('regional Russian tags and remaining-count arithmetic are preserved', () {
      for (final locale in ['ru', 'ru_RU', 'ru-RU']) {
        expect(needMessageFromNote('need_baseline:have=4,need=7', locale: locale),
            'Нужно ещё 3 ночи');
        expect(needMessageFromNote('need_baseline:have=9,need=7', locale: locale),
            'Нужно ещё 1 ночь');
      }
      expect(needMoreNightsFromNote('need_baseline:have=4,need=7'), 3);
      expect(baselineCountsFromNote('need_baseline:have=4,need=7'),
          (have: 4, need: 7));
    });

    test('day wording uses Russian forms without changing the gate', () {
      for (final entry in {1: 'день', 3: 'дня', 11: 'дней', 22: 'дня'}.entries) {
        expect(
          whyFromNote('need_baseline:have=0,need=${entry.key}',
              unit: 'days', locale: 'ru'),
          'Носите браслет ещё ${entry.key} ${entry.value}, чтобы получить оценку',
        );
      }
    });

    test('every known missing input has Russian copy', () {
      const names = [
        'age', 'weight_kg', 'height_cm', 'sex', 'wake_hr', 'hr_samples',
        'resting_hr', 'scored_night', 'nn_beats', 'resp_windows',
        'accel_1hz', 'imported_day', 'today_activity', 'tst_min',
        'wake_time', 'efficiency', 'observed_ceiling', 'maximal_effort',
        'resting_hr_days', 'manual_zones', 'sessions',
      ];
      for (final name in names) {
        final copy = whyFromNote('need_input:name=$name', locale: 'ru');
        expect(copy, isNotNull, reason: name);
        expect(copy, matches(RegExp('[А-Яа-яЁё]')), reason: name);
        expect(copy, isNot(matches(RegExp('[A-Za-z]'))), reason: name);
      }
    });

    test('reported counts stay literal and do not invent measurement units', () {
      final copy = whyFromNote('need_input:name=nn_beats,have=12,need=20',
          locale: 'ru');
      expect(copy, endsWith('Есть: 12; нужно: 20.'));
    });

    test('imported days do not promise recovery by wearing the band', () {
      final copy = whyFromNote('need_input:name=imported_day', locale: 'ru')!;
      expect(copy, contains('только ночь'));
      expect(copy, contains('нет и исходных данных'));
      expect(copy, isNot(contains('Носите')));
    });

    test('unknown reasons still abstain and pipeline diagnostics stay verbatim', () {
      for (final note in <String?>[
        null, '', '   ', 'unknown_cause', 'some_new_gate:id=7',
        'need_input:name=cosmic_rays',
      ]) {
        expect(whyFromNote(note, locale: 'ru'), isNull, reason: '$note');
      }
      const prose = 'refused: the red and IR channels are one signal';
      expect(whyFromNote(prose, locale: 'ru'), prose);
      expect(needMessageFromNote(prose, locale: 'ru'), isNull);
      expect(whyFromNote('unknown_device_family:id=none', locale: 'ru'),
          contains('В записях не указано, каким браслетом'));
    });

    test('StatusCard uses Russian generic absence and baseline messages', () {
      final unknown = StatusCard.forMetric('Нет данных', Metric.empty,
          locale: 'ru')!;
      expect(unknown.why, 'Причина отсутствия показателя не записана.');
      final waiting = StatusCard.forMetric(
          'Нет оценки', const Metric(note: 'need_baseline:have=4,need=7'),
          locale: 'ru')!;
      expect(waiting.fix, 'Нужно ещё 3 ночи');
      expect(waiting.why,
          'Пока недостаточно истории, чтобы определить ваш обычный уровень.');
      expect(waiting.why, isNot(contains('Not enough')));
    });

    test('StatusCard preserves pipeline precedence and supplied gap evidence', () {
      final card = StatusCard.forMetric(
          'Нет калорий', const Metric(note: 'need_input:name=weight_kg'),
          locale: 'ru', why: 'Не использовать эту догадку.',
          gap: 'Записано 12 минут.')!;
      expect(card.why, startsWith('Ваш вес не указан'));
      expect(card.why, endsWith('Записано 12 минут.'));
      expect(card.why, isNot(contains('догадку')));
      expect(StatusCard.forMetric('Есть данные',
          const Metric(value: 42, confidence: 1), locale: 'ru'), isNull);
    });
  });
}
