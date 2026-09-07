import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class TankChartScreen extends StatelessWidget {
  final String facilityId;
  final String sectionId;
  final String tankId;
  final String tankName;

  const TankChartScreen({
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

  double? _calculateSgr(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final valid = docs.where((doc) {
      final data = doc.data();
      return data['avgWeight'] is num && data['date'] is Timestamp;
    }).toList();

    if (valid.length < 2) return null;

    final first = valid.first.data();
    final last = valid.last.data();

    final w1 = (first['avgWeight'] as num).toDouble();
    final w2 = (last['avgWeight'] as num).toDouble();
    final d1 = (first['date'] as Timestamp).toDate();
    final d2 = (last['date'] as Timestamp).toDate();

    final days = d2.difference(d1).inDays;
    if (w1 <= 0 || w2 <= 0 || days <= 0) return null;

    return ((log(w2) - log(w1)) / days) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vekst – $tankName'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _logsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Feil: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data();
            final weight = data['avgWeight'];
            return weight is num && weight > 0;
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text('Ingen vektregistreringer ennå'),
            );
          }

          final spots = <FlSpot>[];

          for (int i = 0; i < docs.length; i++) {
            final data = docs[i].data();
            final weight = (data['avgWeight'] as num).toDouble();
            spots.add(FlSpot(i.toDouble(), weight));
          }

          final sgr = _calculateSgr(docs);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Snittvekt over tid',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: LineChart(
                    LineChartData(
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
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.trending_up),
                    title: const Text('SGR'),
                    subtitle: Text(
                      sgr == null
                          ? 'Ikke nok data'
                          : '${sgr.toStringAsFixed(2)} % / dag',
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.scale),
                    title: const Text('Siste snittvekt'),
                    subtitle: Text(
                      '${(docs.last.data()['avgWeight'] as num).toStringAsFixed(1)} g',
                    ),
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
