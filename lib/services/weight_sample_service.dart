import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/weight_sample.dart';
import 'firestore_service.dart';
import 'user_service.dart';

class WeightSampleParseResult {
  final List<double> validWeights;
  final List<String> invalidValues;

  const WeightSampleParseResult({
    required this.validWeights,
    required this.invalidValues,
  });
}

class WeightSampleService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const double maxWeightGram = 50000;

  static CollectionReference<Map<String, dynamic>> samplesRef({
    required String facilityId,
    required String sectionId,
    required String tankId,
  }) {
    return _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .doc(sectionId)
        .collection('tanks')
        .doc(tankId)
        .collection('weightSamples');
  }

  static Stream<List<WeightSample>> samplesStream({
    required String facilityId,
    required String sectionId,
    required String tankId,
  }) {
    return samplesRef(
      facilityId: facilityId,
      sectionId: sectionId,
      tankId: tankId,
    ).orderBy('date', descending: true).snapshots().map((snap) {
      return snap.docs.map(WeightSample.fromDoc).toList();
    });
  }

  static WeightSampleParseResult parseWeights(String input) {
    final normalized = input.trim();
    if (normalized.isEmpty) {
      return const WeightSampleParseResult(
        validWeights: [],
        invalidValues: [],
      );
    }

    final parts = normalized
        .split(RegExp(r'[\s;]+|,(?=\s|\d{4,}|$)'))
        .expand((part) => part.split(RegExp(r'\n+')))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    final valid = <double>[];
    final invalid = <String>[];

    for (final part in parts) {
      final parsed = double.tryParse(part.replaceAll(',', '.'));
      if (parsed == null || parsed <= 0 || parsed > maxWeightGram) {
        invalid.add(part);
      } else {
        valid.add(parsed);
      }
    }

    return WeightSampleParseResult(
      validWeights: valid,
      invalidValues: invalid,
    );
  }

  static WeightSampleStats calculateStats(List<double> weights) {
    if (weights.isEmpty) {
      throw ArgumentError('Tom vektliste');
    }

    final sorted = [...weights]..sort();
    final count = sorted.length;
    final sum = sorted.fold<double>(0, (total, value) => total + value);
    final average = sum / count;
    final middle = count ~/ 2;
    final median = count.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
    final minWeight = sorted.first;
    final maxWeight = sorted.last;
    final variance = sorted.fold<double>(
            0, (total, value) => total + pow(value - average, 2)) /
        count;
    final standardDeviation = sqrt(variance);

    return WeightSampleStats(
      weightsGram: sorted,
      count: count,
      averageGram: average,
      medianGram: median,
      minGram: minWeight,
      maxGram: maxWeight,
      standardDeviationGram: standardDeviation,
      spreadGram: maxWeight - minWeight,
      distribution: distribution(sorted),
    );
  }

  static Map<String, int> distribution(List<double> weights) {
    final buckets = <String, int>{
      'Under 100 g': 0,
      '100-199 g': 0,
      '200-299 g': 0,
      '300-399 g': 0,
      '400 g og over': 0,
    };

    for (final weight in weights) {
      if (weight < 100) {
        buckets['Under 100 g'] = buckets['Under 100 g']! + 1;
      } else if (weight < 200) {
        buckets['100-199 g'] = buckets['100-199 g']! + 1;
      } else if (weight < 300) {
        buckets['200-299 g'] = buckets['200-299 g']! + 1;
      } else if (weight < 400) {
        buckets['300-399 g'] = buckets['300-399 g']! + 1;
      } else {
        buckets['400 g og over'] = buckets['400 g og over']! + 1;
      }
    }

    return buckets;
  }

  static Future<void> saveWeightSample({
    required String facilityId,
    required String sectionId,
    required String tankId,
    required List<double> weightsGram,
    String note = '',
  }) async {
    if (weightsGram.isEmpty) {
      throw ArgumentError('Legg til minst én vekt før lagring.');
    }

    for (final weight in weightsGram) {
      if (weight <= 0 || weight > maxWeightGram || !weight.isFinite) {
        throw ArgumentError('Ugyldig vekt: ${weight.toStringAsFixed(1)} g');
      }
    }

    final stats = calculateStats(weightsGram);
    final user = UserService.currentUser;
    final now = Timestamp.now();

    await samplesRef(
      facilityId: facilityId,
      sectionId: sectionId,
      tankId: tankId,
    ).add({
      'date': now,
      'weightsGram': stats.weightsGram,
      'count': stats.count,
      'averageGram': stats.averageGram,
      'medianGram': stats.medianGram,
      'minGram': stats.minGram,
      'maxGram': stats.maxGram,
      'standardDeviationGram': stats.standardDeviationGram,
      'spreadGram': stats.spreadGram,
      'distribution': stats.distribution,
      'createdAt': now,
      'createdByUid': user?.uid,
      'createdByEmail': user?.email ?? 'ukjent',
      'note': note.trim(),
    });

    await FirestoreService.addDailyLog(
      facilityId: facilityId,
      sectionId: sectionId,
      tankId: tankId,
      mortality: 0,
      feedKg: 0,
      avgWeight: stats.averageGram,
      temperature: 0,
    );
  }
}
