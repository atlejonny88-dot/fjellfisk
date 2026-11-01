import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/language_controller.dart';
import '../l10n/localizations.dart';
import '../models/addon.dart';
import '../services/addon_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

enum _CollectorSetupFilter {
  all,
  configured,
  unconfigured,
}

class CollectorSetupScreen extends StatefulWidget {
  const CollectorSetupScreen({
    super.key,
    required this.service,
    required this.collectorId,
    this.roleLoader,
  });

  final AddOnService service;
  final String collectorId;
  final Future<String> Function()? roleLoader;

  @override
  State<CollectorSetupScreen> createState() => _CollectorSetupScreenState();
}

class _CollectorSetupScreenState extends State<CollectorSetupScreen> {
  late final Future<String> _roleFuture;
  final Map<String, CollectorSensorMapping> _draftMappings = {};
  _CollectorSetupFilter _filter = _CollectorSetupFilter.all;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _roleFuture = (widget.roleLoader ?? UserService.getCurrentUserRole)();
    for (final mapping
        in widget.service.mappingsForCollector(widget.collectorId)) {
      _draftMappings[mapping.sensorId] = mapping;
    }
    widget.service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  AddOn? get _collector {
    for (final addOn in widget.service.addOns) {
      if (addOn.id == widget.collectorId) return addOn;
    }
    return null;
  }

  CollectorSectionOption? _sectionForId(String? sectionId) {
    for (final section in MockCollectorSetupCatalog.sections) {
      if (section.id == sectionId) return section;
    }
    return null;
  }

  CollectorSensorMapping _mappingFor(CollectorSensor sensor) =>
      _draftMappings[sensor.id] ??
      CollectorSensorMapping(
        collectorId: widget.collectorId,
        sensorId: sensor.id,
      );

  void _selectSection(CollectorSensor sensor, String? sectionId) {
    final section = _sectionForId(sectionId);
    if (section == null) return;
    setState(() {
      _draftMappings[sensor.id] = _mappingFor(sensor).copyWith(
        facilityId: MockCollectorSetupCatalog.facilityId,
        sectionId: section.id,
        sectionName: section.name,
        clearTank: true,
      );
    });
  }

  void _selectTank(CollectorSensor sensor, String? tankId) {
    final mapping = _mappingFor(sensor);
    final section = _sectionForId(mapping.sectionId);
    if (section == null || tankId == null) return;
    CollectorTankOption? tank;
    for (final candidate in section.tanks) {
      if (candidate.id == tankId) {
        tank = candidate;
        break;
      }
    }
    final selectedTank = tank;
    if (selectedTank == null) return;
    setState(() {
      _draftMappings[sensor.id] = mapping.copyWith(
        tankId: selectedTank.id,
        tankName: selectedTank.name,
      );
    });
  }

