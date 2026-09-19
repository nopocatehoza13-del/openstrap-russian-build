import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/l10n/app_localizations.dart';
import 'package:openstrap_edge/models/metric.dart';
import 'package:openstrap_edge/ui2/app_shell.dart';
import 'package:openstrap_edge/ui2/familiar/data.dart';
import 'package:openstrap_edge/ui2/familiar/screens.dart';
import 'package:openstrap_edge/ui2/screens/health_screen.dart';
import 'package:openstrap_edge/ui2/screens/home_screen.dart';
import 'package:openstrap_edge/ui2/theme.dart';
import 'package:personal_analytics/personal_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openstrap_edge/state/prefs.dart';

// Fixtures live ONLY in tests. They are never linked into the application.
const fixture = FamiliarData(
  day: '2026-09-19',
  home: HomeData(
    readiness: Metric(value: 82),
    strain: Metric(value: 12.7),
    sleepMin: Metric(value: 446),
    sleepNeedMin: Metric(value: 480),
    rhr: Metric(value: 56),
    steps: Metric(value: 8450),
    caloriesTotal: Metric(value: 2240),
  ),
  health: HealthData(
    today: {
      'resp': {'value': 14.2},
      'hrv': {'rmssd': 48},
      'skin_temp': {'value': -.4},
      'stress': {'value': 27},
    },
  ),
  sleep: {'duration_min': 446, 'onset_ts': 1789755000, 'wake_ts': 1789781760},
  age: AgeEstimate(
    35,
    32.1,
    {'rhr': -.8, 'hrv': -.7, 'sleep': 0, 'consistency': -.9, 'steps': -.5},
    {'rhr': 7, 'hrv': 7, 'sleep': 7, 'consistency': 7, 'steps': 7},
    '2026-09-13',
    '2026-09-19',
  ),
);

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildTheme(Brightness.dark),
  builder: (c, w) => MediaQuery(
    data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
    child: w!,
  ),
  home: Scaffold(
    body: RepaintBoundary(
      key: const ValueKey('capture'),
      child: ColoredBox(color: const Color(0xFF10181B), child: child),
    ),
  ),
);

void main() {
  test('temperature stays Celsius, never relabels a z-score', () {
    expect(fixture.temperatureUnit, '°C');
    expect(fixture.temperature, isNull);
    const imported = FamiliarData(
      health: HealthData(
        today: {
          'imported_vitals': {'skin_temperature_c': 33.2},
        },
      ),
    );
    expect(imported.temperatureUnit, '°C');
    expect(imported.temperature, 33.2);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.ensureLoaded();
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in manifest) {
      final loader = FontLoader(family['family'] as String);
      for (final font in family['fonts']) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  for (final width in [320.0, 390.0]) {
    for (final entry in <String, Widget>{
      'home': const FamiliarDashboard(data: fixture),
      'health': const FamiliarDashboard(data: fixture, health: true),
      'empty': const FamiliarDashboard(data: FamiliarData()),
      'planner': const FamiliarSleepPlanner(data: fixture),
      'age': const FamiliarAgeDetail(data: fixture),
      'stress': const FamiliarStressDetail(data: fixture),
      'monitor': const FamiliarMonitorDetail(data: fixture),
      'more': const FamiliarMore(),
      'settings': const FamiliarSettings(),
    }.entries) {
      testWidgets('${entry.key} fits $width and scrolling', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 844);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(app(entry.value));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (width == 390 && Platform.isWindows) {
          await expectLater(
            find.byKey(const ValueKey('capture')),
            matchesGoldenFile('familiar_goldens/${entry.key}.png'),
          );
        }
        final list = find.byType(ListView).first;
        await t.drag(list, const Offset(0, -450));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  }
  testWidgets('numeric monitor remains a drilldown', (t) async {
    await t.pumpWidget(app(const FamiliarDashboard(data: fixture)));
    await t.pumpAndSettle();
    expect(find.text('14,2'), findsOneWidget);
    expect(find.text('56'), findsOneWidget);
    expect(find.text('48'), findsOneWidget);
    await t.tap(find.text('МОНИТОР ЗДОРОВЬЯ'));
    await t.pumpAndSettle();
    expect(find.text('Монитор здоровья'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('stress scopes never relabel night as daytime', (t) async {
    await t.pumpWidget(app(const FamiliarStressDetail(data: fixture)));
    await t.pumpAndSettle();
    expect(find.text('27 / 100'), findsOneWidget);
    await t.tap(find.text('Весь день'));
    await t.pumpAndSettle();
    expect(find.text('27 / 100'), findsNothing);
    expect(find.text('—'), findsOneWidget);
    await t.tap(find.text('Без активности'));
    await t.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
    await t.tap(find.text('Сон'));
    await t.pumpAndSettle();
    expect(find.text('27 / 100'), findsOneWidget);
  });
  testWidgets('planner target persists without arming alarm', (t) async {
    await t.pumpWidget(app(const FamiliarSleepPlanner(data: fixture)));
    await t.pumpAndSettle();
    await t.tap(find.text('85%'));
    await t.pumpAndSettle();
    expect(Prefs.getInt('familiar.sleepGoal', 0), 85);
    expect(Prefs.getInt('familiar.wakeMinute', -1), -1);
  });
  testWidgets('four visible tabs preserve old indices and extra routes', (
    t,
  ) async {
    expect(ShellDomain.nutrition.index, 2);
    expect(ShellDomain.workout.index, 3);
    expect(ShellDomain.wellness.index, 4);
    await t.pumpWidget(
      app(AppShell(builder: (_, d) => Text('view-${d.name}'))),
    );
    await t.pumpAndSettle();
    expect(find.text('Ещё'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
    await t.tap(find.text('Ещё'));
    await t.pumpAndSettle();
    expect(find.text('view-more'), findsOneWidget);
    await t.tap(find.text('Настройки'));
    await t.pumpAndSettle();
    expect(find.text('view-settings'), findsOneWidget);
  });
  test('dated curves preserve absent calendar days', () {
    final points = [
      (t: DateTime(2026, 9, 17, 12).millisecondsSinceEpoch ~/ 1000, v: 5.0),
      (t: DateTime(2026, 9, 19, 12).millisecondsSinceEpoch ~/ 1000, v: 7.0),
    ];
    expect(datedSeries(points, DateTime(2026, 9, 19), 3), [5.0, null, 7.0]);
  });
}
