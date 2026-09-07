import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/tank_status.dart';

class FcrService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> calculateTankFcr({
    required String facilityId,
    required String sectionId,
    required String tankId,
    required int currentFishCount,
    DateTime? from,
    DateTime? to,
  }) async {
    if (!TankStatus.isActiveFishCount(currentFishCount)) {
      return _noData('Tomt kar - FCR beregnes ikke');
    }

    final tankRef = _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .doc(sectionId)
        .collection('tanks')
        .doc(tankId);

    final tankSnap = await tankRef.get();
    final tankData = tankSnap.data();
    final storedFishCount = TankStatus.fishCountFrom(tankData?['fishCount']);
    final fishCount = storedFishCount > 0 ? storedFishCount : currentFishCount;

    if (!TankStatus.isActiveFishCount(fishCount)) {
      return _noData('Tomt kar - FCR beregnes ikke');
    }

    final snap = await tankRef.collection('logs').orderBy('date').get();
    final logs = snap.docs.map((doc) => doc.data()).toList();

    final periodStart = from == null ? null : _startOfDay(from);
    final periodEnd = to == null ? null : _endOfDay(to);

    final periodLogs = logs.where((log) {
      final date = _toDate(log['date']);
      if (date == null) return false;
      if (periodStart != null && date.isBefore(periodStart)) return false;
      if (periodEnd != null && date.isAfter(periodEnd)) return false;
      return true;
    }).toList();

    final sourceLogs =
        periodStart == null && periodEnd == null ? logs : periodLogs;

    if (sourceLogs.any(_isMovementLog)) {
      return _noData(
        'Fisk er flyttet i perioden. FCR kan ikke beregnes trygt uten beholdningshistorikk.',
      );
    }

    final weightLogs = sourceLogs.where((log) {
      return _toDate(log['date']) != null && _toDouble(log['avgWeight']) > 0;
    }).toList();

    if (weightLogs.length < 2) {
      return _noData('Ikke nok data');
    }

    final first = weightLogs.first;
    final last = weightLogs.last;
    final startWeight = _toDouble(first['avgWeight']);
    final endWeight = _toDouble(last['avgWeight']);
    final startDate = _toDate(first['date']);
    final endDate = _toDate(last['date']);

    if (startDate == null || endDate == null) {
      return _noData('Mangler dato på vektregistrering');
    }

    final days = endDate.difference(startDate).inDays;
    if (days <= 0) {
      return _noData('Vektregistreringene må være på ulike dager');
    }

    final weightGainGram = endWeight - startWeight;
    if (weightGainGram <= 0) {
      return {
        'hasData': false,
        'message': 'Ikke nok data',
        'startWeight': startWeight,
        'endWeight': endWeight,
        'feedKg': 0.0,
        'biomassGainKg': 0.0,
        'days': days,
      };
    }

    double feedKg = 0;
    for (final log in sourceLogs) {
      final date = _toDate(log['date']);
      if (date == null) continue;
      final insideWeightPeriod =
          !date.isBefore(startDate) && !date.isAfter(endDate);
      if (insideWeightPeriod) {
        feedKg += _toDouble(log['feedKg'] ?? log['feed']);
      }
    }

    final biomassGainKg = fishCount * weightGainGram / 1000;
    if (feedKg <= 0 || biomassGainKg <= 0) {
      return {
        'hasData': false,
        'message': 'Ikke nok data',
        'feedKg': feedKg,
        'biomassGainKg': biomassGainKg,
        'startWeight': startWeight,
        'endWeight': endWeight,
        'days': days,
      };
    }

    final fcr = feedKg / biomassGainKg;
    if (!fcr.isFinite || fcr <= 0) {
      return _noData('Ikke nok data');
    }

    if (fcr > 5) {
      return {
        'hasData': false,
        'message': 'FCR virker unormalt høy. Sjekk fôr, flytting og snittvekt.',
        'fcr': fcr,
        'feedKg': feedKg,
        'biomassGainKg': biomassGainKg,
        'startWeight': startWeight,
        'endWeight': endWeight,
        'days': days,
      };
    }

    return {
      'hasData': true,
      'message': 'OK',
      'fcr': fcr,
      'feedKg': feedKg,
      'biomassGainKg': biomassGainKg,
      'startWeight': startWeight,
      'endWeight': endWeight,
      'days': days,
    };
  }

  static Map<String, dynamic> _noData(String message) {
    return {
      'hasData': false,
      'message': message,
    };
  }

  static DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _endOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
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

  static bool _isMovementLog(Map<String, dynamic> log) {
    final note = (log['note'] ?? log['notes'] ?? log['comment'] ?? '')
        .toString()
        .toLowerCase();
    final type =
        (log['type'] ?? log['eventType'] ?? '').toString().toLowerCase();

    return note.contains('flyttet') ||
        note.contains('mottok') ||
        type.contains('move') ||
        type.contains('flytt');
  }
}
