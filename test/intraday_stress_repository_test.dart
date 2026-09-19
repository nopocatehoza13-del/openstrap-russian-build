import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:openstrap_edge/data/db.dart';
import 'package:openstrap_edge/data/local_repository_impl.dart';
import 'package:openstrap_edge/compute/derivation_engine.dart'
    show kAlgoVersion;
import 'package:openstrap_edge/ui2/familiar/data.dart';
import 'package:personal_analytics/intraday_stress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalRepositoryImpl repo;
  final date = DateTime(2026, 9, 18),
      start = DateTime(2026, 9, 18).millisecondsSinceEpoch ~/ 1000;
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDb.dbName = 'intraday_stress_repository.db';
    await databaseFactory.deleteDatabase(
      path.join(await databaseFactory.getDatabasesPath(), LocalDb.dbName),
    );
    repo = LocalRepositoryImpl(getProfileMap: () => {});
  });
  tearDownAll(() async {
    await LocalDb.close();
    await databaseFactory.deleteDatabase(
      path.join(await databaseFactory.getDatabasesPath(), LocalDb.dbName),
    );
  });
  test(
    'versioned SQLite -> read-only repository -> off-isolate projection -> UI data',
    () async {
      final model = scoreIntradayStress(
        minutes: [
          for (var i = 0; i < 360; i++)
            {
              't': start + i * 60,
              'n': 60,
              'hr': i < 120
                  ? 50.0
                  : i < 300
                  ? 65.0
                  : 100.0,
              'motion': 0.0,
            },
        ],
        start: start,
        end: start + 86400,
        observedUntil: start + 21600,
        sleep: [(start: start, end: start + 7200)],
      );
      await LocalDb.putDayResult(
        dayId: '2026-09-18',
        algoVersion: kAlgoVersion,
        windowJson: '{}',
        payloadJson: jsonEncode({
          'stress': {'score': 27},
          'intraday_stress': model,
        }),
      );
      final read = await repo.getDayStress('2026-09-18');
      expect(jsonEncode(read['intraday_stress']), jsonEncode(model));
      expect((read['stress'] as Map)['score'], 27);
      final before = await FamiliarData.load(repo, date);
      expect(
        (before.intradayStress['summaries'] as Map)['rest']['covered_sec'],
        14400,
      );
      await LocalDb.putSession({
        'id': 'manual-new',
        'type': 'other',
        'start_ts': start + 18000,
        'end_ts': start + 21600,
        'status': 'done',
        'source': 'manual',
        'created_at': start,
      });
      final after = await FamiliarData.load(repo, date);
      expect(
        (after.intradayStress['summaries'] as Map)['rest']['covered_sec'],
        10800,
      );
      // Persisted raw-minute evidence is unchanged. Correction needs no raw replay.
      expect(
        jsonEncode((await repo.getDayStress('2026-09-18'))['intraday_stress']),
        jsonEncode(model),
      );
      await LocalDb.deleteSession('manual-new');
      final undone = await FamiliarData.load(repo, date);
      expect(
        jsonEncode(undone.intradayStress),
        jsonEncode(before.intradayStress),
      );
    },
  );
  test('cross-midnight, live, and half-open workout bounds', () async {
    await LocalDb.putSession({
      'id': 'midnight',
      'type': 'other',
      'start_ts': start - 600,
      'end_ts': start + 600,
      'status': 'done',
      'source': 'manual',
      'created_at': start,
    });
    await LocalDb.putSession({
      'id': 'touch',
      'type': 'other',
      'start_ts': start - 1200,
      'end_ts': start,
      'status': 'done',
      'source': 'manual',
      'created_at': start,
    });
    await LocalDb.putSession({
      'id': 'live',
      'type': 'other',
      'start_ts': start + 1800,
      'status': 'live',
      'source': 'manual',
      'created_at': start,
    });
    final rows = await LocalDb.stressSessionsInRange(start, start + 86400);
    expect(rows.map((r) => r['id']), containsAll(['midnight', 'live']));
    expect(rows.map((r) => r['id']), isNot(contains('touch')));
    final read = await repo.getDayStress('2026-09-18');
    expect(
      (read['stress_sessions'] as List).map((r) => r['id']),
      contains('midnight'),
    );
  });
  test(
    'existing WHOOP summary import does not invent intraday samples',
    () async {
      await LocalDb.putDayResult(
        dayId: '2026-09-17',
        algoVersion: kAlgoVersion,
        windowJson: '{}',
        payloadJson: jsonEncode({
          'source': 'whoop_export',
          'imported': true,
          'stress': {'score': 75},
        }),
      );
      final data = await FamiliarData.load(repo, DateTime(2026, 9, 17));
      expect(data.intradayStress, isEmpty);
    },
  );
}
