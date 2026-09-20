// Same path as familiar_after_sync_test, with the FULL WHOOP export shape the
// user imported: physiological cycles, sleeps and workouts. Then the first
// gen5 sync, the real derive, the loader for today and for an imported day,
// the activities reader and the observations.
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

Future<void> _seedGen5(Database db, {required int fromSec, required int toSec, required int Function(int) hr, required bool asleep}) async {
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
    LocalDb.dbName = 'familiar_after_sync_full_import_test.db';
    await databaseFactory.deleteDatabase(path.join(await databaseFactory.getDatabasesPath(), LocalDb.dbName));
    temp = Directory.systemTemp.createTempSync('familiar_after_sync_full_');
  });
  tearDownAll(() async {
    await LocalDb.close();
    await databaseFactory.deleteDatabase(path.join(await databaseFactory.getDatabasesPath(), LocalDb.dbName));
    temp.deleteSync(recursive: true);
  });

  test('full export import, first gen5 sync, derive, loaders, activities, observations', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayId = dayLabelOf(today);
    String d(int daysAgo) => dayLabelOf(DateTime(today.year, today.month, today.day - daysAgo));

    final cycles = File(path.join(temp.path, 'physiological_cycles.csv'));
    final sleeps = File(path.join(temp.path, 'sleeps.csv'));
    final workouts = File(path.join(temp.path, 'workouts.csv'));
    final c = ['Cycle start time,Wake onset,Recovery score %,Resting heart rate (bpm),Heart rate variability (ms),Day Strain,Energy burned (cal),Asleep duration (min),Blood oxygen %,Skin temp (celsius)'];
    final s = ['Cycle start time,Sleep onset,Wake onset,Asleep duration (min),In bed duration (min),Light sleep duration (min),Deep (SWS) duration (min),REM duration (min),Awake duration (min),Sleep efficiency %,Sleep performance %,Respiratory rate (rpm),Sleep consistency %,Sleep debt (min),Sleep need (min),Nap'];
    final w = ['Cycle start time,Workout start time,Workout end time,Activity name,Duration (min),Energy burned (cal),Max HR (bpm),Average HR (bpm),Activity Strain,HR Zone 1 %,HR Zone 2 %,HR Zone 3 %,HR Zone 4 %,HR Zone 5 %'];
    for (var i = 30; i >= 1; i--) {
      c.add('${d(i)} 00:00:00,${d(i)} 07:30:00,${60 + i % 30},${54 + i % 5},${40 + i % 12},${(8 + i % 9).toStringAsFixed(1)},${2000 + i * 7},${400 + i % 60},${96 + i % 3},${33.0 + (i % 5) / 10}');
      s.add('${d(i)} 00:00:00,${d(i + 1)} 23:10:00,${d(i)} 07:30:00,${400 + i % 60},${470 + i % 30},${200 + i % 30},${90 + i % 20},${110 + i % 15},${30 + i % 10},${88 + i % 8},${70 + i % 25},${14.2 + (i % 4) / 10},${60 + i % 30},${20 + i % 40},${480 + i % 40},false');
      if (i % 4 == 0) {
        w.add('${d(i)} 00:00:00,${d(i)} 18:00:00,${d(i)} 18:50:00,Running,50,${420 + i * 3},${170 + i % 12},${145 + i % 10},${(10 + i % 6).toStringAsFixed(1)},5,15,40,30,10');
      }
    }
    cycles.writeAsStringSync(c.join('\n'));
    sleeps.writeAsStringSync(s.join('\n'));
    workouts.writeAsStringSync(w.join('\n'));
    final imported = await WhoopImporter.importFiles([cycles.path, sleeps.path, workouts.path]);
    expect(imported.days, 30);
    expect(imported.workouts, greaterThanOrEqualTo(7));
    final repo = LocalRepositoryImpl(getProfileMap: () => {'age': 35, 'sex': 'male', 'weight_kg': 75.0, 'height_cm': 180.0});
    await FamiliarData.load(repo, now);
    await FamiliarData.load(repo, DateTime(today.year, today.month, today.day - 3));

    final db = await LocalDb.instance;
    final nightStart = DateTime(today.year, today.month, today.day - 1, 23).millisecondsSinceEpoch ~/ 1000;
    final nightEnd = DateTime(today.year, today.month, today.day, 7).millisecondsSinceEpoch ~/ 1000;
    final dayEnd = DateTime(today.year, today.month, today.day, 11).millisecondsSinceEpoch ~/ 1000;
    await _seedGen5(db, fromSec: nightStart, toSec: nightEnd, asleep: true, hr: (t) => 48 + ((t ~/ 600) % 5) + (t % 3));
    await _seedGen5(db, fromSec: nightEnd, toSec: dayEnd, asleep: false, hr: (t) => (t - nightEnd) > 5400 && (t - nightEnd) < 7200 ? 128 + (t % 9) : 74 + (t % 11));
    await LocalDb.putSleepOverride(dayId: dayId, onsetTs: nightStart, offsetTs: nightEnd, source: 'manual');
    // A workout recorded in the app today as well (the loader reads its 1 Hz rows).
    await repo.logManualWorkout(startTs: nightEnd + 5400, endTs: nightEnd + 7200, type: 'run');

    final done = await DerivationEngine().runDays(const Profile(ageYears: 35, sex: 'm', weightKg: 75, heightCm: 180), {dayId}, force: true);
    expect(done, 1);

    final data = await FamiliarData.load(repo, now);
    expect(data.loadFailures, isEmpty, reason: data.loadFailures.join('; '));
    expect(data.sleep['has_sleep'], isTrue);
    expect(data.nightHr, isNotEmpty);
    expect(data.activities.length, 1);
    final view = WhView(data, now);
    expect(view.spo2Source, 'band');
    expect(view.observations(), isNotEmpty);
    final input = view.observationInput();
    expect(input.lastActivityName, 'Бег');
    // An imported day after the derive, and the activities reader.
    final imp = await FamiliarData.load(repo, DateTime(today.year, today.month, today.day - 4));
    expect(imp.loadFailures, isEmpty, reason: imp.loadFailures.join('; '));
    final all = await repo.getWorkouts(range: 'month');
    expect(all, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
