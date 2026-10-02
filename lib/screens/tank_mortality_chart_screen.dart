import '../utils/load_error.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/data_values.dart';
import '../l10n/localizations.dart';

class TankMortalityChartScreen extends StatelessWidget {
  final String facilityId;
  final String sectionId;
  final String tankId;
  final String tankName;

  const TankMortalityChartScreen({
    super.key,
    required this.facilityId,
    required this.sectionId,
    required this.tankId,
    required this.tankName,
  });

  Query<Map<String, dynamic>> get _logsQuery {
    return FirebaseFirestore.instance
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .doc(sectionId)
        .collection('tanks')
        .doc(tankId)
        .collection('logs')
        .orderBy('date');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.mortalityTitle(tankName)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _logsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(loadErrorMessage(context, snapshot.error)),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Text(context.l10n.noMortalityRecords),
            );
          }

          final barGroups = <BarChartGroupData>[];
          int totalDead = 0;

          for (int i = 0; i < docs.length; i++) {
            final data = docs[i].data();
            final raw = data['mortality'] ?? data['dead'] ?? 0;
            final dead = DataValues.integer(raw).clamp(0, 2147483647);

            totalDead += dead;

            barGroups.add(
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: dead.toDouble(),
                    width: 14,
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.mortalityPerRegistration,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      minY: 0,
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: true),
                      titlesData: const FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      barGroups: barGroups,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning),
                    title: Text(context.l10n.totalMortality),
                    subtitle: Text(context.l10n.fishCount(totalDead)),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.list),
                    title: Text(context.l10n.numberOfRegistrations),
                    subtitle: Text('${docs.length}'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
