import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:openstrap_edge/data/db.dart';
import 'package:openstrap_edge/data/day_label.dart';
import 'package:openstrap_edge/data/imported_vitals.dart';
import 'package:openstrap_edge/data/local_repository_impl.dart';
import 'package:openstrap_edge/import/whoop_import.dart';
import 'package:openstrap_edge/ui2/familiar/data.dart';

void main() {
  late Directory temp;
  setUpAll(() async {
    sqfliteFfiInit(); databaseFactory=databaseFactoryFfi;
    LocalDb.dbName='familiar_import_test.db';
    await databaseFactory.deleteDatabase(path.join(await databaseFactory.getDatabasesPath(),LocalDb.dbName));
    temp=Directory.systemTemp.createTempSync('familiar_import_');
  });
  tearDownAll(()async {await LocalDb.close(); temp.deleteSync(recursive:true);});
  test('relative optical and raw temperature never become percent or Celsius',(){
    expect(importedVitals({'source':'onehz','scalars':{'spo2':98,'skin_temp_z':1.2}}),isEmpty);
    expect(importedVitals({'source':'whoop_export','imported':true,'scalars':{'spo2':double.nan,'skin_temp_z':-.4}})['skin_temperature_c'],isNull);
  });
  test('official WHOOP CSV -> SQLite -> repository -> real age and typed vitals',()async{
    final now=DateTime.now();
    final csv=File(path.join(temp.path,'physiological_cycles.csv'));
    final lines=['Cycle start time,Wake onset,Recovery score %,Resting heart rate (bpm),Heart rate variability (ms),Day Strain,Energy burned (cal),Asleep duration (min),Blood oxygen %,Skin temp (celsius)'];
    for(var i=6;i>=0;i--) {
      final day=dayLabelOf(DateTime(now.year,now.month,now.day-i));
      lines.add('$day 00:00:00,$day 08:00:00,82,56,48,12.7,2240,456,98,33.2');
    }
    csv.writeAsStringSync(lines.join('\n'));
    final imported=await WhoopImporter.importFiles([csv.path]);
    expect(imported.days,7);
    final repo=LocalRepositoryImpl(getProfileMap:()=>{'age':35,'weight_kg':75.0});
    final snapshot=await FamiliarData.load(repo,now);
    expect(snapshot.age,isNotNull);
    expect(snapshot.age!.samples['rhr'],7);
    expect(snapshot.age!.samples['hrv'],7);
    expect(snapshot.age!.samples['sleep'],7);
    expect(snapshot.age!.contributions.containsKey('steps'),false);
    expect(snapshot.oxygenPercent,98);
    expect(snapshot.temperatureC,33.2);
    expect(snapshot.temperatureUnit,'°C');
    // The old mislabeled scalar is not allowed through as a z-score.
    expect((snapshot.health.today['skin_temp'] as Map)['value'],isNull);
    expect(snapshot.nightDay,dayLabelOf(now));
  });
}
