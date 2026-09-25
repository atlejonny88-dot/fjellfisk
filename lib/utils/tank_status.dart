import 'data_values.dart';

class TankStatus {
  static int fishCountFrom(Object? value) {
    if (value == null) return 0;
    if (value is int) return value < 0 ? 0 : value;
    if (value is num && value.isFinite) {
      final count = value.toInt();
      return count < 0 ? 0 : count;
    }
    if (value is String) {
      final count = DataValues.integer(value);
      return count < 0 ? 0 : count;
    }
    return 0;
  }

  static bool isActiveFishCount(int fishCount) => fishCount > 0;

  static bool isActiveData(Map<String, dynamic> data) {
    return isActiveFishCount(fishCountFrom(data['fishCount']));
  }
}
