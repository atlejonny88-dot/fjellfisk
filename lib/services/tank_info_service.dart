import 'package:cloud_firestore/cloud_firestore.dart';

class TankInfoService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static double toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  static int toInt(Object? value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static double weightFromLog(Map<String, dynamic> data) {
    final candidates = [
      data['avgWeight'],
      data['avgWeightGram'],
      data['averageWeight'],
      data['weight'],
    ];

    for (final value in candidates) {
      final weight = toDouble(value);
      if (weight > 0) return weight;
    }

    return 0;
  }

  static Future<double> latestWeight({
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
        .orderBy('date', descending: true)
        .limit(50)
        .get();

    for (final doc in snap.docs) {
      final weight = weightFromLog(doc.data());
      if (weight > 0) return weight;
    }

    return 0;
  }

  static String recommendedFeed(double weight) {
    if (weight <= 0) return 'Registrer snittvekt for anbefaling';
    if (weight < 2) return 'Skretting Nutra Sprint 0.5';
    if (weight < 5) return 'Skretting Nutra Sprint 0.8';
    if (weight < 15) return 'Skretting Nutra Sprint 1.0';
    if (weight < 100) return 'Skretting Nutra Olympic 2.0';
    if (weight < 300) return 'Polarfeed Laksens Valg 150';
    return 'Polarfeed Laksens Valg 300';
  }

  static String pelletSize(double weight) {
    if (weight <= 0) return '-';
    if (weight < 2) return '0.5 mm';
    if (weight < 5) return '0.8 mm';
    if (weight < 15) return '1.0 mm';
    if (weight < 100) return '2.0 mm';
    if (weight < 300) return '3 mm';
    return '6 mm';
  }

  static String nextFeedMessage(double weight) {
    if (weight <= 0) return 'Ingen snittvekt registrert ennå';
    if (weight < 2) {
      return '${(2 - weight).toStringAsFixed(1)} g igjen til Nutra Sprint 0.8';
    }
    if (weight < 5) {
      return '${(5 - weight).toStringAsFixed(1)} g igjen til Nutra Sprint 1.0';
    }
    if (weight < 15) {
      return '${(15 - weight).toStringAsFixed(1)} g igjen til Nutra Olympic 2.0';
    }
    if (weight < 100) {
      return '${(100 - weight).toStringAsFixed(1)} g igjen til Polarfeed Laksens Valg 150';
    }
    if (weight < 300) {
      return '${(300 - weight).toStringAsFixed(1)} g igjen til Polarfeed Laksens Valg 300';
    }
    return 'Sluttfôr / stor fisk';
  }

  static double biomassKg({
    required int fishCount,
    required double avgWeightGram,
  }) {
    if (fishCount <= 0 || avgWeightGram <= 0) return 0;
    return fishCount * avgWeightGram / 1000;
  }

  static double recommendedFeedPercent(double weight) {
    if (weight <= 0) return 0;
    if (weight < 100) return 1.5;
    if (weight < 300) return 1.0;
    if (weight < 1000) return 0.8;
    return 0.6;
  }

  static double recommendedDailyFeedKg({
    required double biomassKg,
    required double feedPercent,
  }) {
    if (biomassKg <= 0 || feedPercent <= 0) return 0;
    return biomassKg * (feedPercent / 100);
  }

  static double stockKg(Map<String, dynamic> data) {
    final stockKg = data['stockKg'];
    if (stockKg is num) return stockKg.toDouble();

    final bags = toInt(data['bags']);
    final kgPerBag = toDouble(data['kgPerBag']);
    return bags * kgPerBag;
  }

  static Future<Map<String, dynamic>?> recommendedFeedInventory(
    String recommendedFeedName,
  ) async {
    if (recommendedFeedName.isEmpty ||
        recommendedFeedName.startsWith('Registrer')) {
      return null;
    }

    final snap = await _db
        .collection('feed_inventory')
        .where('active', isEqualTo: true)
        .get();

    final target = _normalize(recommendedFeedName);
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString();
      if (_normalize(name) == target) {
        return {
          'id': doc.id,
          ...data,
        };
      }
    }

    return null;
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