  Future<void> _save(bool canManage) async {
    if (!canManage || _saving || _collector?.isConnected != true) return;
    setState(() => _saving = true);
    try {
      await widget.service.saveCollectorMappings(
        widget.collectorId,
        _draftMappings.values,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.collectorSetupSaved)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collector = _collector;
    final l10n = context.l10n;
    if (collector == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.collectorSetup)),
        body: Center(child: Text(l10n.collectorNotAvailable)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.collectorSetup)),
      body: FutureBuilder<String>(
        future: _roleFuture,
        builder: (context, roleSnapshot) {
          final canManage = roleSnapshot.data == 'admin';
          final sensors = widget.service.sensorsForCollector(collector.id);
          final visibleSensors = sensors.where((sensor) {
            final configured = _mappingFor(sensor).isComplete;
            return switch (_filter) {
              _CollectorSetupFilter.all => true,
              _CollectorSetupFilter.configured => configured,
              _CollectorSetupFilter.unconfigured => !configured,
            };
          }).toList(growable: false);

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.collectorSetup,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.collectorSetupSubtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _CollectorConnectionCard(
                      collector: collector,
                      sensors: sensors,
                      configuredCount: sensors
                          .where((sensor) => _mappingFor(sensor).isComplete)
                          .length,
                    ),
                    const SizedBox(height: 18),
                    if (!canManage) _ReadOnlyBanner(),
                    if (!canManage) const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F8FC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            l10n.filter,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          _FilterChip(
                            label: l10n.all,
                            selected: _filter == _CollectorSetupFilter.all,
                            onSelected: () => setState(
                              () => _filter = _CollectorSetupFilter.all,
                            ),
                          ),
                          _FilterChip(
                            label: l10n.collectorConfigured,
                            selected:
                                _filter == _CollectorSetupFilter.configured,
                            onSelected: () => setState(
                              () => _filter = _CollectorSetupFilter.configured,
                            ),
                          ),
                          _FilterChip(
                            label: l10n.collectorNotConfigured,
                            selected:
                                _filter == _CollectorSetupFilter.unconfigured,
                            onSelected: () => setState(
                              () =>
                                  _filter = _CollectorSetupFilter.unconfigured,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (visibleSensors.isEmpty)
                      _EmptySensorState()
                    else
                      ...visibleSensors.map(
                        (sensor) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _SensorMappingCard(
                            key: ValueKey('sensor-card-${sensor.id}'),
                            sensor: sensor,
                            mapping: _mappingFor(sensor),
                            canManage: canManage && collector.isConnected,
                            onSectionChanged: (sectionId) =>
                                _selectSection(sensor, sectionId),
                            onTankChanged: (tankId) =>
                                _selectTank(sensor, tankId),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        key: const ValueKey('save-collector-setup'),
                        onPressed:
                            canManage && collector.isConnected && !_saving
                                ? () => _save(canManage)
                                : null,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _saving ? l10n.saving : l10n.saveCollectorSetup,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CollectorConnectionCard extends StatelessWidget {
  const _CollectorConnectionCard({
    required this.collector,
    required this.sensors,
    required this.configuredCount,
  });

  final AddOn collector;
  final List<CollectorSensor> sensors;
  final int configuredCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 28,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.sensors_outlined,
                    color: AppTheme.oceanBlue,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.collectorAddOnName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _CollectorStateLabel(connected: collector.isConnected),
                  ],
                ),
              ],
            ),
            _Detail(label: l10n.collectorDevice, value: collector.deviceName),
            _Detail(
                label: l10n.collectorDataSource, value: collector.readerType),
            _Detail(
              label: l10n.collectorSensorsDetected,
              value: l10n.sensorsCount(sensors.length),
            ),
            _Detail(
              label: l10n.collectorSensorsConfigured,
              value: '$configuredCount',
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value ?? context.l10n.notAvailable,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectorStateLabel extends StatelessWidget {
  const _CollectorStateLabel({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? const Color(0xFF15803D) : const Color(0xFF64748B);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 9, color: color),
        const SizedBox(width: 6),
        Text(
          connected
              ? context.l10n.addOnStatusConnected
              : context.l10n.addOnStatusNotConnected,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: const Color(0xFFDCEBFF),
      labelStyle: TextStyle(
        color: selected ? AppTheme.oceanBlue : AppTheme.textSecondary,
        fontWeight: FontWeight.w700,
      ),
      side: const BorderSide(color: AppTheme.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
    );
  }
}

class _SensorMappingCard extends StatelessWidget {
  const _SensorMappingCard({
    super.key,
    required this.sensor,
    required this.mapping,
    required this.canManage,
    required this.onSectionChanged,
    required this.onTankChanged,
  });

  final CollectorSensor sensor;
  final CollectorSensorMapping mapping;
  final bool canManage;
  final ValueChanged<String?> onSectionChanged;
  final ValueChanged<String?> onTankChanged;

  CollectorSectionOption? get _section {
    for (final item in MockCollectorSetupCatalog.sections) {
      if (item.id == mapping.sectionId) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final section = _section;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.sensors_outlined, color: AppTheme.oceanBlue),
                Text(
                  sensor.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                _SensorStatusChip(sensor: sensor),
              ],
            ),
            const SizedBox(height: 14),
            _SensorReadings(sensor: sensor),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final sectionField = DropdownButtonFormField<String>(
                  key: ValueKey('collector-setup-section-${sensor.id}'),
                  initialValue: section?.id,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.sectionBuilding),
                  items: MockCollectorSetupCatalog.sections
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: canManage ? onSectionChanged : null,
                );
                final tankField = DropdownButtonFormField<String>(
                  key: ValueKey('collector-setup-tank-${sensor.id}'),
                  initialValue: _hasTankId(section, mapping.tankId)
                      ? mapping.tankId
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.tank),
                  items: (section?.tanks ?? const <CollectorTankOption>[])
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged:
                      canManage && section != null ? onTankChanged : null,
                );

                if (constraints.maxWidth < 620) {
                  return Column(
                    children: [
                      sectionField,
                      const SizedBox(height: 12),
                      tankField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: sectionField),
                    const SizedBox(width: 12),
                    Expanded(child: tankField),
                  ],
                );
              },
            ),
            if (mapping.isComplete) ...[
              const SizedBox(height: 16),
              _LivePreview(sensor: sensor, mapping: mapping),
            ],
          ],
        ),
      ),
    );
  }
}

