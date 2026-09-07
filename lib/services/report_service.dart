import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../utils/tank_status.dart';

class ReportService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DateFormat dateFormat = DateFormat('yyyy-MM-dd');

  static DateTime startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime endOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
  }

  static DateTime fromForPeriod(String period) {
    final today = startOfDay(DateTime.now());
    switch (period) {
      case 'today':
        return today;
      case '7d':
        return today.subtract(const Duration(days: 6));
      case '30d':
        return today.subtract(const Duration(days: 29));
      default:
        return today;
    }
  }

  static String periodLabel(DateTime from, DateTime to) {
    return '${dateFormat.format(from)} - ${dateFormat.format(to)}';
  }

  static Future<List<ReportOption>> loadSections(String facilityId) async {
    final snap = await _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .orderBy('createdAt')
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return ReportOption(
        id: doc.id,
        name: (data['name'] ?? doc.id).toString(),
      );
    }).toList();
  }

  static Future<List<ReportOption>> loadTanks({
    required String facilityId,
    required String sectionId,
  }) async {
    final snap = await _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .doc(sectionId)
        .collection('tanks')
        .orderBy('createdAt')
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return ReportOption(
        id: doc.id,
        name: (data['name'] ?? doc.id).toString(),
      );
    }).toList();
  }

  static Future<ProductionReport> loadProductionReport({
    required String facilityId,
    required DateTime from,
    required DateTime to,
    String? sectionId,
    String? tankId,
  }) async {
    final fromDate = startOfDay(from);
    final toDate = endOfDay(to);
    final notes = <String>[];

    int activeTanks = 0;
    int emptyTanks = 0;
    int activeFish = 0;
    int mortality = 0;
    int tempCount = 0;
    int weightCount = 0;
    int tanksWithGain = 0;

    double feedKg = 0;
    double tempSum = 0;
    double biomassKg = 0;
    double weightSum = 0;
    double biomassGainKg = 0;

    final sectionRefs = <DocumentReference<Map<String, dynamic>>>[];
    final facilityRef = _db.collection('facilities').doc(facilityId);

    if (sectionId != null) {
      sectionRefs.add(facilityRef.collection('sections').doc(sectionId));
    } else {
      final sections = await facilityRef.collection('sections').get();
      sectionRefs.addAll(sections.docs.map((doc) => doc.reference));
    }

    for (final sectionRef in sectionRefs) {
      final sectionSnap = await sectionRef.get();
      final sectionName =
          (sectionSnap.data()?['name'] ?? sectionRef.id).toString();

      final tankDocs = <DocumentSnapshot<Map<String, dynamic>>>[];
      if (tankId != null) {
        final tankSnap = await sectionRef.collection('tanks').doc(tankId).get();
        if (tankSnap.exists) {
          tankDocs.add(tankSnap);
        }
      } else {
        final tanks = await sectionRef.collection('tanks').get();
        tankDocs.addAll(tanks.docs);
      }

      for (final tank in tankDocs) {
        final tankData = tank.data() ?? <String, dynamic>{};
        final fishCount = TankStatus.fishCountFrom(tankData['fishCount']);
        final tankName = (tankData['name'] ?? tank.id).toString();

        if (!TankStatus.isActiveFishCount(fishCount)) {
          emptyTanks++;
          continue;
        }

        activeTanks++;
        activeFish += fishCount;

        final logs =
            await tank.reference.collection('logs').orderBy('date').get();

        double firstWeight = 0;
        double lastWeight = 0;
        double latestWeight = 0;

        for (final log in logs.docs) {
          final data = log.data();
          final date = _toDate(data['date']);
          if (date == null) continue;

          final avgWeight = _toDouble(data['avgWeight'] ?? data['weight']);
          if (!date.isAfter(toDate) && avgWeight > 0) {
            latestWeight = avgWeight;
          }

          if (date.isBefore(fromDate) || date.isAfter(toDate)) continue;

          mortality += _toInt(data['mortality'] ?? data['dead']);
          feedKg += _toDouble(data['feedKg'] ?? data['feed']);

          final temp = _toDouble(data['temperature']);
          if (temp > 0) {
            tempSum += temp;
            tempCount++;
          }

          if (avgWeight > 0) {
            firstWeight = firstWeight == 0 ? avgWeight : firstWeight;
            lastWeight = avgWeight;
            weightSum += avgWeight;
            weightCount++;
          }

          final note =
              _firstText([data['note'], data['notes'], data['comment']]);
          if (note.isNotEmpty) {
            notes.add('$sectionName / $tankName: $note');
          }
        }

        if (latestWeight > 0) {
          biomassKg += fishCount * latestWeight / 1000;
        }

        if (firstWeight > 0 && lastWeight > firstWeight) {
          biomassGainKg += fishCount * (lastWeight - firstWeight) / 1000;
          tanksWithGain++;
        }
      }
    }

    final avgTemperature = tempCount == 0 ? 0.0 : tempSum / tempCount;
    final avgWeight = weightCount == 0 ? 0.0 : weightSum / weightCount;
    final fcr = biomassGainKg > 0 && feedKg > 0 ? feedKg / biomassGainKg : null;

    return ProductionReport(
      from: fromDate,
      to: toDate,
      activeTanks: activeTanks,
      emptyTanks: emptyTanks,
      activeFish: activeFish,
      mortality: mortality,
      feedKg: feedKg,
      avgTemperature: avgTemperature,
      biomassKg: biomassKg,
      avgWeight: avgWeight,
      fcr: fcr,
      biomassGainKg: biomassGainKg,
      tanksWithGain: tanksWithGain,
      notes: notes,
    );
  }

  static DateTime? _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

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

  static String _firstText(List<Object?> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}

class ReportOption {
  final String id;
  final String name;

  const ReportOption({
    required this.id,
    required this.name,
  });
}

class ProductionReport {
  final DateTime from;
  final DateTime to;
  final int activeTanks;
  final int emptyTanks;
  final int activeFish;
  final int mortality;
  final double feedKg;
  final double avgTemperature;
  final double biomassKg;
  final double avgWeight;
  final double? fcr;
  final double biomassGainKg;
  final int tanksWithGain;
  final List<String> notes;

  const ProductionReport({
    required this.from,
    required this.to,
    required this.activeTanks,
    required this.emptyTanks,
    required this.activeFish,
    required this.mortality,
    required this.feedKg,
    required this.avgTemperature,
    required this.biomassKg,
    required this.avgWeight,
    required this.fcr,
    required this.biomassGainKg,
    required this.tanksWithGain,
    required this.notes,
  });
}
