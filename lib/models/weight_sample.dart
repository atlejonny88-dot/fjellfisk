import 'package:cloud_firestore/cloud_firestore.dart';

class WeightSampleStats {
  final List<double> weightsGram;
  final int count;
  final double averageGram;
  final double medianGram;
  final double minGram;
  final double maxGram;
  final double standardDeviationGram;
  final double spreadGram;
  final Map<String, int> distribution;

  const WeightSampleStats({
    required this.weightsGram,
    required this.count,
    required this.averageGram,
    required this.medianGram,
    required this.minGram,
    required this.maxGram,
    required this.standardDeviationGram,
    required this.spreadGram,
    required this.distribution,
  });
}

class WeightSample {
  final String id;
  final DateTime? date;
  final List<double> weightsGram;
  final int count;
  final double averageGram;
  final double medianGram;
  final double minGram;
  final double maxGram;
  final double standardDeviationGram;
  final double spreadGram;
  final Map<String, int> distribution;
  final String createdByEmail;
  final String note;

  const WeightSample({
    required this.id,
    required this.date,
    required this.weightsGram,
    required this.count,
    required this.averageGram,
    required this.medianGram,
    required this.minGram,
    required this.maxGram,
    required this.standardDeviationGram,
    required this.spreadGram,
    required this.distribution,
    required this.createdByEmail,
    required this.note,
  });

  factory WeightSample.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawWeights = data['weightsGram'];
    final weights = rawWeights is List
        ? rawWeights
            .map((value) => _toDouble(value))
            .where((value) => value > 0)
            .toList()
        : <double>[];

    return WeightSample(
      id: doc.id,
      date: _toDate(data['date']),
      weightsGram: weights,
      count: _toInt(data['count']),
      averageGram: _toDouble(data['averageGram']),
      medianGram: _toDouble(data['medianGram']),
      minGram: _toDouble(data['minGram']),
      maxGram: _toDouble(data['maxGram']),
      standardDeviationGram: _toDouble(data['standardDeviationGram']),
      spreadGram: _toDouble(data['spreadGram']),
      distribution: _distributionFrom(data['distribution']),
      createdByEmail: (data['createdByEmail'] ?? 'ukjent').toString(),
      note: (data['note'] ?? '').toString(),
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

  static Map<String, int> _distributionFrom(Object? value) {
    if (value is! Map) return const <String, int>{};
    return value.map((key, entry) => MapEntry(key.toString(), _toInt(entry)));
  }
}