class _SensorStatusChip extends StatelessWidget {
  const _SensorStatusChip({required this.sensor});

  final CollectorSensor sensor;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _sensorStatus(context, sensor.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorReadings extends StatelessWidget {
  const _SensorReadings({required this.sensor});

  final CollectorSensor sensor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 10,
      children: [
        _Reading(
          label: context.l10n.temperature,
          value: _temperature(context, sensor),
        ),
        _Reading(
          label: context.l10n.oxygenConcentration,
          value: _oxygen(context, sensor),
        ),
        _Reading(
          label: context.l10n.oxygenSaturation,
          value: _saturation(context, sensor),
        ),
      ],
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.sensor, required this.mapping});

  final CollectorSensor sensor;
  final CollectorSensorMapping mapping;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('collector-live-preview-${sensor.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFDCE7F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${sensor.name} → ${mapping.sectionName} → ${mapping.tankName}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _SensorReadings(sensor: sensor),
          const SizedBox(height: 10),
          _SensorUpdateLabel(sensor: sensor),
        ],
      ),
    );
  }
}

class _SensorUpdateLabel extends StatelessWidget {
  const _SensorUpdateLabel({required this.sensor});

  final CollectorSensor sensor;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _sensorStatus(context, sensor.status);
    final now = DateTime.now();
    final difference = now.difference(sensor.updatedAt).abs();
    final l10n = context.l10n;
    final timestamp = DateFormat(
      'HH:mm',
      LanguageScope.of(context).language.code,
    ).format(sensor.updatedAt.toLocal());
    final detail = switch (sensor.status) {
      CollectorSensorStatus.live => difference.inSeconds == 0
          ? l10n.collectorUpdatedNow
          : l10n.collectorUpdatedSecondsAgo(difference.inSeconds),
      CollectorSensorStatus.stale =>
        l10n.collectorLastUpdatedMinutesAgo(difference.inMinutes),
      CollectorSensorStatus.offline => l10n.collectorLastDataAt(timestamp),
    };
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(
          '$label · $detail',
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF2D58A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFF9A6700)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.collectorSetupAdminOnly,
              style: const TextStyle(
                color: Color(0xFF624600),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySensorState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Center(
        child: Text(
          context.l10n.collectorNoSensorsInFilter,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}

(String, Color) _sensorStatus(
  BuildContext context,
  CollectorSensorStatus status,
) =>
    switch (status) {
      CollectorSensorStatus.live => (
          context.l10n.collectorLive,
          const Color(0xFF15803D)
        ),
      CollectorSensorStatus.stale => (
          context.l10n.collectorStale,
          const Color(0xFFD97706)
        ),
      CollectorSensorStatus.offline => (
          context.l10n.collectorOffline,
          const Color(0xFF64748B)
        ),
    };

String _decimal(
  BuildContext context,
  double? value, {
  int digits = 1,
}) {
  if (value == null) return '—';
  return NumberFormat.decimalPatternDigits(
    locale: LanguageScope.of(context).language.code,
    decimalDigits: digits,
  ).format(value);
}

bool _hasTankId(CollectorSectionOption? section, String? tankId) {
  if (section == null || tankId == null) return false;
  return section.tanks.any((tank) => tank.id == tankId);
}

String _temperature(BuildContext context, CollectorSensor sensor) =>
    sensor.temperatureC == null
        ? '—'
        : '${_decimal(context, sensor.temperatureC)} °C';

String _oxygen(BuildContext context, CollectorSensor sensor) =>
    sensor.oxygenMgL == null
        ? '—'
        : '${_decimal(context, sensor.oxygenMgL)} mg/L';

String _saturation(BuildContext context, CollectorSensor sensor) =>
    sensor.oxygenSaturationPct == null
        ? '—'
        : '${_decimal(context, sensor.oxygenSaturationPct, digits: 0)} %';
