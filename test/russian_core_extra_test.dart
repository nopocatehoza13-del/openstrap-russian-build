import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/l10n/ai_response_language.dart';
import 'package:openstrap_edge/l10n/ru_core_extra.dart';
import 'package:openstrap_edge/l10n/ru_coach_extra.dart';
import 'package:openstrap_edge/coach/coach_engine.dart';

void main() {
  test('units are presentation only and preserve values and unknown prose', () {
    expect(ruCoreText('12.75 br/min', locale: 'ru'), '12.75 дых./мин');
    expect(ruCoreText('7h 08m', locale: 'ru'), '7 ч 08 мин');
    expect(ruCoreText('2 points', locale: 'ru'), '2 балла');
    expect(ruCoreText('1314.0 ms²', locale:'ru'), '1314.0 мс²');
    expect(ruCoreText('2ms', locale:'ru'), '2 мс');
    expect(ruCoreText('2m/s', locale:'ru'), '2m/s');
    expect(ruCoreText('51 ms', locale: 'en'), '51 ms');
    expect(ruCoreText('history of sleep', locale: 'ru'), 'history of sleep');
    expect(ruCoreText('Alex wrote this note', locale: 'ru'), 'Alex wrote this note');
  });
  test('common absence, chart and live-HR messages are Russian', () {
    for (final key in ['No data yet','No live reading','Awake','Light','Deep','LF power','higher than usual','Reading your overnight RR…']) {
      expect(ruCoreText(key, locale:'ru'), matches(RegExp('[А-Яа-яЁё]')));
      expect(ruCoreText(key, locale:'en'), key);
    }
    expect(ruCoreText('No beat in the last 12 seconds.', locale:'ru'), 'За последние 12 с данных о пульсе не поступало.');
    expect(ruCoreText('Zone 3', locale:'ru'), 'Зона 3');
  });
  test('AI instruction leaves original messages and schema unchanged', () {
    final messages = <Map<String,dynamic>>[
      {'role':'system','content':'Return {"reply": string, "tags": [string]}. Use caffeine as a tag.'},
      {'role':'user','content':'Мой пульс 57.'},
    ];
    final ru = aiMessagesForLanguage(messages,'ru-RU');
    expect(ru.first['content'], contains('Response language: Russian (ru)'));
    expect(ru.first['content'], contains('Do NOT translate JSON keys'));
    expect(ru.first['content'], startsWith(messages.first['content']));
    expect(ru.last, messages.last);
    expect(messages.first['content'], isNot(contains('Response language')));
    expect(aiMessagesForLanguage(messages,'en'), same(messages));
  });
  test('coach confirmation preserves actual action arguments and safety text', () {
    final args = <String,dynamic>{'name':'User medicine','time':'21:00','weekdays':[1,4]};
    final action = ActionRequest(tool:'add_medication',title:'Add a medication',summary:'Original summary',args:args);
    final ru = coachActionSummary(action,'ru');
    expect(ru, contains('User medicine'));
    expect(ru, contains('21:00, пн, чт'));
    expect(ru, contains('не проверяет взаимодействия'));
    expect(coachActionSummary(action,'en'), 'Original summary');
    expect(args, {'name':'User medicine','time':'21:00','weekdays':[1,4]});
  });
}
