// Renders every Familiar trend screen (metric × period) on the mock's demo
// numbers into test/trend_shots/*.png, so the native charts can be compared
// with design/whoop-mock-v6-shots one to one. Windows only (fonts, goldens);
// run with --update-goldens to (re)write the shots. Not part of CI.
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/models/metric.dart';
import 'package:openstrap_edge/state/prefs.dart';
import 'package:openstrap_edge/ui2/familiar/data.dart';
import 'package:openstrap_edge/ui2/familiar/screens.dart';
import 'package:openstrap_edge/ui2/familiar/wh_data.dart';
import 'package:openstrap_edge/ui2/screens/health_screen.dart';
import 'package:openstrap_edge/ui2/screens/home_screen.dart';
import 'package:openstrap_edge/ui2/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _today = DateTime(2026, 9, 20); // the mock's Sunday
int _t(int daysAgo) => DateTime(2026, 9, 20 - daysAgo, 12).millisecondsSinceEpoch ~/ 1000;

/// The mock's generator (app.js `series`): deterministic pseudo-random walk.
List<double> _gen(double base, int n, double spread, int seed) {
  var s = seed;
  double r() {
    s = (s * 9301 + 49297) % 233280;
    return s / 233280;
  }
  return [for (var i = 0; i < n; i++) double.parse((base + (r() - .5) * spread * 2 + math.sin(i / 3) * spread * .3).toStringAsFixed(1))];
}

/// 180 days oldest first, the last seven replaced by the mock's WEEK values.
List<ChartPoint> _pts(double base, double spread, int seed, [List<double>? week, double floor = 0]) {
  final vals = _gen(base, 180, spread, seed);
  if (week != null) vals.replaceRange(173, 180, week);
  return [for (var i = 0; i < 180; i++) (t: _t(179 - i), v: math.max(floor, vals[i]))];
}

List<Map<String, dynamic>> _windows() {
  const tib = [[23.2, 7.05], [23.75, 7.6], [24.5, 8.1], [23.1, 6.75], [23.9, 7.35], [25.2, 8.6], [23.2, 6.9]];
  final out = <Map<String, dynamic>>[];
  for (var ago = 59; ago >= 0; ago--) {
    final w = ago < 7 ? tib[6 - ago] : [23.5 + math.sin(ago.toDouble()) * .3, 7.3 + math.cos(ago * 1.3) * .25];
    final wake = DateTime(2026, 9, 20 - ago);
    final bedH = w[0] % 24, bedPrev = w[0] < 24;
    final onset = DateTime(wake.year, wake.month, wake.day - (bedPrev ? 1 : 0), bedH.floor(), ((bedH % 1) * 60).round());
    final up = DateTime(wake.year, wake.month, wake.day, w[1].floor(), ((w[1] % 1) * 60).round());
    out.add({'date': '${wake.year}-${wake.month.toString().padLeft(2, '0')}-${wake.day.toString().padLeft(2, '0')}', 'onset_ts': onset.millisecondsSinceEpoch ~/ 1000, 'wake_ts': up.millisecondsSinceEpoch ~/ 1000});
  }
  return out;
}

final fixture = FamiliarData(
  day: '2026-09-20',
  home: const HomeData(readiness: Metric(value: 76), strain: Metric(value: 10.2), sleepMin: Metric(value: 462), sleepNeedMin: Metric(value: 495), rhr: Metric(value: 52), steps: Metric(value: 12459)),
  health: HealthData(
    today: const {'resp': {'value': 14.4}, 'hrv': {'rmssd': 64}},
    charts: {
      'hrv': _pts(59, 8.6, 13, [58, 61, 55, 66, 60, 64, 64]),
      'resting_hr': _pts(54, 3.2, 13, [55, 54, 56, 52, 53, 52, 52]),
      'resp_rate': _pts(14.4, .55, 13),
      'sleep': _pts(452, 60, 11, [465, 492, 470, 432, 441, 452, 462]),
    },
  ),
  recovery: _pts(66, 22, 11, [53, 72, 64, 67, 88, 61, 76]),
  strain: _pts(10.2, 4, 11, [9.1, 12.4, 7.2, 11.0, 8.6, 13.4, 10.2]),
  steps: _pts(8100, 2600, 11, [7200, 9100, 6400, 10300, 8450, 7800, 12459]),
  series: {
    'whoop_strain': _pts(10.2, 4, 11, [9.1, 12.4, 7.2, 11.0, 8.6, 13.4, 10.2]),
    'whoop_recovery': _pts(66, 22, 11, [53, 72, 64, 67, 88, 61, 76]),
    'whoop_sleep_perf': _pts(86, 12, 11, [93, 98, 93, 86, 88, 91, 85]),
    'whoop_consistency': _pts(77, 16, 11, [81, 84, 72, 69, 78, 66, 72]),
    'whoop_need_min': _pts(495, 40, 11, [488, 502, 481, 495, 510, 478, 495]),
    'deep': _pts(88, 10, 11, [88, 95, 90, 80, 86, 84, 92]),
    'rem': _pts(104, 12, 11, [100, 118, 105, 96, 99, 110, 108]),
    'calories': _pts(2340, 500, 11),
    'whoop_z13_min': _pts(60, 30, 11, [38, 62, 0, 82, 39, 104, 65]),
    'whoop_z45_min': _pts(20, 12, 11, [8, 12, 0, 15, 6, 19, 12]),
    'whoop_z1_min': _pts(36, 18, 11, [20, 35, 0, 48, 25, 60, 38]),
    'whoop_z2_min': _pts(17, 9, 12, [12, 18, 0, 22, 10, 30, 17]),
    'whoop_z3_min': _pts(8, 5, 13, [6, 9, 0, 12, 4, 14, 10]),
    'whoop_z4_min': _pts(7, 4, 14, [5, 7, 0, 9, 4, 12, 7]),
    'whoop_z5_min': _pts(4, 3, 15, [3, 5, 0, 6, 2, 7, 5]),
    'whoop_spo2_pct': _pts(97, 1.5, 11, null, 90),
    'whoop_skin_temp_c': _pts(33.4, .3, 11),
  },
  sleepWindows: _windows(),
);

Widget app(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildTheme(Brightness.dark),
  home: Scaffold(body: RepaintBoundary(key: const ValueKey('capture'), child: ColoredBox(color: const Color(0xFF10181B), child: child))),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.ensureLoaded();
    final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in manifest) {
      final loader = FontLoader(family['family'] as String);
      for (final font in family['fonts']) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  const metrics = ['hrv', 'resting_hr', 'respiratory_rate', 'steps', 'calories', 'strain', 'recovery', 'sleepperf', 'consistency', 'hours', 'need', 'restorative', 'tib', 'zones13', 'zones45', 'heart_rate', 'skin_temperature'];
  const periods = {'w': 'Нед', 'm': 'Мес', '6m': '6 мес'};
  for (final metric in metrics) {
    for (final p in periods.entries) {
      testWidgets('trend $metric ${p.key}', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(390, 1100);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(app(WhTrend(metric, view: WhView(fixture, _today))));
        await t.pumpAndSettle();
        if (p.key != 'm') {
          await t.tap(find.text(p.value.toUpperCase()));
          await t.pumpAndSettle();
        }
        expect(t.takeException(), isNull);
        if (Platform.isWindows) {
          await expectLater(find.byKey(const ValueKey('capture')), matchesGoldenFile('trend_shots/$metric-${p.key}.png'));
        }
      });
    }
  }
}
