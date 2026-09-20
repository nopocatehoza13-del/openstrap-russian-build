// The user's exact path after v8: fresh database -> WHOOP export import ->
// the first band sync (gen5 1 Hz rows with skin temperature, the SpO2 byte
// and the band sleep state) -> the real day derive -> the Familiar loader.
// Loading must not throw, and the night must reach the sleep screen data.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/compute/derivation_engine.dart';
import 'package:openstrap_edge/compute/profile.dart';
import 'package:openstrap_edge/data/day_label.dart';
import 'package:openstrap_edge/data/db.dart';
import 'package:openstrap_edge/data/local_repository_impl.dart';
import 'package:openstrap_edge/import/whoop_import.dart';
import 'package:openstrap_edge/ui2/familiar/data.dart';
import 'package:openstrap_edge/ui2/familiar/wh_data.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _seedGen5(
  Database db, {
  required int fromSec,
  required int toSec,
  required int Function(int sec) hr,
  required bool asleep,
}) async {
  var batch = db.batch();
  var n = 0;
  for (var ts = fromSec; ts < toSec; ts++) {
    final i = ts - fromSec;
    batch.insert('decoded_onehz', {
      'device_id': LocalDb.kPrimaryDeviceId,
      'ts_ms': ts * 1000,
      'rec_ts': ts,
      'counter': i,
      'hr': hr(ts),
      'ax': asleep ? 0.02 * ((i % 7) - 3) : 0.3 * ((i % 5) - 2),
      'ay': asleep ? 0.01 * ((i % 5) - 2) : 0.2 * ((i % 3) - 1),
      'az': 1.0,
      'device_family': 'gen5',
      'skin_temp_c': asleep ? 33.4 + (i % 100) / 1000 : 32.1 + (i % 100) / 1000,
      'band_sleep_state': asleep ? 2 : 0,
      if (asleep && i % 30 == 0) 'spo2_band_raw': 95 + (i ~/ 30) % 4,
      'step_count': asleep ? 1000 : 1000 + i ~/ 2,
      'dyn_accel_g': asleep ? 0.01 : 0.2,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (++n % 5000 == 0) {
      await batch.commit(noResult: true);
      batch = db.batch();
    }
  }
  await batch.commit(noResult: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDb.dbName = 'familiar_after_sync_test.db';
    await databaseFactory.deleteDatabase(
      path.join(await databaseFactory.getDatabasesPath(), LocalDb.dbName),
    );
    temp = Directory.systemTemp.createTempSync('familiar_after_sync_');
  });
  tearDownAll(() async {
    await LocalDb.close();
    await databaseFactory.deleteDatabase(
      path.join(await databaseFactory.getDatabasesPath(), LocalDb.dbName),
    );
    temp.deleteSync(recursive: true);
  });

  test('import, first gen5 sync, real derive, then the Familiar loader', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayId = dayLabelOf(today);
    // 1. The WHOOP export the user imported (7 days up to yesterday).
    final csv = File(path.join(temp.path, 'physiological_cycles.csv'));
    final lines = [
      'Cycle start time,Wake onset,Recovery score %,Resting heart rate (bpm),Heart rate variability (ms),Day Strain,Energy burned (cal),Asleep duration (min),Blood oxygen %,Skin temp (celsius)',
    ];
    for (var i = 7; i >= 1; i--) {
      final day = dayLabelOf(DateTime(today.year, today.month, today.day - i));
      lines.add('$day 00:00:00,$day 08:00:00,82,56,48,12.7,2240,456,98,33.2');
    }
    csv.writeAsStringSync(lines.join('\n'));
    final imported = await WhoopImporter.importFiles([csv.path]);
    expect(imported.days, 7);
    final repo = LocalRepositoryImpl(getProfileMap: () => {'age': 35, 'sex': 'male', 'weight_kg': 75.0});
    // The screen works on the imported days alone (what the user saw first).
    await FamiliarData.load(repo, now);

    // 2. The first sync: last night 23:00 -> 07:00 asleep, then a morning
    //    awake with a brisk walk, all gen5.
    final db = await LocalDb.instance;
    final nightStart = DateTime(today.year, today.month, today.day - 1, 23).millisecondsSinceEpoch ~/ 1000;
    final nightEnd = DateTime(today.year, today.month, today.day, 7).millisecondsSinceEpoch ~/ 1000;
    final dayEnd = DateTime(today.year, today.month, today.day, 11).millisecondsSinceEpoch ~/ 1000;
    await _seedGen5(db, fromSec: nightStart, toSec: nightEnd, asleep: true, hr: (t) => 48 + ((t ~/ 600) % 5) + (t % 3));
    await _seedGen5(db, fromSec: nightEnd, toSec: dayEnd, asleep: false, hr: (t) => (t - nightEnd) > 5400 && (t - nightEnd) < 7200 ? 128 + (t % 9) : 74 + (t % 11));
    await LocalDb.putSleepOverride(dayId: dayId, onsetTs: nightStart, offsetTs: nightEnd, source: 'manual');

    // 3. The real derive of today (what runs after a sync).
    final done = await DerivationEngine().runDays(const Profile(ageYears: 35, sex: 'm'), {dayId}, force: true);
    expect(done, 1, reason: 'today must derive');
    final row = await LocalDb.dayResult(dayId);
    expect(row, isNotNull);

    // 4. The Familiar loader and the view model over the derived day.
    final data = await FamiliarData.load(repo, now);
    final view = WhView(data, now);
    expect(data.sleep['has_sleep'], isTrue, reason: 'the forced night must be there');
    expect(data.nightHr, isNotEmpty, reason: 'the sleep screen draws the night HR line from this');
    expect(view.strain, isNotNull);
    // The band vitals of v8 on the derived day.
    expect(view.spo2Source, 'band');
    expect(view.spo2, inInclusiveRange(95, 98));
    expect(view.tempC, closeTo(33.45, .2));
    expect(view.observations(), isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
