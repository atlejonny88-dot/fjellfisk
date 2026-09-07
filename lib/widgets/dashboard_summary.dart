import 'package:flutter/material.dart';

class DashboardSummary extends StatelessWidget {
  final int totalFish;
  final int totalTanks;
  final int totalSections;

  const DashboardSummary({
    super.key,
    required this.totalFish,
    required this.totalTanks,
    required this.totalSections,
  });

  Widget _card(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _card('Totalt fisk', '$totalFish', Icons.set_meal),
        _card('Antall kar', '$totalTanks', Icons.pool),
        _card('Antall bygg', '$totalSections', Icons.home_work),
      ],
    );
  }
}
