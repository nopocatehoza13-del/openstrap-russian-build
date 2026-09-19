import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openstrap_edge/notify/notification_copy.dart';
import 'package:openstrap_edge/compute/findings.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  String ru(String text) => notificationText(text, language: 'ru');
  tearDown(() => binding.platformDispatcher.clearLocalesTestValue());
  test(
    'notification language uses explicit app override and then system',
    () async {
      binding.platformDispatcher.localesTestValue = [const Locale('en', 'US')];
      SharedPreferences.setMockInitialValues({'locale_override': 'ru'});
      expect(await notificationLanguage(), 'ru');
      SharedPreferences.setMockInitialValues({});
      binding.platformDispatcher.localesTestValue = [const Locale('ru', 'RU')];
      expect(await notificationLanguage(), 'ru');
      SharedPreferences.setMockInitialValues({'locale_override': 'en'});
      expect(await notificationLanguage(), 'en');
    },
  );
  test('known static notices are Russian but English fallback is exact', () {
    for (final en in russianNotificationLabels.keys) {
      expect(ru(en), matches(RegExp('[А-Яа-я]')), reason: en);
      expect(notificationText(en, language: 'en'), en);
      expect(notificationText(en, language: 'de'), en);
    }
    expect(ru('A dose is due.'), 'Пора принять лекарство.');
    expect(
      ru('Your strap alarm just fired.'),
      'На браслете сработал будильник.',
    );
  });
  test('numeric values and absent clauses survive copy translation', () {
    expect(
      ru('Recovery 74, slept 7h 17m.'),
      'Восстановление: 74, сон: 7 ч 17 мин.',
    );
    expect(ru('Recovery 74.'), 'Восстановление: 74.');
    expect(
      ru('Your band is at 15%. Charge it soon.'),
      'Заряд браслета — 15%. Скоро потребуется зарядка.',
    );
    expect(
      ru(
        'No new data for about 13 hours. Open OpenStrap to reconnect — background sync may have stalled.',
      ),
      contains('около 13 ч'),
    );
    expect(
      ru('We spotted ~24 min of elevated activity. Tap to log it.'),
      contains('около 24 мин'),
    );
    expect(
      ru('Your bedtime is around 23:15. Start slowing down.'),
      contains('около 23:15'),
    );
  });
  test('battery predictions keep rate, time, reserve and uncertainty', () {
    final before = ru(
      "At 1.2%/h it runs out around 04:15 — before you wake. Charge it now to keep tonight's sleep.",
    );
    expect(before, contains('1.2%/ч'));
    expect(before, contains('примерно в 04:15'));
    expect(before, contains('до вашего пробуждения'));
    final after = ru(
      "At 0.8%/h it runs out around 08:30, just after your usual wake time — about 4% left when you get up. Charge it now to keep tonight's sleep.",
    );
    expect(after, contains('около 4%'));
    expect(after, contains('вскоре после'));
  });
  test('health warning titles and bullet bodies keep screening disclaimer', () {
    final f = Finding(FindingKind.irregularRhythm, '2026-09-19');
    expect(ru(f.title), contains('скрининг'));
    expect(ru('• ${f.title} — ${f.detail}'), contains('не диагноз'));
    expect(ru('2 things to look at'), 'Поводов обратить внимание: 2');
  });
  test('unknown diagnostics, AI text and user text are never guessed', () {
    const text = 'Personal note: water helped. PlatformException(code: -42)';
    expect(ru(text), text);
    expect(ru(''), '');
  });
}
