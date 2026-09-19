import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> readStrings(String name, String language) {
  final text = File(
    'ios/Runner/$language.lproj/$name.strings',
  ).readAsStringSync();
  final pattern = RegExp(
    r'^("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*");$',
    multiLine: true,
  );
  return {
    for (final m in pattern.allMatches(text))
      jsonDecode(m[1]!) as String: jsonDecode(m[2]!) as String,
  };
}

void main() {
  test(
    'all native shortcut metadata and invocation phrases have Russian resources',
    () {
      for (final resource in ['Localizable', 'AppShortcuts']) {
        final en = readStrings(resource, 'en');
        final ru = readStrings(resource, 'ru');
        expect(en, hasLength(15));
        expect(ru.keys.toSet(), en.keys.toSet());
        for (final value in ru.values) {
          expect(value, matches(RegExp('[А-Яа-я]')));
          if (resource == 'AppShortcuts') {
            expect(r'${applicationName}'.allMatches(value), hasLength(1));
          }
        }
      }
    },
  );
  test(
    'Siri metadata stays extractable literals and resources are bundled in Runner',
    () {
      final swift = File('ios/OpenStrapIntents.swift').readAsStringSync();
      final localized = readStrings('Localizable', 'ru');
      final titles = RegExp(
        r'static var title: LocalizedStringResource = "([^"]+)"',
      ).allMatches(swift).map((m) => m[1]!);
      expect(titles, hasLength(5));
      for (final title in titles) {
        expect(localized, contains(title));
      }
      final pbx = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      for (final resource in ['Localizable.strings', 'AppShortcuts.strings']) {
        expect(pbx, contains('$resource in Resources'));
        expect(pbx, contains('name = $resource;'));
        expect(pbx, contains('path = ru.lproj/$resource;'));
        expect(pbx, contains('path = en.lproj/$resource;'));
      }
      expect(swift, contains('string(forKey: "widget_language")'));
      expect(swift, contains('Locale.preferredLanguages'));
      expect(swift, contains('Ваша готовность к нагрузке'));
      expect(swift, contains('данных о сне пока нет'));
    },
  );
}
