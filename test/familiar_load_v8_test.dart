// FamiliarData.load over a REAL repository with data the v8 loader reads for
// the first time: sessions across 30 days (the previous same-type activity),
// a day result carrying the WHOOP vitals blocks, no sleep, no wear rows.
// Regression for the "Не удалось прочитать данные" screen after v8.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/compute/derivation_engine.dart' show kAlgoVersion;
import 'package:openstrap_edge/data/day_label.dart';
import 'package:openstrap_edge/data/db.dart';
import 'package:openstrap_edge/data/local_repository_impl.dart';
import 'package:openstrap_edge/ui2/familiar/data.dart';
import 'package:openstrap_edge/ui2/familiar/wh_data.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalRepositoryImpl repo;
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDb.dbName = 'familiar_load_v8.db';
    await databaseFactory.deleteDatabase(
      path.join(await databaseFactory.getDatabasesPath(), LocalDb.dbName),
    );
    repo = LocalRepositoryImpl(getProfileMap: () => {'age': 35, 'sex': 'male'});
  });
  tearDownAll(() async {
    await LocalDb.close();
    await databaseFactory.deleteDatabase(
      path.join(await databaseFactory.getDatabasesPath(), LocalDb.dbName),
    );
  });

  test('load survives sessions spanning 30 days plus the WHOOP vitals blocks', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int ts(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
    DateTime at(int daysAgo, int hour) => DateTime(today.year, today.month, today.day - daysAgo, hour);
    await repo.logManualWorkout(startTs: ts(at(40, 8)), endTs: ts(at(40, 9)), type: 'walk');
    await repo.logManualWorkout(startTs: ts(at(20, 7)), endTs: ts(at(20, 8)), type: 'run');
    await repo.logManualWorkout(startTs: ts(at(0, 6)), endTs: ts(at(0, 7)), type: 'run');
    await LocalDb.putDayResult(
      dayId: dayLabelOf(today),
      algoVersion: kAlgoVersion,
      windowJson: '{}',
      payloadJson: jsonEncode({
        'whoop': {
          'strain': 12.3,
          'max_hr': 185,
          'spo2': {'pct': 96.5, 'samples': 40, 'lo': 95, 'hi': 98, 'source': 'band'},
          'skin_temp': {'c': 33.8, 'baseline_c': 33.5, 'dev_c': .3, 'nights': 12},
        },
        'scalars': {'whoop_strain': 12.3, 'whoop_spo2_pct': 96.5, 'whoop_skin_temp_c': 33.8},
      }),
    );
    final data = await FamiliarData.load(repo, today);
    expect(data.activities.length, 1);
    expect(data.recentSessions.length, greaterThanOrEqualTo(2));
    final view = WhView(data, today);
    expect(view.spo2, 96.5);
    expect(view.spo2Source, 'band');
    expect(view.tempC, 33.8);
    expect(view.tempDevC, closeTo(.3, 1e-9));
    final input = view.observationInput();
    expect(input.lastActivityName, 'Бег');
    expect(input.restDays, greaterThanOrEqualTo(0));
    expect(view.observations(), isNotEmpty);
  });
}
