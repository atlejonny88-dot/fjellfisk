import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/production_report.dart';
import '../utils/tank_status.dart';

class ProductionReportService {
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
      case 'month':
        return DateTime(today.year, today.month);
      default:
        return today.subtract(const Duration(days: 6));
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
    final facilityRef = _db.collection('facilities').doc(facilityId);

    final sectionRefs = <DocumentReference<Map<String, dynamic>>>[];
    if (sectionId != null) {
      sectionRefs.add(facilityRef.collection('sections').doc(sectionId));
    } else {
      final sections = await facilityRef.collection('sections').get();
      sectionRefs.addAll(sections.docs.map((doc) => doc.reference));
    }

    var activeTanks = 0;
    var emptyTanks = 0;
    var activeFish = 0;
    var registrations = 0;
    var mortality = 0;
    var tempCount = 0;
    var weightChangeCount = 0;

    var feedKg = 0.0;
    var biomassKg = 0.0;
    var biomassGainKg = 0.0;
    var weightedLatestWeight = 0.0;
    var tempSum = 0.0;
    var weightChangeSum = 0.0;
    double? minTemperature;
    double? maxTemperature;

    final rows = <ProductionReportTankRow>[];
    final registrationRows = <ProductionReportRegistration>[];
    var filterLabel = 'Hele anlegget';

    for (final sectionRef in sectionRefs) {
      final sectionSnap = await sectionRef.get();
      final sectionName =
          (sectionSnap.data()?['name'] ?? sectionRef.id).toString();
      if (sectionId != null && tankId == null) filterLabel = sectionName;

      final tankDocs = <DocumentSnapshot<Map<String, dynamic>>>[];
      if (tankId != null) {
        final tankSnap = await sectionRef.collection('tanks').doc(tankId).get();
        if (tankSnap.exists) tankDocs.add(tankSnap);
      } else {
        final tanks = await sectionRef.collection('tanks').get();
        tankDocs.addAll(tanks.docs);
      }

      for (final tank in tankDocs) {
        final tankData = tank.data() ?? <String, dynamic>{};
        final tankName = (tankData['name'] ?? tank.id).toString();
        final fishCount = TankStatus.fishCountFrom(tankData['fishCount']);
        final isActive = TankStatus.isActiveFishCount(fishCount);
        if (tankId != null) filterLabel = '$sectionName / $tankName';

        if (isActive) {
          activeTanks++;
          activeFish += fishCount;
        } else {
          emptyTanks++;
        }

        final logs =
            await tank.reference.collection('logs').orderBy('date').get();

        var tankRegistrations = 0;
        var tankFeedKg = 0.0;
        var tankMortality = 0;
        var latestWeight = 0.0;
        var latestTemperature = 0.0;
        var firstPeriodWeight = 0.0;
        var lastPeriodWeight = 0.0;
        DateTime? firstWeightDate;
        DateTime? lastWeightDate;

        for (final log in logs.docs) {
          final data = log.data();
          final date = _toDate(data['date']);
          if (date == null) continue;

          final avgWeight = _weightFromLog(data);
          final temperature = _toDouble(data['temperature']);

          if (!date.isAfter(toDate) && avgWeight > 0) {
            latestWeight = avgWeight;
          }

          if (date.isBefore(fromDate) || date.isAfter(toDate)) continue;

          tankRegistrations++;
          registrations++;

          final logMortality = _toInt(data['mortality'] ?? data['dead']);
          final logFeedKg = _toDouble(data['feedKg'] ?? data['feed']);

          tankMortality += logMortality;
          mortality += logMortality;
          tankFeedKg += logFeedKg;
          feedKg += logFeedKg;

          if (temperature > 0) {
            latestTemperature = temperature;
            tempSum += temperature;
            tempCount++;
            minTemperature = minTemperature == null
                ? temperature
                : _min(minTemperature, temperature);
            maxTemperature = maxTemperature == null
                ? temperature
                : _max(maxTemperature, temperature);
          }

          if (avgWeight > 0) {
            firstPeriodWeight =
                firstPeriodWeight == 0 ? avgWeight : firstPeriodWeight;
            firstWeightDate ??= date;
            lastPeriodWeight = avgWeight;
            lastWeightDate = date;
          }

          registrationRows.add(
            ProductionReportRegistration(
              date: date,
              sectionName: sectionName,
              tankName: tankName,
              mortality: logMortality,
              feedKg: logFeedKg,
              avgWeight: avgWeight,
              temperature: temperature,
              feedType: _firstText([data['feedType'], data['feedName']]),
              pelletSizeMm: _toDouble(data['pelletSizeMm']),
            ),
          );
        }

        final tankBiomassKg = isActive && latestWeight > 0
            ? fishCount * latestWeight / 1000
            : 0.0;
        final tankWeightChange = lastPeriodWeight > 0 && firstPeriodWeight > 0
            ? lastPeriodWeight - firstPeriodWeight
            : 0.0;
        final tankBiomassGainKg = isActive && tankWeightChange > 0
            ? fishCount * tankWeightChange / 1000
            : 0.0;
        final tankFcr = tankBiomassGainKg > 0 && tankFeedKg > 0
            ? tankFeedKg / tankBiomassGainKg
            : null;

        if (isActive) {
          biomassKg += tankBiomassKg;
          if (latestWeight > 0) {
            weightedLatestWeight += latestWeight * fishCount;
          }
          if (tankBiomassGainKg > 0) biomassGainKg += tankBiomassGainKg;
          if (tankWeightChange != 0 &&
              firstWeightDate != null &&
              lastWeightDate != null &&
              lastWeightDate.isAfter(firstWeightDate)) {
            weightChangeSum += tankWeightChange;
            weightChangeCount++;
          }
        }

        rows.add(
          ProductionReportTankRow(
            sectionId: sectionRef.id,
            sectionName: sectionName,
            tankId: tank.id,
            tankName: tankName,
            fishCount: fishCount,
            isActive: isActive,
            latestWeight: latestWeight,
            biomassKg: tankBiomassKg,
            feedKg: tankFeedKg,
            mortality: tankMortality,
            fcr: tankFcr,
            latestTemperature: latestTemperature > 0 ? latestTemperature : null,
            weightChange: tankWeightChange,
            registrations: tankRegistrations,
          ),
        );
      }
    }

