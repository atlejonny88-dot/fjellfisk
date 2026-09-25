import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fjellfisk/services/firestore_service.dart';
import 'package:fjellfisk/services/fcr_service.dart';
import 'package:fjellfisk/services/fish_transfer_service.dart';
import 'package:fjellfisk/services/production_report_service.dart';
import 'package:fjellfisk/services/excel_service.dart';
import 'package:fjellfisk/services/weight_sample_service.dart';
import 'package:fjellfisk/utils/data_values.dart';
import 'package:fjellfisk/utils/tank_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  const tankPath = 'facilities/f/sections/s/tanks/t';
  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.doc('facilities/f').set({'name': 'Test'});
    await db.doc('facilities/f/sections/s').set({'name': 'Tunnel'});
    await db.doc(tankPath).set({'name': 'K1', 'fishCount': 100});
    await db.doc('feed_inventory/feed').set({
      'name': 'Testfor',
      'active': true,
      'bags': 5,
      'kgPerBag': 20,
      'stockKg': 80.0,
      'pelletSizeMm': 1.5,
    });
  });
  Future<int> save(
      {String id = 'registration',
      double feed = 0,
      int mortality = 0,
      String? feedId,
      double weight = 250.5}) {
    return FirestoreService.addDailyLog(
      facilityId: 'f',
      sectionId: 's',
      tankId: 't',
      mortality: mortality,
      feedKg: feed,
      avgWeight: weight,
      temperature: 0,
      feedInventoryId: feedId,
      registrationId: id,
      firestore: db,
      actorEmail: 'test@example.invalid',
    );
  }

  test('weight only needs no feed; aliases and timestamp are saved', () async {
    expect(await save(), 100);
    final log = (await db.doc('$tankPath/logs/registration').get()).data()!;
    expect(log['avgWeight'], 250.5);
    expect(log['avgWeightGram'], 250.5);
    expect(log['date'], isA<Timestamp>());
    expect(log.containsKey('feedInventoryId'), isFalse);
    expect((await db.collection('feed_inventory_history').get()).size, 0);
  });
  test('feed-only entry does not become a new weight measurement', () async {
    await save(id: 'weight', weight: 250);
    await save(id: 'feed-only', feed: 2, weight: 0);
    final log = (await db.doc('$tankPath/logs/feed-only').get()).data()!;
    expect(DataValues.weight(log), 0);
    expect((await db.doc('$tankPath/logs/weight').get()).data()!['avgWeight'],
        250);
    expect(log['feedKg'], 2);
  });
  test('fish transfer retry moves exactly once and logs both ends', () async {
    final target = db.doc('facilities/f/sections/other/tanks/t');
    await target.set({'fishCount': '10', 'name': 'K2'});
    for (var attempt = 0; attempt < 2; attempt++) {
      await FishTransferService.move(
          from: db.doc(tankPath), to: target, amount: 20, transferId: 'move');
    }
    expect((await db.doc(tankPath).get()).data()!['fishCount'], 80);
    expect((await target.get()).data()!['fishCount'], 30);
    expect((await target.collection('logs').get()).size, 1);
    await expectLater(
        FishTransferService.move(
            from: db.doc(tankPath),
            to: target,
            amount: 81,
            transferId: 'too-many'),
        throwsFormatException);
  });
  test('retry uses same log and debits feed and mortality once', () async {
    await save(feed: 12.5, mortality: 2, feedId: 'feed');
    await save(feed: 12.5, mortality: 2, feedId: 'feed');
    expect((await db.doc(tankPath).get()).data()!['fishCount'], 98);
    expect(
        (await db.doc('feed_inventory/feed').get()).data()!['stockKg'], 67.5);
    expect((await db.collection('$tankPath/logs').get()).size, 1);
    expect((await db.collection('feed_inventory_history').get()).size, 1);
  });
  test('current server count used for sequential mortality', () async {
    await save(id: 'a', mortality: 2);
    await save(id: 'b', mortality: 3);
    expect((await db.doc(tankPath).get()).data()!['fishCount'], 95);
  });
  test('insufficient stock rejects whole registration', () async {
    await expectLater(
        save(feed: 81, mortality: 2, feedId: 'feed'), throwsFormatException);
    expect((await db.doc(tankPath).get()).data()!['fishCount'], 100);
    expect((await db.collection('$tankPath/logs').get()).size, 0);
    expect((await db.doc('feed_inventory/feed').get()).data()!['stockKg'], 80);
  });
  test('empty tank, excessive mortality and nonfinite values rejected',
      () async {
    await expectLater(save(mortality: 101), throwsFormatException);
    await expectLater(save(weight: double.nan), throwsFormatException);
    await db.doc(tankPath).update({'fishCount': 0});
    await expectLater(save(), throwsFormatException);
  });
  test('bag adjustment preserves already consumed feed', () async {
    await FirestoreService.adjustFeedBags(
        feedId: 'feed',
        change: 1,
        firestore: db,
        actorEmail: 'test@example.invalid');
    expect((await db.doc('feed_inventory/feed').get()).data()!['stockKg'], 100);
    expect((await db.doc('feed_inventory/feed').get()).data()!['bags'], 6);
  });
  test('weight sample and matching average log saved atomically once',
      () async {
    for (var attempt = 0; attempt < 2; attempt++) {
      await WeightSampleService.saveWeightSample(
          facilityId: 'f',
          sectionId: 's',
          tankId: 't',
          weightsGram: [200, 300],
          sampleId: 'sample',
          firestore: db,
          actorUid: 'employee',
          actorEmail: 'test@example.invalid');
    }
    expect((await db.collection('$tankPath/weightSamples').get()).size, 1);
    expect((await db.collection('$tankPath/logs').get()).size, 1);
    expect(
        (await db.doc('$tankPath/logs/sample').get()).data()!['avgWeightGram'],
        250);
    await db.doc(tankPath).update({'fishCount': 0});
    await expectLater(
        WeightSampleService.saveWeightSample(
            facilityId: 'f',
            sectionId: 's',
            tankId: 't',
            weightsGram: [200],
            sampleId: 'empty',
            firestore: db),
        throwsFormatException);
  });
  test('invalid legacy numbers are safe and aliases fall through', () {
    for (final value in [null, {}, true, double.nan, double.infinity, 'NaN']) {
      expect(DataValues.decimal(value), 0);
      expect(TankStatus.fishCountFrom(value), 0);
    }
    expect(DataValues.decimal('250,5'), 250.5);
    expect(
        DataValues.weight({'avgWeight': 'invalid', 'avgWeightGram': '250,5'}),
        250.5);
  });
  test('weight samples parse decimal input and calculate statistics', () {
    final parsed = WeightSampleService.parseWeights(
        '250 250.5 250,5 NaN Infinity -1 0 50001');
    expect(parsed.validWeights, [250, 250.5, 250.5]);
    expect(parsed.invalidValues.length, 5);
    final stats = WeightSampleService.calculateStats([100, 200, 300, 400]);
    expect(stats.averageGram, 250);
    expect(stats.medianGram, 250);
    expect(stats.minGram, 100);
    expect(stats.maxGram, 400);
    expect(stats.standardDeviationGram, closeTo(111.803, .001));
    expect(() => WeightSampleService.calculateStats([double.nan]),
        throwsArgumentError);
  });
  test('FCR uses valid aliases and rejects transfers, empty and no gain', () {
    final logs = <Map<String, dynamic>>[
      {'date': Timestamp.fromDate(DateTime(2026, 9, 1)), 'avgWeightGram': 100},
      {'date': Timestamp.fromDate(DateTime(2026, 9, 2)), 'feedKg': '5,0'},
      {'date': Timestamp.fromDate(DateTime(2026, 9, 3)), 'averageWeight': 200},
    ];
    expect(FcrService.calculateFromLogs(logs, 100)['fcr'], .5);
    expect(FcrService.calculateFromLogs(logs, 0)['hasData'], false);
    logs[1]['transferIn'] = 10;
    expect(FcrService.calculateFromLogs(logs, 100)['hasData'], false);
    logs[1].remove('transferIn');
    logs[2]['averageWeight'] = 100;
    expect(FcrService.calculateFromLogs(logs, 100)['hasData'], false);
  });
  test('report filters, empty tanks and Excel share the same safe values',
      () async {
    await db.doc('facilities/f/sections/s/tanks/empty').set({'fishCount': 0});
    await db
        .doc('facilities/f/sections/s/tanks/unknown')
        .set({'fishCount': 100});
    for (final tank in ['t', 'empty']) {
      final logs = db.collection('facilities/f/sections/s/tanks/$tank/logs');
      await logs.doc('start').set({
        'date': Timestamp.fromDate(DateTime(2026, 9, 1)),
        'avgWeightGram': 100
      });
      await logs.doc('feed').set({
        'date': Timestamp.fromDate(DateTime(2026, 9, 2)),
        'feedKg': '5,0',
        'mortality': '2',
        'temperature': 12,
        'feedType': 'Testfor',
        'pelletSizeMm': 1.5
      });
      await logs.doc('end').set(
          {'date': Timestamp.fromDate(DateTime(2026, 9, 3)), 'avgWeight': 200});
    }
    final report = await ProductionReportService.loadProductionReport(
        facilityId: 'f',
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 3),
        firestore: db);
    expect(report.activeTanks, 2);
    expect(report.emptyTanks, 1);
    expect(report.feedKg, 5);
    expect(report.mortality, 2);
    expect(report.registrations, 3);
    expect(report.latestAvgWeight, 200);
    expect(report.biomassKg, 20);
    expect(report.fcr, .5);
    expect(report.avgTemperature, 12);
    final excel = ExcelService.productionReportWorkbook(
        report: report, facilityName: 'Test');
    final decoded = Excel.decodeBytes(excel.encode()!);
    expect(decoded.tables.keys,
        containsAll(['Sammendrag', 'Karoversikt', 'Registreringer']));
    expect(decoded['Karoversikt'].maxRows, 4);
    expect(decoded['Registreringer'].maxRows, 4);
    final filtered = await ProductionReportService.loadProductionReport(
        facilityId: 'f',
        sectionId: 's',
        tankId: 't',
        from: DateTime(2026, 9, 3),
        to: DateTime(2026, 9, 3),
        firestore: db);
    expect(filtered.tanks.length, 1);
    expect(filtered.feedKg, 0);
    expect(filtered.fcr, isNull);
    expect(filtered.registrations, 1);
  });
}
