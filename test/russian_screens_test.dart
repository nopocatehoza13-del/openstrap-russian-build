import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/state/locale_controller.dart';
import 'package:openstrap_edge/ui2/onboarding/pairing.dart';
import 'package:openstrap_edge/ui2/onboarding/profile_setup.dart';
import 'package:openstrap_edge/ui2/onboarding/welcome.dart';
import 'package:openstrap_edge/ui2/profile/profile.dart';
import 'package:openstrap_edge/ui2/profile/settings.dart';
import 'package:openstrap_edge/ui2/ui2.dart';

void main() {
  test('Setting choices translate presentation, not persisted values', () {
    expect(settingsChoiceLabel('Metric', 'ru'), 'Метрические');
    expect(settingsChoiceLabel('Imperial', 'ru'), 'Имперские');
    expect(settingsChoiceLabel('Dark', 'ru'), 'Тёмное');
    expect(settingsChoiceLabel('Light', 'ru'), 'Светлое');
    expect(settingsChoiceLabel('System', 'ru'), 'Как в системе');
    expect(settingsChoiceLabel('Dark', 'en'), 'Dark');
  });
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final files = Directory('assets/fonts/Manrope').listSync().whereType<File>()
        .where((f) => f.path.endsWith('.ttf')).toList();
    for (final family in ['Manrope', '.SF Pro Text']) {
      final loader = FontLoader(family);
      for (final file in files) {
        loader.addFont(file.readAsBytes().then(ByteData.sublistView));
      }
      await loader.load();
    }
    final icons = FontLoader('packages/lucide_icons_flutter/Lucide');
    icons.addFont(rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
    await icons.load();
  });
  final cases = <String, Widget Function()>{
    'welcome': () => WelcomeView(onNew: () {}, onImport: () {}),
    'pairing': () => PairingView(phase: PairPhase.bondRefused, onPair: () {}, onSkip: () {}),
    'profile_setup': () => ProfileSetupView(onSave: (_) async {}),
    'profile': () => const ProfileHomeView(stats: ProfileStats(name: 'Алексей', sources: 2, storageBytes: 1503238553)),
    'settings': () => const MoreSettingsView(units: 'Metric', appearance: 'Dark', phoneSteps: true),
  };
  for (final variant in [
    (320.0, 1.0, Brightness.dark),
    (390.0, 1.0, Brightness.light),
    (390.0, 1.5, Brightness.dark),
    (320.0, 1.5, Brightness.light),
  ]) {
    for (final item in cases.entries) {
      final tag = '${item.key}_${variant.$1.toInt()}_${variant.$2}_${variant.$3.name}';
      testWidgets('Russian actual screen $tag', (tester) async {
        tester.view.physicalSize = Size(variant.$1, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final shot = GlobalKey();
        final controller = LocaleController.seed('ru');
        addTearDown(controller.dispose);
        await tester.pumpWidget(ChangeNotifierProvider<LocaleController>.value(
          value: controller,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildTheme(variant.$3),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(variant.$2)),
              child: child!,
            ),
            home: RepaintBoundary(key: shot, child: item.value()),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tag);
        if (variant.$2 == 1.0) {
          final boundary = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final picture = await boundary.toImage(pixelRatio: 1);
            final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
            final file = File('build/ru-review/$tag.png');
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
      });
    }
  }
}
