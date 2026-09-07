import 'dart:math';

double calculateSGR({
  required double startWeight,
  required double endWeight,
  required int days,
}) {
  if (startWeight <= 0 || endWeight <= 0 || days <= 0) {
    return 0;
  }

  return ((log(endWeight) - log(startWeight)) / days) * 100;
}
