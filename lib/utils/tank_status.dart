class TankStatus {
  static int fishCountFrom(Object? value) {
    if (value == null) return 0;
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) {
      final count = value.toInt();
      return count < 0 ? 0 : count;
    }
    if (value is String) {
      final count = int.tryParse(value.trim()) ?? 0;
      return count < 0 ? 0 : count;
    }
    return 0;
  }

  static bool isActiveFishCount(int fishCount) => fishCount > 0;

  static bool isActiveData(Map<String, dynamic> data) {
    return isActiveFishCount(fishCountFrom(data['fishCount']));
  }
}
