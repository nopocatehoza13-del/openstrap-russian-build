import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openstrap_edge/models/payloads.dart';
import 'package:openstrap_edge/state/locale_controller.dart';
import 'package:openstrap_edge/widget/widget_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Object?> written;
  late List<String> writeKeys;
  final messenger = binding.defaultBinaryMessenger;
  final data = TodayData.fromJson({
    'daily': {'readiness': 74, 'strain': 12.4},
    'sleep': {'duration_min': 437, 'need_min': 465},
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    binding.platformDispatcher.localesTestValue = [const Locale('en', 'US')];
    written = {};
    writeKeys = [];
    messenger.setMockMethodCallHandler(const MethodChannel('home_widget'), (
      call,
    ) async {
      if (call.method == 'saveWidgetData') {
        final args = (call.arguments as Map).cast<String, Object?>();
        written[args['id'] as String] = args['data'];
        writeKeys.add(args['id'] as String);
      }
      return true;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('openstrap/ios_config'),
      (call) async {
        return call.method == 'appGroupIdentifier' ? 'group.test' : null;
      },
    );
    await WidgetService.clear();
    written.clear();
  });

  tearDown(() {
    binding.platformDispatcher.clearLocalesTestValue();
    messenger.setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('openstrap/ios_config'),
      null,
    );
  });

  test(
    'Russian override on English iOS labels native snapshot, not numbers',
    () async {
      SharedPreferences.setMockInitialValues({'locale_override': 'ru'});
      await WidgetService.push(data);
      expect(written['widget_language'], 'ru');
      expect(written['ring_recovery_value'], '74');
      expect(written['ring_recovery_sub'], 'Готовность высокая');
      expect(written['ring_strain_value'], '12.4');
      expect(written['ring_strain_sub'], 'из 21');
      expect(written['ring_sleep_value'], '7 ч 17 мин');
      expect(written['ring_sleep_sub'], 'из 7 ч 45 мин');
      expect(written['ring_sleep_frac'], closeTo(437 / 465, 1e-9));
      expect(written['readiness'], 74);
      expect(written['strain'], 12.4);
      expect(written['sleep_min'], 437);
      expect(written['sleep_need_min'], 465);
    },
  );

  test(
    'system Russian is used only without an explicit language override',
    () async {
      binding.platformDispatcher.localesTestValue = [const Locale('ru', 'RU')];
      await WidgetService.push(data);
      expect(written['widget_language'], 'ru');
      final controller = LocaleController.seed(null);
      await controller.setCode('en');
      expect(written['widget_language'], 'en');
      expect(written['ring_sleep_value'], '7h 17m');
      expect(written['ring_strain_sub'], 'of 21');
    },
  );

  test(
    'language switch republishes identical metrics through fingerprint gate',
    () async {
      await WidgetService.push(data);
      expect(written['widget_language'], 'en');
      writeKeys.clear();
      final controller = LocaleController.seed(null);
      await controller.setCode('ru');
      expect(written['widget_language'], 'ru');
      expect(written['ring_sleep_value'], '7 ч 17 мин');
      expect(written['readiness'], 74);
      expect(written['strain'], 12.4);
      expect(written['sleep_min'], 437);
      expect(
        writeKeys,
        isNot(contains('updated_at')),
        reason: 'Changing language must not make old readings look fresh',
      );
      expect(WidgetService.fingerprintKeyOrder, contains('widget_language'));
      await controller.setCode(null);
      expect(written['widget_language'], 'en');
    },
  );

  test(
    'Russian calibration keeps unknown score and original progress',
    () async {
      SharedPreferences.setMockInitialValues({'locale_override': 'ru'});
      await WidgetService.push(
        TodayData.fromJson({
          'daily': {
            'readiness': {'value': null, 'note': 'need_baseline:have=2,need=5'},
          },
        }),
      );
      expect(written['readiness'], -1);
      expect(written['ring_recovery_state'], 1);
      expect(written['ring_recovery_frac'], closeTo(0.4, 1e-9));
      expect(written['ring_recovery_value'], isNot(contains('Calibrating')));
      expect(written['ring_recovery_sub'], matches(RegExp('[А-Яа-я]')));
      expect(written['ring_sleep_state'], 2);
      expect(written['ring_sleep_frac'], -1.0);
    },
  );

  test('battery-only sync also mirrors the app override', () async {
    SharedPreferences.setMockInitialValues({'locale_override': 'ru'});
    await WidgetService.pushBattery(80, false, 'WHOOP 5.0');
    expect(written['widget_language'], 'ru');
    expect(written['batt_pct'], 80);
    expect(written['batt_name'], 'WHOOP 5.0');
  });

  test(
    'language persistence survives unavailable native widget plugins',
    () async {
      messenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('openstrap/ios_config'),
        null,
      );
      final controller = LocaleController.seed(null);
      await controller.setCode('ru');
      expect(controller.code, 'ru');
      expect(
        (await SharedPreferences.getInstance()).getString('locale_override'),
        'ru',
      );
    },
  );
}
