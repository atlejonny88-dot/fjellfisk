import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/localizations.dart';
import '../models/addon.dart';
import '../services/addon_service.dart';
import '../services/dashboard_temperature_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

class DashboardTemperatureSettingsScreen extends StatefulWidget {
  const DashboardTemperatureSettingsScreen({
    super.key,
    required this.facilityId,
    required this.service,
    this.store,
    this.roleLoader,
  });

  final String facilityId;
  final AddOnService service;
  final DashboardTemperatureConfigurationStore? store;
  final Future<String> Function()? roleLoader;

  @override
  State<DashboardTemperatureSettingsScreen> createState() =>
      _DashboardTemperatureSettingsScreenState();
}

class _DashboardTemperatureSettingsScreenState
    extends State<DashboardTemperatureSettingsScreen> {
  late final DashboardTemperatureConfigurationStore _store;
  late final Future<String> _roleFuture;
  Set<DashboardTemperatureTankKey>? _selectedTanks;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? FirestoreDashboardTemperatureConfigurationStore();
    _roleFuture = (widget.roleLoader ?? UserService.getCurrentUserRole)();
    widget.service.addListener(_onServiceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.service.loadSections());
    });
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  List<_TemperatureTankCandidate> _candidates() {
    final candidates =
        <DashboardTemperatureTankKey, _TemperatureTankCandidate>{};
    for (final collector in widget.service.addOns) {
      for (final mapping in widget.service.mappingsForCollector(collector.id)) {
        if (!mapping.isComplete ||
            mapping.facilityId != null &&
                mapping.facilityId != widget.facilityId) {
          continue;
        }
        CollectorSectionOption? section;
        for (final candidate in widget.service.sections) {
          if (candidate.id == mapping.sectionId) {
            section = candidate;
            break;
          }
        }
        CollectorTankOption? tank;
        if (section != null) {
          for (final candidate in section.tanks) {
            if (candidate.id == mapping.tankId) {
              tank = candidate;
              break;
            }
          }
        }
        if (section == null || tank == null || !tank.isActive) continue;
        final selectedSection = section;
        final selectedTank = tank;
        final key = DashboardTemperatureTankKey(
          sectionId: mapping.sectionId!,
          tankId: mapping.tankId!,
        );
        candidates.putIfAbsent(
          key,
          () => _TemperatureTankCandidate(
            key: key,
            sectionName: selectedSection.name,
            tankName: selectedTank.name,
          ),
        );
      }
    }
    return candidates.values.toList(growable: false)
      ..sort((left, right) {
        final section = left.sectionName.compareTo(right.sectionName);
        return section == 0 ? left.tankName.compareTo(right.tankName) : section;
      });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _store.save(
        widget.facilityId,
        DashboardTemperatureConfiguration(
          isConfigured: true,
          selectedTanks: Set.unmodifiable(_selectedTanks ?? const {}),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.dashboardTemperatureSaved)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.dashboardTemperatureSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dashboardTemperatureSettings)),
      body: FutureBuilder<String>(
        future: _roleFuture,
        builder: (context, roleSnapshot) {
          final canManage = roleSnapshot.data == 'admin';
          return StreamBuilder<DashboardTemperatureConfiguration>(
            stream: _store.watch(widget.facilityId),
            builder: (context, snapshot) {
              final configuration = snapshot.data ??
                  const DashboardTemperatureConfiguration.unconfigured();
              _selectedTanks ??= Set.of(configuration.selectedTanks);
              final candidates = _candidates();
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.dashboardTemperatureSettings,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.dashboardTemperatureSettingsSubtitle,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (!canManage) const _TemperatureReadOnlyBanner(),
                        if (!canManage) const SizedBox(height: 18),
                        if (!configuration.isConfigured)
                          _InformationCard(
                            text: context
                                .l10n.dashboardTemperatureDefaultSelection,
                          ),
                        if (!configuration.isConfigured)
                          const SizedBox(height: 14),
                        if (widget.service.sectionsUnavailable)
                          _InformationCard(
                            isError: true,
                            text: context.l10n.collectorCatalogUnavailable,
                          )
                        else if (candidates.isEmpty)
                          _InformationCard(
                            text: context
                                .l10n.dashboardTemperatureNoEligibleTanks,
                          )
                        else
                          Card(
                            margin: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (final candidate in candidates)
                                  CheckboxListTile(
                                    key: ValueKey(
                                      'dashboard-temperature-${candidate.key.sectionId}-${candidate.key.tankId}',
                                    ),
                                    value:
                                        _selectedTanks!.contains(candidate.key),
                                    onChanged: canManage
                                        ? (selected) => setState(() {
                                              if (selected == true) {
                                                _selectedTanks!
                                                    .add(candidate.key);
                                              } else {
                                                _selectedTanks!
                                                    .remove(candidate.key);
                                              }
                                            })
                                        : null,
                                    title: Text(candidate.tankName),
                                    subtitle: Text(candidate.sectionName),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            key: const ValueKey(
                              'save-dashboard-temperature-settings',
                            ),
                            onPressed: canManage && !_saving ? _save : null,
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
                              _saving ? context.l10n.saving : context.l10n.save,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TemperatureTankCandidate {
  const _TemperatureTankCandidate({
    required this.key,
    required this.sectionName,
    required this.tankName,
  });

  final DashboardTemperatureTankKey key;
  final String sectionName;
  final String tankName;
}

class _TemperatureReadOnlyBanner extends StatelessWidget {
  const _TemperatureReadOnlyBanner();

  @override
  Widget build(BuildContext context) => _InformationCard(
        text: context.l10n.dashboardTemperatureAdminOnly,
      );
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color =
        isError ? Theme.of(context).colorScheme.error : AppTheme.oceanBlue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
