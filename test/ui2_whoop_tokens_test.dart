// The WHOOP tokens are painted directly (never through `P.on`), so this proves
// every ink/accent in `W.inks` clears AA as text on the lightest WHOOP surface
// it can sit on (`W.card2`) — the same floor `ui2_contrast_test` holds for the
// solved palette. Also checks that the WHOOP fonts and icons are registered.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/ui2/theme.dart';

void main() {
  test('WHOOP text inks clear 4.5:1 on W.card2, accents 3:1 on W.card', () {
    final failures = <String>[];
    for (final c in W.inks) {
      final ratio = P.contrast(c, W.card2);
      if (ratio < 4.5) failures.add('ink ${c.toARGB32().toRadixString(16)} → ${ratio.toStringAsFixed(2)}');
    }
    for (final c in W.accents) {
      final ratio = P.contrast(c, W.card);
      if (ratio < 3.0) failures.add('accent ${c.toARGB32().toRadixString(16)} → ${ratio.toStringAsFixed(2)}');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
  test('WHOOP faces and icons are bundled', () {
    expect(File('assets/fonts/WhoopText/WhoopText-Regular.otf').existsSync(), isTrue);
    expect(File('assets/fonts/WhoopNum/WhoopNum-Bold.otf').existsSync(), isTrue);
    final icons = Directory('assets/icons/whoop').listSync().whereType<File>().length;
    expect(icons, greaterThanOrEqualTo(140));
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: WHOOP Text'));
    expect(pubspec, contains('family: WHOOP Num'));
    expect(pubspec, contains('assets/icons/whoop/'));
  });
}
