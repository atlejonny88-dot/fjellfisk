import 'package:flutter/material.dart';

import '../services/fcr_service.dart';
import '../services/growth_forecast_service.dart';
import '../services/tank_info_service.dart';

class TankInfoScreen extends StatelessWidget {
  final String facilityId;
  final String sectionId;
  final String tankId;
  final String tankName;
  final int fishCount;

  const TankInfoScreen({
    super.key,
    required this.facilityId,
    required this.sectionId,
    required this.tankId,
    required this.tankName,
    required this.fishCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kar info - $tankName'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _recommendedFeedCard(),
          _fcrCard(),
          _growthForecastCard(),
        ],
      ),
    );
  }

  Widget _recommendedFeedCard() {
    return FutureBuilder<double>(
      future: TankInfoService.latestWeight(
        facilityId: facilityId,
        sectionId: sectionId,
        tankId: tankId,
      ),
      builder: (context, snapshot) {
        final latestWeight = snapshot.data ?? 0;
        final biomassKg = TankInfoService.biomassKg(
          fishCount: fishCount,
          avgWeightGram: latestWeight,
        );
        final feedPercent = TankInfoService.recommendedFeedPercent(
          latestWeight,
        );
        final dailyFeedKg = TankInfoService.recommendedDailyFeedKg(
          biomassKg: biomassKg,
          feedPercent: feedPercent,
        );
        final recommendedFeed = TankInfoService.recommendedFeed(latestWeight);

        return _InfoCard(
          icon: Icons.restaurant,
          iconColor: const Color(0xFF2E7D32),
          title: 'Anbefalt fôr',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: 'Siste snittvekt',
                value: latestWeight > 0
                    ? '${latestWeight.toStringAsFixed(1)} g'
                    : 'Ikke registrert',
              ),
              _InfoRow(label: 'Anbefalt fôrtype', value: recommendedFeed),
              _InfoRow(
                label: 'Pelletstørrelse',
                value: TankInfoService.pelletSize(latestWeight),
              ),
              FutureBuilder<Map<String, dynamic>?>(
                future: TankInfoService.recommendedFeedInventory(
                  recommendedFeed,
                ),
                builder: (context, stockSnapshot) {
                  if (stockSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const _InfoRow(
                      label: 'Lagerbeholdning',
                      value: 'Sjekker lager...',
                    );
                  }

                  if (stockSnapshot.hasError) {
                    return const _InfoRow(
                      label: 'Lagerbeholdning',
                      value: 'Ikke tilgjengelig',
                    );
                  }

                  final feedData = stockSnapshot.data;
                  if (feedData == null) {
                    return const _InfoRow(
                      label: 'Lagerbeholdning',
                      value: 'Ikke funnet i aktivt fôrlager',
                    );
                  }

                  final stockKg = TankInfoService.stockKg(feedData);
                  return _InfoRow(
                    label: 'Lagerbeholdning',
                    value: '${stockKg.toStringAsFixed(1)} kg',
                  );
                },
              ),
              _InfoRow(
                label: 'Anbefalt daglig fôrmengde',
                value: dailyFeedKg > 0
                    ? '${dailyFeedKg.toStringAsFixed(1)} kg/dag'
                    : 'Ikke nok data',
              ),
              _InfoRow(
                label: 'Fôrprosent',
                value: feedPercent > 0
                    ? '${feedPercent.toStringAsFixed(1)} %'
                    : 'Ikke nok data',
              ),
              _InfoRow(
                label: 'Biomasse',
                value: biomassKg > 0
                    ? '${biomassKg.toStringAsFixed(1)} kg (${(biomassKg / 1000).toStringAsFixed(2)} tonn)'
                    : 'Ikke nok data',
              ),
              const SizedBox(height: 8),
              Text(
                TankInfoService.nextFeedMessage(latestWeight),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fcrCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: FcrService.calculateTankFcr(
        facilityId: facilityId,
        sectionId: sectionId,
        tankId: tankId,
        currentFishCount: fishCount,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _InfoCard(
            icon: Icons.show_chart,
            iconColor: Colors.blueGrey,
            title: 'FCR',
            child: Text('Beregner...'),
          );
        }

        final data = snapshot.data!;
        if (data['hasData'] != true) {
          return _InfoCard(
            icon: Icons.show_chart,
            iconColor: Colors.blueGrey,
            title: 'FCR',
            child: Text(
              data['message']?.toString() ?? 'Ikke nok data til å beregne FCR',
            ),
          );
        }

        final fcr = TankInfoService.toDouble(data['fcr']);
        final feedKg = TankInfoService.toDouble(data['feedKg']);
        final biomassGainKg = TankInfoService.toDouble(
          data['biomassGainKg'],
        );
        final startWeight = TankInfoService.toDouble(data['startWeight']);
        final endWeight = TankInfoService.toDouble(data['endWeight']);

        Color color;
        if (fcr <= 1.0) {
          color = Colors.green;
        } else if (fcr <= 1.2) {
          color = Colors.orange;
        } else {
          color = Colors.red;
        }

        return _InfoCard(
          icon: Icons.show_chart,
          iconColor: color,
          title: 'FCR',
          trailing: Text(
            fcr.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: 'Startvekt',
                value: '${startWeight.toStringAsFixed(1)} g',
              ),
              _InfoRow(
                label: 'Sluttvekt',
                value: '${endWeight.toStringAsFixed(1)} g',
              ),
              _InfoRow(
                label: 'Biomasseøkning',
                value: '${biomassGainKg.toStringAsFixed(1)} kg',
              ),
              _InfoRow(
                label: 'Fôr brukt',
                value: '${feedKg.toStringAsFixed(1)} kg',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _growthForecastCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: GrowthForecastService.forecastTankGrowth(
        facilityId: facilityId,
        sectionId: sectionId,
        tankId: tankId,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _InfoCard(
            icon: Icons.trending_up,
            iconColor: Colors.blue,
            title: 'Vekstprognose',
            child: Text('Beregner...'),
          );
        }

        final data = snapshot.data!;
        if (data['hasData'] != true) {
          return _InfoCard(
            icon: Icons.trending_up,
            iconColor: Colors.blue,
            title: 'Vekstprognose',
            child: Text(data['message']?.toString() ?? 'Ikke nok data'),
          );
        }

        final sgr = TankInfoService.toDouble(data['sgr']);
        final lastWeight = TankInfoService.toDouble(data['lastWeight']);
        final forecast30 = TankInfoService.toDouble(data['forecast30']);
        final forecast60 = TankInfoService.toDouble(data['forecast60']);
        final forecast90 = TankInfoService.toDouble(data['forecast90']);
        final daysMeasured = TankInfoService.toInt(data['daysMeasured']);

        return _InfoCard(
          icon: Icons.trending_up,
          iconColor: Colors.blue,
          title: 'Vekstprognose',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: 'Nåværende snittvekt',
                value: '${lastWeight.toStringAsFixed(1)} g',
              ),
              _InfoRow(
                label: 'Prognose 30 dager',
                value: '${forecast30.toStringAsFixed(1)} g',
              ),
              _InfoRow(
                label: 'Prognose 60 dager',
                value: '${forecast60.toStringAsFixed(1)} g',
              ),
              _InfoRow(
                label: 'Prognose 90 dager',
                value: '${forecast90.toStringAsFixed(1)} g',
              ),
              _InfoRow(
                label: 'SGR',
                value: '${sgr.toStringAsFixed(2)} %/dag',
              ),
              _InfoRow(
                label: 'Datagrunnlag',
                value: '$daysMeasured dager',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