    registrationRows.sort((a, b) => b.date.compareTo(a.date));
    rows.sort((a, b) {
      final sectionCompare = a.sectionName.compareTo(b.sectionName);
      if (sectionCompare != 0) return sectionCompare;
      return a.tankName.compareTo(b.tankName);
    });

    final fcr = biomassGainKg > 0 && feedKg > 0 ? feedKg / biomassGainKg : null;
    final latestAvgWeight =
        activeFish > 0 ? weightedLatestWeight / activeFish : 0.0;
    final avgTemperature = tempCount == 0 ? null : tempSum / tempCount;
    final weightChange =
        weightChangeCount == 0 ? 0.0 : weightChangeSum / weightChangeCount;

    return ProductionReport(
      from: fromDate,
      to: toDate,
      scope: tankId != null
          ? 'tank'
          : sectionId != null
              ? 'section'
              : 'facility',
      filterLabel: filterLabel,
      activeTanks: activeTanks,
      emptyTanks: emptyTanks,
      activeFish: activeFish,
      registrations: registrations,
      mortality: mortality,
      feedKg: feedKg,
      biomassKg: biomassKg,
      latestAvgWeight: latestAvgWeight,
      weightChange: weightChange,
      biomassGainKg: biomassGainKg,
      fcr: fcr,
      avgTemperature: avgTemperature,
      minTemperature: minTemperature,
      maxTemperature: maxTemperature,
      tanks: rows,
      registrationsList: registrationRows,
    );
  }

  static DateTime? _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static double _weightFromLog(Map<String, dynamic> data) {
    for (final value in [
      data['avgWeight'],
      data['avgWeightGram'],
      data['averageWeight'],
      data['weight'],
    ]) {
      final weight = _toDouble(value);
      if (weight > 0) return weight;
    }
    return 0;
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

  static double _min(double? a, double b) {
    if (a == null) return b;
    return a < b ? a : b;
  }

  static double _max(double? a, double b) {
    if (a == null) return b;
    return a > b ? a : b;
  }
}
