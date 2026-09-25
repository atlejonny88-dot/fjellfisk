import 'package:flutter/foundation.dart';

import '../utils/tank_status.dart';
import 'web_update_guard.dart';

/// In-memory progress only. Keys include the facility and section, not just tank ID.
class RegistrationRound extends ChangeNotifier {
  static final session = RegistrationRound();
  final Set<(String, String, String)> _reviewed = {};
  String? _userId;

  void setUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _reviewed.clear();
  }

  bool isReviewed(String facilityId, String sectionId, String tankId) =>
      _reviewed.contains((facilityId, sectionId, tankId));

  void markReviewed(String facilityId, String sectionId, String tankId) {
    _reviewed.add((facilityId, sectionId, tankId));
    notifyListeners();
  }

  List<Map<String, dynamic>> ordered(
    String facilityId,
    String sectionId,
    List<Map<String, dynamic>> tanks,
  ) {
    int priority(Map<String, dynamic> tank) {
      if (isReviewed(facilityId, sectionId, tank['id'].toString())) return 3;
      if (TankStatus.isActiveData(tank)) return 0;
      if (tank['activeNote'] != null ||
          tank['statusLevel'] == 'critical' ||
          tank['statusLevel'] == 'observation') {
        return 1;
      }
      return 2;
    }

    // Stable partitions preserve the existing order within each group.
    return [
      for (var group = 0; group <= 3; group++)
        ...tanks.where((tank) => priority(tank) == group),
    ];
  }

  Map<String, dynamic>? next(
    String facilityId,
    String sectionId,
    String currentTankId,
    List<Map<String, dynamic>> tanks,
  ) {
    for (final tank in ordered(facilityId, sectionId, tanks)) {
      final id = tank['id'].toString();
      if (id != currentTankId &&
          TankStatus.isActiveData(tank) &&
          !isReviewed(facilityId, sectionId, id)) {
        return tank;
      }
    }
    return null;
  }
}

/// Locks synchronously, including validation and reads before the actual write.
class RegistrationSave extends ChangeNotifier {
  bool busy = false;
  bool hasSaved = false;
  bool _disposed = false;

  Future<bool> run(Future<void> Function() operation) async {
    if (busy || _disposed) return false;
    busy = true;
    setWebSavePending(true);
    notifyListeners();
    try {
      await operation();
      hasSaved = true;
      return true;
    } finally {
      busy = false;
      setWebSavePending(false);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
