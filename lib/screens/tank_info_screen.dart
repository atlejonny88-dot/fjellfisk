import 'package:flutter/material.dart';

import '../services/fcr_service.dart';
import '../services/growth_forecast_service.dart';
import '../services/tank_info_service.dart';
import '../l10n/localizations.dart';

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
        title: Text(context.l10n.tankInfoTitle(tankName)),
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
        if (snapshot.hasError) {
          return _loadError(
            context,
            context.l10n.recommendedFeedLabel,
            snapshot.error,
          );
        }
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
        final recommendedFeedName = latestWeight > 0
            ? TankInfoService.recommendedFeed(latestWeight)
            : '';
        final recommendedFeed = recommendedFeedName.isEmpty
            ? context.l10n.registerAverageWeightForFeed
            : recommendedFeedName;

        return _InfoCard(
          icon: Icons.restaurant,
          iconColor: const Color(0xFF2E7D32),
          title: context.l10n.recommendedFeedLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: context.l10n.latestAverageWeight,
                value: latestWeight > 0
                    ? '${latestWeight.toStringAsFixed(1)} g'
                    : context.l10n.notRegistered,
              ),
              _InfoRow(
                  label: context.l10n.recommendedFeedType,
                  value: recommendedFeed),
              _InfoRow(
                label: context.l10n.pelletSize,
                value: TankInfoService.pelletSize(latestWeight),
              ),
              FutureBuilder<Map<String, dynamic>?>(
                future: TankInfoService.recommendedFeedInventory(
                  recommendedFeedName,
                ),
                builder: (context, stockSnapshot) {
                  if (stockSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return _InfoRow(
                      label: context.l10n.stockLevel,
                      value: context.l10n.checkingStock,
                    );
                  }

                  if (stockSnapshot.hasError) {
                    return _InfoRow(
                      label: context.l10n.stockLevel,
                      value: context.l10n.notAvailable,
                    );
                  }

                  final feedData = stockSnapshot.data;
                  if (feedData == null) {
                    return _InfoRow(
                      label: context.l10n.stockLevel,
                      value: context.l10n.notFoundInActiveInventory,
                    );
                  }

                  final stockKg = TankInfoService.stockKg(feedData);
                  return _InfoRow(
                    label: context.l10n.stockLevel,
                    value: '${stockKg.toStringAsFixed(1)} kg',
                  );
                },
              ),
              _InfoRow(
                label: context.l10n.recommendedDailyFeedAmount,
                value: dailyFeedKg > 0
                    ? '${dailyFeedKg.toStringAsFixed(1)} kg/dag'
                    : context.l10n.notEnoughData,
              ),
              _InfoRow(
                label: context.l10n.feedPercent,
                value: feedPercent > 0
                    ? '${feedPercent.toStringAsFixed(1)} %'
                    : context.l10n.notEnoughData,
              ),
              _InfoRow(
                label: context.l10n.biomass,
                value: biomassKg > 0
                    ? '${biomassKg.toStringAsFixed(1)} kg (${(biomassKg / 1000).toStringAsFixed(2)} tonn)'
                    : context.l10n.notEnoughData,
              ),
              const SizedBox(height: 8),
              Text(
                _nextFeedMessage(context, latestWeight),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _loadError(BuildContext context, String title, Object? error) {
    debugPrint('$title: $error');
    return _InfoCard(
      icon: Icons.error_outline,
      iconColor: Colors.orange,
      title: title,
      child: Text(context.l10n.couldNotFetchData),
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
        if (snapshot.hasError) {
          return _loadError(context, 'FCR', snapshot.error);
        }
        if (!snapshot.hasData) {
          return _InfoCard(
            icon: Icons.show_chart,
            iconColor: Colors.blueGrey,
            title: 'FCR',
            child: Text(context.l10n.calculating),
          );
        }

        final data = snapshot.data!;
        if (data['hasData'] != true) {
          return _InfoCard(
            icon: Icons.show_chart,
            iconColor: Colors.blueGrey,
            title: 'FCR',
            child: Text(
              context.l10n.fcrUnavailable,
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
                label: context.l10n.startWeight,
                value: '${startWeight.toStringAsFixed(1)} g',
              ),
              _InfoRow(
                label: context.l10n.endWeight,
                value: '${endWeight.toStringAsFixed(1)} g',
              ),
              _InfoRow(
                label: context.l10n.biomassGain,
                value: '${biomassGainKg.toStringAsFixed(1)} kg',
              ),
              _InfoRow(
                label: context.l10n.feedUsed,
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
        if (snapshot.hasError) {
          return _loadError(
            context,
            context.l10n.growthForecast,
            snapshot.error,
          );
        }
        if (!snapshot.hasData) {
          return _InfoCard(
            icon: Icons.trending_up,
            iconColor: Colors.blue,
            title: context.l10n.growthForecast,
            child: Text(context.l10n.calculating),
          );
        }

        final data = snapshot.data!;
        if (data['hasData'] != true) {
          return _InfoCard(
            icon: Icons.trending_up,
            iconColor: Colors.blue,
            title: context.l10n.growthForecast,
            child: Text(context.l10n.notEnoughData),
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
          title: context.l10n.growthForecast,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: context.l10n.currentAverageWeight,
                value: '${lastWeight.toStringAsFixed(1)} g',
              ),
              _InfoRow(
                label: context.l10n.forecastDays(30),
                value: '${forecast30.toStringAsFixed(1)} g',
              ),
              _InfoRow(
                label: context.l10n.forecastDays(60),
                value: '${forecast60.toStringAsFixed(1)} g',
              ),
              _InfoRow(
                label: context.l10n.forecastDays(90),
                value: '${forecast90.toStringAsFixed(1)} g',
              ),
              _InfoRow(
                label: 'SGR',
                value: '${sgr.toStringAsFixed(2)} %/dag',
              ),
              _InfoRow(
                label: context.l10n.dataBasis,
                value: context.l10n.daysCount(daysMeasured),
              ),
            ],
          ),
        );
      },
    );
  }

  String _nextFeedMessage(BuildContext context, double weight) {
    if (weight <= 0) return context.l10n.noAverageWeightRegistered;
    if (weight < 2) {
      return context.l10n.weightUntilFeed(
        (2 - weight).toStringAsFixed(1),
        'Nutra Sprint 0.8',
      );
    }
    if (weight < 5) {
      return context.l10n.weightUntilFeed(
        (5 - weight).toStringAsFixed(1),
        'Nutra Sprint 1.0',
      );
    }
    if (weight < 15) {
      return context.l10n.weightUntilFeed(
        (15 - weight).toStringAsFixed(1),
        'Nutra Olympic 2.0',
      );
    }
    if (weight < 100) {
      return context.l10n.weightUntilFeed(
        (100 - weight).toStringAsFixed(1),
        'Polarfeed Laksens Valg 150',
      );
    }
    if (weight < 300) {
      return context.l10n.weightUntilFeed(
        (300 - weight).toStringAsFixed(1),
        'Polarfeed Laksens Valg 300',
      );
    }
    return context.l10n.finishFeedLargeFish;
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
