import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/language_controller.dart';
import '../l10n/localizations.dart';
import '../models/addon.dart';
import '../services/addon_service.dart';
import '../services/dashboard_temperature_service.dart';
import 'dashboard_v3_widgets.dart';

/// Dashboard presentation for facility-selected live Collector temperatures.
class DashboardTemperatureKpi extends StatelessWidget {
  const DashboardTemperatureKpi({
    super.key,
    required this.service,
    required this.facilityId,
    required this.configuration,
    required this.activeTanks,
  });

  final AddOnService service;
  final String facilityId;
  final DashboardTemperatureConfiguration configuration;
  final Set<DashboardTemperatureTankKey> activeTanks;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final mappings = <CollectorSensorMapping>[
          for (final collector in service.addOns)
            ...service.mappingsForCollector(collector.id),
        ];
        final summary = DashboardTemperatureCalculator.calculate(
          configuration: configuration,
          mappings: mappings,
          activeTanks: activeTanks,
          sensorForMapping: (mapping) => service.sensorForTank(
            facilityId: facilityId,
            sectionId: mapping.sectionId!,
            sectionName: mapping.sectionName ?? '',
            tankId: mapping.tankId!,
            tankName: mapping.tankName ?? '',
          ),
        );
        return _card(context, summary);
      },
    );
  }

  Widget _card(BuildContext context, DashboardTemperatureSummary summary) {
    final l10n = context.l10n;
    final value = switch (summary.state) {
      DashboardTemperatureState.live => '${NumberFormat.decimalPatternDigits(
          locale: LanguageScope.of(context).language.code,
          decimalDigits: 1,
        ).format(summary.roundedTemperatureC)} °C',
      DashboardTemperatureState.notConfigured =>
        l10n.dashboardTemperatureNotConfigured,
      DashboardTemperatureState.noData => l10n.noData,
    };
    final detail = switch (summary.state) {
      DashboardTemperatureState.live => summary.usesDefaultSelection
          ? l10n.dashboardTemperatureTemporaryDefault
          : l10n.dashboardTemperatureSourceCount(summary.includedTankCount),
      DashboardTemperatureState.notConfigured =>
        l10n.dashboardTemperatureChooseSources,
      DashboardTemperatureState.noData => l10n.dashboardTemperatureNoLiveData,
    };
    final note = switch (summary.state) {
      DashboardTemperatureState.live => l10n.dashboardTemperatureLive,
      DashboardTemperatureState.notConfigured =>
        l10n.dashboardTemperatureConfigureInSetup,
      DashboardTemperatureState.noData => l10n.notEnoughData,
    };
    return DashboardKpiCard(
      title: l10n.averageTemperature,
      value: value,
      detail: detail,
      note: note,
      icon: Icons.device_thermostat,
      accent: const Color(0xFF1678D2),
    );
  }
}
