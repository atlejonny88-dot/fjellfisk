import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardMiniChart extends StatelessWidget {
  final String facilityId;

  const DashboardMiniChart({
    super.key,
    required this.facilityId,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [
                FlSpot(0, 2),
                FlSpot(1, 4),
                FlSpot(2, 3),
                FlSpot(3, 5),
              ],
              isCurved: true,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
