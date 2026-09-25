import '../utils/data_values.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static String get userId => FirebaseAuth.instance.currentUser!.uid;

  static double _toDouble(Object? value) => DataValues.decimal(value);

  static int _toInt(Object? value) => DataValues.integer(value);

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
        fish += _toInt(t.data()['fishCount']);
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

  static Future<int> addDailyLog({
    required String facilityId,
    required String sectionId,
    required String tankId,
    required int mortality,
    required double feedKg,
    required double avgWeight,
    required double temperature,
    String? feedInventoryId,
    String? feedType,
    double? pelletSizeMm,
    String? registrationId,
    FirebaseFirestore? firestore,
    String? actorEmail,
  }) async {
    if (mortality < 0 ||
        !feedKg.isFinite ||
        feedKg < 0 ||
        !avgWeight.isFinite ||
        avgWeight < 0 ||
        !temperature.isFinite ||
        (pelletSizeMm != null &&
            (!pelletSizeMm.isFinite || pelletSizeMm <= 0))) {
      throw const FormatException('Registreringen inneholder ugyldige tall.');
    }
    final db = firestore ?? _db;
    final tankRef = db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .doc(sectionId)
        .collection('tanks')
        .doc(tankId);
    // The same ID can be retried after an uncertain network response.
    final logRef = tankRef.collection('logs').doc(registrationId);
    final feedRef = feedKg > 0 && feedInventoryId != null
        ? db.collection('feed_inventory').doc(feedInventoryId)
        : null;
    final historyRef = db.collection('feed_inventory_history').doc();
    final now = Timestamp.now();
    final email = feedRef == null
        ? ''
        : actorEmail ?? FirebaseAuth.instance.currentUser?.email ?? 'ukjent';

    return db.runTransaction<int>((transaction) async {
      final existing = await transaction.get(logRef);
      final tank = await transaction.get(tankRef);
      final count = DataValues.integer(tank.data()?['fishCount']);
      if (existing.exists) return count;
      if (!tank.exists || count <= 0) {
        throw const FormatException('Karet er tomt eller finnes ikke lenger.');
      }
      if (mortality > count) {
        throw const FormatException(
            'Dødelighet kan ikke være større enn fisketallet.');
      }
      Map<String, dynamic>? feedData;
      double stockKg = 0;
      if (feedRef != null) {
        final feed = await transaction.get(feedRef);
        feedData = feed.data();
        if (!feed.exists || feedData == null || feedData['active'] == false) {
          throw const FormatException('Valgt fôrtype er ikke tilgjengelig.');
        }
        stockKg = DataValues.number(feedData['stockKg'])?.toDouble() ??
            _toInt(feedData['bags']) * _toDouble(feedData['kgPerBag']);
        if (stockKg + 0.0001 < feedKg) {
          throw const FormatException('Ikke nok fôr på lager.');
        }
      }
      final countAfter = count - mortality;
      final resolvedPellet =
          pelletSizeMm ?? _toDouble(feedData?['pelletSizeMm']);
      transaction.set(logRef, {
        'date': now,
        'mortality': mortality,
        'feedKg': feedKg,
        'avgWeight': avgWeight,
        'avgWeightGram': avgWeight,
        'temperature': temperature,
        if (feedRef != null) 'feedInventoryId': feedInventoryId,
        if (feedType != null || feedData != null)
          'feedType':
              feedType ?? (feedData?['name'] ?? feedInventoryId).toString(),
        if (resolvedPellet > 0) 'pelletSizeMm': resolvedPellet,
      });
      if (mortality > 0) transaction.update(tankRef, {'fishCount': countAfter});
      if (feedRef != null) {
        final after = (stockKg - feedKg).clamp(0.0, double.maxFinite);
        transaction.update(feedRef, {'stockKg': after, 'updatedAt': now});
        transaction.set(historyRef, {
          'feedId': feedInventoryId,
          'feedType': feedType ?? feedData?['name'],
          'change': 0,
          'changeKg': -feedKg,
          'stockKgBefore': stockKg,
          'stockKgAfter': after,
          'user': email,
          'timestamp': now,
          'note': 'Fôr brukt i $tankId',
          'facilityId': facilityId,
          'sectionId': sectionId,
          'tankId': tankId,
        });
      }
      return countAfter;
    });
  }

  // ================= CHART DATA =================

  static Future<void> adjustFeedBags({
    required String feedId,
    required int change,
    String? adjustmentId,
    FirebaseFirestore? firestore,
    String? actorEmail,
  }) async {
    final db = firestore ?? _db;
    final ref = db.collection('feed_inventory').doc(feedId);
    final history = db.collection('feed_inventory_history').doc(adjustmentId);
    final email =
        actorEmail ?? FirebaseAuth.instance.currentUser?.email ?? 'ukjent';
    await db.runTransaction((tx) async {
      final existing = await tx.get(history);
      if (existing.exists) return;
      final snap = await tx.get(ref);
      if (!snap.exists) throw const FormatException('Fôrtypen finnes ikke.');
      final data = snap.data()!;
      final bags = _toInt(data['bags']);
      final kg = _toDouble(data['kgPerBag']);
      final stock = DataValues.number(data['stockKg'])?.toDouble() ?? bags * kg;
      final after = stock + change * kg;
      if (kg <= 0 || bags + change < 0 || after < 0) {
        throw const FormatException('Justeringen gir ugyldig lagerbeholdning.');
      }
      tx.update(ref, {
        'bags': bags + change,
        'stockKg': after,
        'updatedAt': Timestamp.now()
      });
      tx.set(history, {
        'feedId': feedId,
        'feedType': data['name'],
        'change': change,
        'changeKg': change * kg,
        'bagsBefore': bags,
        'bagsAfter': bags + change,
        'stockKgBefore': stock,
        'stockKgAfter': after,
        'user': email,
        'timestamp': Timestamp.now(),
      });
    });
  }

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
    if (!w1.isFinite || !w2.isFinite || w1 <= 0 || w2 <= 0 || days <= 0) {
      return 0;
    }
    return ((log(w2) - log(w1)) / days) * 100;
  }
}
