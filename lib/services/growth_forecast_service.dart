import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/tank_status.dart';

class GrowthForecastService {
  static final _db = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> forecastTankGrowth({
    required String facilityId,
    required String sectionId,
    required String tankId,
  }) async {
    final tankRef = _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .doc(sectionId)
        .collection('tanks')
        .doc(tankId);

    final tankSnap = await tankRef.get();
    final tankData = tankSnap.data();
    final fishCount = TankStatus.fishCountFrom(tankData?['fishCount']);

    if (!TankStatus.isActiveFishCount(fishCount)) {
      return {
        'hasData': false,
        'message': 'Tomt kar - vekstprognose beregnes ikke',
      };
    }

    final snap = await tankRef.collection('logs').orderBy('date').get();

    final weightLogs = snap.docs.where((doc) {
      final data = doc.data();
      return _weightFromLog(data) > 0 && data['date'] is Timestamp;
    }).toList();

    if (weightLogs.length < 2) {
      return {
        'hasData': false,
        'message': 'Trenger minst to snittvekter for å lage prognose',
      };
    }

    final firstData = weightLogs.first.data();
    final lastData = weightLogs.last.data();

    final firstWeight = _weightFromLog(firstData);
    final lastWeight = _weightFromLog(lastData);

    final firstDateRaw = firstData['date'];
    final lastDateRaw = lastData['date'];

    if (firstDateRaw is! Timestamp || lastDateRaw is! Timestamp) {
      return {
        'hasData': false,
        'message': 'Mangler dato på vektregistrering',
      };
    }

    final firstDate = firstDateRaw.toDate();
    final lastDate = lastDateRaw.toDate();
    final days = lastDate.difference(firstDate).inDays;

    if (days <= 0 || firstWeight <= 0 || lastWeight <= firstWeight) {
      return {
        'hasData': false,
        'message': 'Ikke nok positiv vekst ennå',
      };
    }

    if (days < 7) {
      return {
        'hasData': false,
        'message':
            'Ikke nok data til trygg vekstprognose. Trenger minst 7 dager mellom vektregistreringene.',
        'firstWeight': firstWeight,
        'lastWeight': lastWeight,
        'daysMeasured': days,
      };
    }

    final sgr = ((log(lastWeight) - log(firstWeight)) / days) * 100;

    if (!sgr.isFinite || sgr <= 0 || sgr > 5) {
      return {
        'hasData': false,
        'message': 'Vekstprognosen virker urimelig. Sjekk snittvekt og datoer.',
        'sgr': sgr,
        'firstWeight': firstWeight,
        'lastWeight': lastWeight,
        'daysMeasured': days,
      };
    }

    double forecastWeight(int daysAhead) {
      return lastWeight * exp((sgr / 100) * daysAhead);
    }

    final forecast30 = forecastWeight(30);
    final forecast60 = forecastWeight(60);
    final forecast90 = forecastWeight(90);

    if (!forecast30.isFinite ||
        !forecast60.isFinite ||
        !forecast90.isFinite ||
        forecast90 > lastWeight * 10) {
      return {
        'hasData': false,
        'message':
            'Vekstprognosen blir for høy til å vises trygt. Sjekk datagrunnlaget.',
        'sgr': sgr,
        'lastWeight': lastWeight,
        'daysMeasured': days,
      };
    }

    return {
      'hasData': true,
      'sgr': sgr,
      'lastWeight': lastWeight,
      'daysMeasured': days,
      'forecast30': forecast30,
      'forecast60': forecast60,
      'forecast90': forecast90,
    };
  }

  static double _weightFromLog(Map<String, dynamic> data) {
    final candidates = [
      data['avgWeight'],
      data['avgWeightGram'],
      data['averageWeight'],
      data['weight'],
    ];

    for (final value in candidates) {
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
}
