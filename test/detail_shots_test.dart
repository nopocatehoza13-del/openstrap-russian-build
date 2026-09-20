// Renders the Familiar detail screens (sleep, recovery, strain, home, health)
// on the mock's demo numbers into test/detail_shots/*.png for a one-to-one
// comparison with design/whoop-mock-v6-shots. Windows only; run with
// --update-goldens to (re)write. Not part of CI.
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

final _today = DateTime(2026, 9, 20);
int _t(int daysAgo) => DateTime(2026, 9, 20 - daysAgo, 12).millisecondsSinceEpoch ~/ 1000;
int _sec(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
String _label(int daysAgo) {
  final d = DateTime(2026, 9, 20 - daysAgo);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

List<double> _gen(double base, int n, double spread, int seed) {
  var s = seed;
  double r() {
    s = (s * 9301 + 49297) % 233280;
    return s / 233280;
  }
  return [for (var i = 0; i < n; i++) double.parse((base + (r() - .5) * spread * 2 + math.sin(i / 3) * spread * .3).toStringAsFixed(1))];
}

List<ChartPoint> _pts(double base, double spread, int seed, [List<double>? week, double floor = 0]) {
  final vals = _gen(base, 180, spread, seed);
  if (week != null) vals.replaceRange(173, 180, week);
  return [for (var i = 0; i < 180; i++) (t: _t(179 - i), v: math.max(floor, vals[i]))];
}

final _onset = DateTime(2026, 9, 19, 23, 12), _wake = DateTime(2026, 9, 20, 6, 54);

List<Map<String, dynamic>> _nightHr() => [
  for (var t = _sec(_onset) - 900; t <= _sec(_wake) + 900; t += 60)
    {'t': t, 'v': 52 + 6 * math.sin((t - _sec(_onset)) / 3600 * 1.3) - 3 * math.cos((t - _sec(_onset)) / 900) + (t < _sec(_onset) || t > _sec(_wake) ? 8 : 0)},
];

List<Map<String, dynamic>> _hypno() {
  const pattern = ['wake', 'light', 'deep', 'light', 'rem', 'light', 'deep', 'light', 'rem', 'wake', 'light', 'rem', 'light', 'deep', 'light', 'rem', 'light', 'rem', 'wake'];
  final total = _sec(_wake) - _sec(_onset);
  return [for (var i = 0; i < pattern.length; i++) {'t': _sec(_onset) + (total * i / pattern.length).round(), 'stage': pattern[i]}];
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
    out.add({'date': _label(ago), 'onset_ts': _sec(onset), 'wake_ts': _sec(up)});
  }
  return out;
}

const List<double> _weekStrain = [9.1, 12.4, 7.2, 11.0, 8.6, 13.4, 10.2];
const List<double> _weekRec = [53.0, 72, 64, 67, 88, 61, 76];
const List<double> _weekTst = [465.0, 492, 470, 432, 441, 452, 462];
const List<double> _weekSteps = [7200.0, 9100, 6400, 10300, 8450, 7800, 12459];
const List<double> _weekZ13 = [38.0, 62, 0, 82, 39, 104, 65];
const List<double> _weekZ45 = [8.0, 12, 0, 15, 6, 19, 12];

Map<String, dynamic> _whoopInsights() => {
  'need': {'need_sec': 495 * 60, 'baseline_sec': 452 * 60, 'strain_add_sec': 25 * 60, 'debt_sec': 18 * 60, 'nap_sec': 0, 'baseline_source': 'personal'},
  'baseline': {'sec': 452 * 60, 'source': 'personal', 'nights': 30},
  'debt_outstanding_sec': 70 * 60,
  'last_night': {
    'date': '2026-09-20',
    'tst_sec': 462 * 60,
    'in_bed_sec': 500 * 60,
    'need': {'need_sec': 495 * 60, 'baseline_sec': 452 * 60, 'strain_add_sec': 25 * 60, 'debt_sec': 18 * 60, 'nap_sec': 0, 'baseline_source': 'personal'},
    'performance': {
      'performance_pct': 85,
      'hours_vs_need_pct': 93,
      'consistency_pct': 68,
      'efficiency_pct': 92,
      'high_stress_pct': 2,
      'levels': {'hours': 2, 'consistency': 0, 'efficiency': 2, 'stress': 2},
    },
  },
  'recovery': {'date': '2026-09-20', 'score': 76, 'band': 'green'},
  'zones_week': {'z13_min': 390, 'z45_min': 72},
  'zones_prev_week': {'z13_min': 355, 'z45_min': 60},
  'week': [
    for (var i = 6; i >= 0; i--)
      {
        'date': _label(i),
        'whoop_strain': _weekStrain[6 - i],
        'readiness': _weekRec[6 - i],
        'tst_min': _weekTst[6 - i],
        'steps': _weekSteps[6 - i],
        'rhr': [55.0, 54, 56, 52, 53, 52, 52][6 - i],
        'rmssd': [58.0, 61, 55, 66, 60, 64, 64][6 - i],
        'whoop_z13_min': _weekZ13[6 - i],
        'whoop_z45_min': _weekZ45[6 - i],
        'efficiency': 92.0,
        'whoop_max_hr': 185.0,
      },
  ],
};

final fixture = FamiliarData(
  day: '2026-09-20',
  home: const HomeData(readiness: Metric(value: 76), strain: Metric(value: 10.2), sleepMin: Metric(value: 462), sleepNeedMin: Metric(value: 495), rhr: Metric(value: 52), steps: Metric(value: 12459), caloriesTotal: Metric(value: 2340)),
  health: HealthData(
    today: const {'resp': {'value': 14.4}, 'hrv': {'rmssd': 64}, 'skin_temp': {'value': .3}, 'stress': {'value': 27}},
    insights: {'whoop': _whoopInsights()},
    profile: const {'age': 35, 'sex': 'male'},
    charts: {
      'hrv': _pts(59, 8.6, 13, [58, 61, 55, 66, 60, 64, 64]),
      'resting_hr': _pts(54, 3.2, 13, [55, 54, 56, 52, 53, 52, 52]),
      'resp_rate': _pts(14.4, .55, 13),
      'sleep': _pts(452, 60, 11, _weekTst),
    },
  ),
  sleep: {
    'has_sleep': true,
    'duration_min': 462,
    'in_bed_min': 500,
    'awake_min': 38,
    'efficiency': .92,
    'onset_ts': _sec(_onset),
    'wake_ts': _sec(_wake),
    'light_min': 262,
    'deep_min': 92,
    'rem_min': 108,
    'awakenings': 3,
    'hypnogram': _hypno(),
  },
  nightHr: _nightHr(),
  whoopDay: {
    'strain': 10.2,
    'strain_intensity': .31,
    'band': 'moderate',
    'max_hr': 185,
    'rhr': 52,
    'zone_lower_bpm': [119, 132, 145, 158, 172],
    'zones': {'z1': 38, 'z2': 17, 'z3': 10, 'z4': 5, 'z5': 3},
    'strain_curve': [for (var m = 0; m < 14 * 60; m += 10) {'t': _sec(_wake) + m * 60, 'v': 10.2 * (1 - math.exp(-m / 300))}],
    'spo2': {'pct': 97, 'samples': 41, 'lo': 95, 'hi': 99, 'source': 'band'},
    'skin_temp': {'c': 33.8, 'baseline_c': 33.5, 'dev_c': .3, 'nights': 12},
  },
  activities: [
    {'id': 'w1', 'title': 'Бег', 'type': 'run', 'start_ts': _sec(DateTime(2026, 9, 20, 18)), 'end_ts': _sec(DateTime(2026, 9, 20, 18, 48)), 'duration_min': 48, 'strain': 12.4, 'whoop_strain': 12.4, 'avg_hr': 152, 'max_hr': 178, 'calories': 520, 'zone_min': [5, 12, 20, 9, 2], 'whoop_zone_min': [5, 12, 20, 9, 2], 'source': 'manual'},
  ],
  recovery: _pts(66, 22, 11, _weekRec),
  strain: _pts(10.2, 4, 11, _weekStrain),
  steps: _pts(8100, 2600, 11, _weekSteps),
  series: {
    'whoop_strain': _pts(10.2, 4, 11, _weekStrain),
    'whoop_recovery': _pts(66, 22, 11, _weekRec),
    'whoop_sleep_perf': _pts(86, 12, 11, [93, 98, 93, 86, 88, 91, 85]),
    'whoop_consistency': _pts(77, 16, 11, [81, 84, 72, 69, 78, 66, 72]),
    'whoop_need_min': _pts(495, 40, 11, [488, 502, 481, 495, 510, 478, 495]),
    'deep': _pts(88, 10, 11, [88, 95, 90, 80, 86, 84, 92]),
    'rem': _pts(104, 12, 11, [100, 118, 105, 96, 99, 110, 108]),
    'light': _pts(250, 30, 11, [262, 270, 255, 240, 248, 252, 262]),
    'efficiency': _pts(91, 4, 11, [92, 94, 90, 89, 93, 88, 92]),
    'calories': _pts(2340, 500, 11),
    'whoop_z13_min': _pts(60, 30, 11, _weekZ13),
    'whoop_z45_min': _pts(20, 12, 11, _weekZ45),
    'whoop_z1_min': _pts(36, 18, 11, [20, 35, 0, 48, 25, 60, 38]),
    'whoop_z2_min': _pts(17, 9, 12, [12, 18, 0, 22, 10, 30, 17]),
    'whoop_z3_min': _pts(8, 5, 13, [6, 9, 0, 12, 4, 14, 10]),
    'whoop_z4_min': _pts(7, 4, 14, [5, 7, 0, 9, 4, 12, 7]),
    'whoop_z5_min': _pts(4, 3, 15, [3, 5, 0, 6, 2, 7, 5]),
    'whoop_spo2_pct': _pts(97, 1.5, 11, null, 90),
    'whoop_skin_temp_c': _pts(33.4, .3, 11),
  },
  sleepWindows: _windows(),
  batteryPct: 84,
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
  final view = WhView(fixture, _today);
  final screens = <String, Widget>{
    'sleep': WhSleep(view: view),
    'recovery': WhRecovery(view: view),
    'strain': WhStrain(view: view),
    'home': FamiliarDashboard(data: fixture),
    'health': FamiliarDashboard(data: fixture, health: true),
  };
  for (final e in screens.entries) {
    testWidgets('detail ${e.key}', (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 3600);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(app(e.value));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      if (Platform.isWindows) {
        await expectLater(find.byKey(const ValueKey('capture')), matchesGoldenFile('detail_shots/${e.key}.png'));
      }
    });
  }
}
