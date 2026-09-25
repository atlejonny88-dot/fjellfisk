/// Tolerant reads for legacy Firestore fields; never propagate NaN/Infinity.
class DataValues {
  static num? number(Object? value) {
    final parsed = value is num
        ? value
        : value is String
            ? num.tryParse(value.trim().replaceAll(',', '.'))
            : null;
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static double decimal(Object? value) => number(value)?.toDouble() ?? 0;
  static int integer(Object? value) => number(value)?.toInt() ?? 0;

  static double weight(Map<String, dynamic> data) {
    for (final key in [
      'avgWeight',
      'avgWeightGram',
      'averageWeight',
      'weight'
    ]) {
      final value = decimal(data[key]);
      if (value > 0) return value;
    }
    return 0;
  }
}
