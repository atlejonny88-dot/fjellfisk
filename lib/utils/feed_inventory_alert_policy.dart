import 'data_values.dart';

class FeedInventoryAlertPolicy {
  const FeedInventoryAlertPolicy._();

  static double stockKg(Map<String, dynamic> data) {
    final stored = DataValues.number(data['stockKg']);
    if (stored != null) return stored.toDouble();
    return DataValues.decimal(data['bags']) *
        DataValues.decimal(data['kgPerBag']);
  }

  /// A low-stock alert means less than one full bag remains.
  static double thresholdKg(Map<String, dynamic> data) {
    final kilograms = DataValues.decimal(data['kgPerBag']);
    return kilograms > 0 ? kilograms : 0;
  }

  static bool hasLowStock(Map<String, dynamic> data) {
    if (data['active'] == false) return false;
    final threshold = thresholdKg(data);
    final stock = stockKg(data);
    return threshold > 0 && stock >= 0 && stock < threshold;
  }
}
