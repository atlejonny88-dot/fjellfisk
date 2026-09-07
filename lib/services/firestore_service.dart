import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static String get userId => FirebaseAuth.instance.currentUser!.uid;

  static double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  static int _toInt(Object? value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  // ================= DASHBOARD =================

  static Future<Map<String, int>> getDashboardTotals(String facilityId) async {
    final sections = await _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .get();

    int tanks = 0;
    int fish = 0;

    for (final s in sections.docs) {
      final tanksSnap = await s.reference.collection('tanks').get();
      tanks += tanksSnap.docs.length;
      for (final t in tanksSnap.docs) {
        fish += (t.data()['fishCount'] ?? 0) as int;
      }
    }

    return {'tanks': tanks, 'fish': fish};
  }

  static Stream<Map<String, int>> dashboardTotalsStream(
      String facilityId) async* {
    yield await getDashboardTotals(facilityId);
  }

  // ================= SECTIONS =================

  static Stream<QuerySnapshot> streamSections(String facilityId) {
    return _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .snapshots();
  }

  // ================= TANKS =================

  static Stream<QuerySnapshot> streamTanks({
    required String facilityId,
    required String sectionId,
  }) {
    return _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .doc(sectionId)
        .collection('tanks')
        .snapshots();
  }

  static Future<void> createTank({
    required String facilityId,
    required String sectionId,
    required String name,
    required int fishCount,
  }) async {
    await _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .doc(sectionId)
        .collection('tanks')
        .add({
      'name': name,
      'fishCount': fishCount,
      'createdAt': Timestamp.now(),
    });
  }

  static Future<void> updateFishCount({
    required String facilityId,
    required String sectionId,
    required String tankId,
    required int fishCount,
  }) async {
    await _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .doc(sectionId)
        .collection('tanks')
        .doc(tankId)
        .set({
      'fishCount': fishCount,
    }, SetOptions(merge: true));
  }

  // ================= LOGGING =================

  static Future<void> addDailyLog({
    required String facilityId,
    required String sectionId,
    required String tankId,
    required int mortality,
    required double feedKg,
    required double avgWeight,
    required double temperature,
    int? fishCountAfter,
    String? feedInventoryId,
    String? feedType,
    double? pelletSizeMm,
  }) async {
    final tankRef = _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .doc(sectionId)
        .collection('tanks')
        .doc(tankId);

    final logRef = tankRef.collection('logs').doc();
    final now = Timestamp.now();
    final logData = <String, dynamic>{
      'date': now,
      'mortality': mortality,
      'feedKg': feedKg,
      'avgWeight': avgWeight,
      'avgWeightGram': avgWeight,
      'temperature': temperature,
      if (feedInventoryId != null) 'feedInventoryId': feedInventoryId,
      if (feedType != null) 'feedType': feedType,
      if (pelletSizeMm != null) 'pelletSizeMm': pelletSizeMm,
    };

    if (feedInventoryId == null || feedKg <= 0) {
      if (fishCountAfter == null) {
        await logRef.set(logData);
        return;
      }

      final batch = _db.batch();
      batch.set(
        tankRef,
        {'fishCount': fishCountAfter < 0 ? 0 : fishCountAfter},
        SetOptions(merge: true),
      );
      batch.set(logRef, logData);
      await batch.commit();
      return;
    }

    final feedRef = _db.collection('feed_inventory').doc(feedInventoryId);
    final historyRef = _db.collection('feed_inventory_history').doc();

    await _db.runTransaction((transaction) async {
      final feedSnap = await transaction.get(feedRef);
      if (!feedSnap.exists) {
        throw Exception('Valgt fôrtype finnes ikke i lageret.');
      }

      final feedData = feedSnap.data() ?? <String, dynamic>{};
      if (feedData['active'] == false) {
        throw Exception('Valgt fôrtype er deaktivert.');
      }

      final bags = _toInt(feedData['bags']);
      final kgPerBag = _toDouble(feedData['kgPerBag']);
      final stockKgRaw = feedData['stockKg'];
      final stockKg =
          stockKgRaw is num ? stockKgRaw.toDouble() : bags * kgPerBag;

      if (stockKg + 0.0001 < feedKg) {
        throw Exception(
          'Ikke nok fôr på lager. Tilgjengelig: ${stockKg.toStringAsFixed(1)} kg.',
        );
      }

      final newStockKg = stockKg - feedKg;
      final resolvedFeedType =
          feedType ?? (feedData['name'] ?? feedInventoryId).toString();
      final resolvedPelletSize =
          pelletSizeMm ?? _toDouble(feedData['pelletSizeMm']);

      transaction.set(logRef, {
        ...logData,
        'feedType': resolvedFeedType,
        if (resolvedPelletSize > 0) 'pelletSizeMm': resolvedPelletSize,
      });

      if (fishCountAfter != null) {
        transaction.set(
          tankRef,
          {'fishCount': fishCountAfter < 0 ? 0 : fishCountAfter},
          SetOptions(merge: true),
        );
      }

      transaction.update(feedRef, {
        'stockKg': newStockKg,
        'updatedAt': now,
      });

      transaction.set(historyRef, {
        'feedId': feedInventoryId,
        'feedType': resolvedFeedType,
        'change': 0,
        'changeKg': -feedKg,
        'stockKgBefore': stockKg,
        'stockKgAfter': newStockKg,
        'user': FirebaseAuth.instance.currentUser?.email ?? 'ukjent',
        'timestamp': now,
        'note': 'Fôr brukt i $tankId',
        'facilityId': facilityId,
        'sectionId': sectionId,
        'tankId': tankId,
      });
    });
  }

  // ================= CHART DATA =================

  static Future<List<Map<String, dynamic>>> getWeights({
    required String facilityId,
    required String sectionId,
    required String tankId,
  }) async {
    final snap = await _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .doc(sectionId)
        .collection('tanks')
        .doc(tankId)
        .collection('logs')
        .orderBy('date')
        .get();

    return snap.docs.map((d) => d.data()).toList();
  }

  static Future<List<Map<String, dynamic>>> getMortalityData({
    required String facilityId,
    required String sectionId,
    required String tankId,
  }) async {
    final snap = await _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .doc(sectionId)
        .collection('tanks')
        .doc(tankId)
        .collection('logs')
        .orderBy('date')
        .get();

    return snap.docs.map((d) => d.data()).toList();
  }

  static double calculateSGR(double w1, double w2, int days) {
    if (w1 <= 0 || days <= 0) return 0;
    return ((log(w2) - log(w1)) / days) * 100;
  }
}
