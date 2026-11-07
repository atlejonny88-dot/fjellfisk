import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/language_controller.dart';
import '../l10n/localizations.dart';
import '../models/vacon_control.dart';
import '../services/user_service.dart';
import '../services/vacon_control_service.dart';
import '../theme/app_theme.dart';
import '../utils/ui_motion.dart';
import 'vacon_setup_screen.dart';

/// Add-ons > VACON Control. Flutter uses the protected HTTPS API only. It
/// never connects to a VPN, Modbus TCP, or a physical drive directly.
class VaconControlScreen extends StatefulWidget {
  const VaconControlScreen({
    super.key,
    required this.facilityId,
    this.service,
    this.roleLoader,
  });

  final String facilityId;
  final VaconControlService? service;
  final Future<String> Function()? roleLoader;

  @override
  State<VaconControlScreen> createState() => _VaconControlScreenState();
}

class _VaconControlScreenState extends State<VaconControlScreen> {
  late final VaconControlService _service;
  late final Future<String> _roleFuture;
  bool _commandBusy = false;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MockVaconControlService.shared;
    _roleFuture = (widget.roleLoader ?? UserService.getCurrentUserRole)();
    _service.addListener(_onServiceChanged);
    _refresh();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _service.refreshFacility(widget.facilityId);
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _loading = false;
    });
  }

  Future<void> _openSetup({VaconDevice? device}) async {
    final saved = await Navigator.of(context).push<bool>(
      subtleFadeSlideRoute<bool>(
        context: context,
        builder: (_) => VaconSetupScreen(
          facilityId: widget.facilityId,
          service: _service,
          device: device,
        ),
      ),
    );
    if (saved == true && mounted) await _refresh();
  }

  Future<void> _showHistory(VaconDevice device) async {
    try {
      final readings = await _service.telemetryHistory(
        facilityId: widget.facilityId,
        deviceId: device.id,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.6,
          child: readings.isEmpty
              ? Center(child: Text(sheetContext.l10n.vaconDataUnavailable))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: readings.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final reading = readings[index];
                    return ListTile(
                      title: Text(reading.actualHz == null
                          ? '—'
                          : '${reading.actualHz!.toStringAsFixed(2)} Hz'),
                      subtitle: Text(
                        DateFormat(
                          'dd.MM.yyyy HH:mm:ss',
                          LanguageScope.of(sheetContext).language.code,
                        ).format(reading.measuredAt.toLocal()),
                      ),
                      trailing: Text(reading.quality),
                    );
                  },
                ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.vaconBackendUnavailable)),
      );
    }
  }

  Future<void> _requestSimulation(
    VaconDevice device,
    String role,
    VaconCommandType command, {
    double? frequencyHz,
  }) async {
    if (_commandBusy || !_service.isSimulator) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.vaconSimulationBadge),
        content: Text(context.l10n.vaconPhysicalControlLocked),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.vaconConfirmSimulation),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _commandBusy = true);
    try {
      final result = await _service.requestSimulation(
        access: VaconAccessContext(
          facilityId: widget.facilityId,
          canRead: const ['admin', 'ansatt', 'leser'].contains(role),
          canControl: role == 'admin',
          hasEntitlement:
              _service.entitlementForFacility(widget.facilityId).enabled,
        ),
        deviceId: device.id,
        command: command,
        frequencyHz: frequencyHz,
      );
      if (!mounted) return;
      if (result.isVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.vaconCommandVerified)),
        );
      } else {
        if (kDebugMode) debugPrint('VACON simulator blocked: ${result.reason}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.vaconCommandBlocked)),
        );
      }
    } finally {
      if (mounted) setState(() => _commandBusy = false);
    }
  }

  Future<void> _askFrequency(VaconDevice device, String role) async {
    final controller = TextEditingController(
      text: device.telemetry.referenceHz?.toStringAsFixed(1) ?? '',
    );
    final input = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.vaconSimulationFrequency),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Hz',
            helperText: '${device.minHz.toStringAsFixed(1)}–'
                '${device.maxHz.toStringAsFixed(1)} Hz',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(context.l10n.vaconConfirmSimulation),
          ),
        ],
      ),
    );
    controller.dispose();
    if (input == null) return;
    final hz = double.tryParse(input.replaceAll(',', '.'));
    if (hz == null || hz < device.minHz || hz > device.maxHz) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.vaconCommandBlocked)),
        );
      }
      return;
    }
    await _requestSimulation(
      device,
      role,
      VaconCommandType.setFrequency,
      frequencyHz: hz,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.vaconControlName),
          actions: [
            IconButton(
              tooltip: context.l10n.refresh,
              onPressed: _refreshing ? null : _refresh,
              icon: _refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_outlined),
            ),
          ],
        ),
        body: FutureBuilder<String>(
          future: _roleFuture,
          builder: (context, roleSnapshot) {
            if (!roleSnapshot.hasData || _loading) {
              return const Center(child: CircularProgressIndicator());
            }
            final role = roleSnapshot.data!;
            final entitlement =
                _service.entitlementForFacility(widget.facilityId);
            final devices = _service.devicesForFacility(widget.facilityId);
            final error = _service.errorForFacility(widget.facilityId);
            final canManage = role == 'admin' && entitlement.enabled;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.vaconControlName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.vaconControlDescription,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      _SafetyBanner(
                        entitled: entitlement.enabled,
                        simulator: _service.isSimulator,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        const _ErrorBanner(),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.vaconDevices,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (canManage)
                            FilledButton.icon(
                              key: const ValueKey('vacon-add-device'),
                              onPressed: () => _openSetup(),
                              icon: const Icon(Icons.add),
                              label: Text(context.l10n.vaconAddDevice),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (devices.isEmpty)
                        _EmptyDevices()
                      else
                        ...devices.map(
                          (device) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _DeviceCard(
                              device: device,
                              simulator: _service.isSimulator,
                              canManage: canManage,
                              canControl: canManage,
                              busy: _commandBusy,
                              onCommand: (command) =>
                                  _requestSimulation(device, role, command),
                              onFrequency: () => _askFrequency(device, role),
                              onSetup: () => _openSetup(device: device),
                              onHistory: () => _showHistory(device),
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

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.entitled, required this.simulator});

  final bool entitled;
  final bool simulator;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF2D58A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFF9A6700)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    simulator
                        ? context.l10n.vaconSimulationBadge
                        : context.l10n.vaconMonitoringBadge,
                    style: const TextStyle(
                      color: Color(0xFF624600),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    simulator
                        ? context.l10n.vaconPhysicalControlLocked
                        : context.l10n.vaconReadOnlyMonitoring,
                    style: const TextStyle(color: Color(0xFF624600)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entitled
                        ? context.l10n.vaconEntitlementActive
                        : context.l10n.vaconEntitlementInactive,
                    style: const TextStyle(
                      color: Color(0xFF624600),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E5),
          border: Border.all(color: const Color(0xFFF2D58A)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF9A6700)),
            const SizedBox(width: 10),
            Expanded(child: Text(context.l10n.vaconBackendUnavailable)),
          ],
        ),
      );
}

class _EmptyDevices extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(context.l10n.vaconNoDevices),
        ),
      );
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.simulator,
    required this.canManage,
    required this.canControl,
    required this.busy,
    required this.onCommand,
    required this.onFrequency,
    required this.onSetup,
    required this.onHistory,
  });

  final VaconDevice device;
  final bool simulator;
  final bool canManage;
  final bool canControl;
  final bool busy;
  final ValueChanged<VaconCommandType> onCommand;
  final VoidCallback onFrequency;
  final VoidCallback onSetup;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fresh = device.connection == VaconConnectionState.online &&
        device.telemetry.isFreshAt(DateTime.now());
    final status = fresh
        ? (device.telemetry.running ? l10n.vaconRunning : l10n.vaconStopped)
        : _connectionLabel(context, device.connection);
    final controlAvailable = simulator &&
        canControl &&
        device.canSimulateControlAt(DateTime.now()) &&
        !busy;
    final hasTelemetry = device.telemetry.measuredAt.year > 1970;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                _StatusChip(label: status, color: _statusColor(fresh)),
                _StatusChip(
                  label: simulator
                      ? l10n.vaconSimulationBadge
                      : l10n.vaconMonitoringBadge,
                  color: const Color(0xFF0B63E5),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 24,
              runSpacing: 14,
              children: [
                _Detail(
                  label: l10n.vaconModelProfile,
                  value: device.modelProfile.name,
                ),
                _Detail(
                  label: l10n.vaconGatewayEndpoint,
                  value: '${device.endpointLabel}:${device.port}',
                ),
                _Detail(label: l10n.vaconUnitId, value: '${device.unitId}'),
                _Detail(
                  label: l10n.vaconLastMeasurement,
                  value: hasTelemetry
                      ? _format(context, device.telemetry.measuredAt)
                      : '—',
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              l10n.vaconTelemetry,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 24,
              runSpacing: 14,
              children: [
                _Detail(
                  label: l10n.vaconActualFrequency,
                  value: _value(device.telemetry.actualHz, 'Hz'),
                ),
                _Detail(
                  label: l10n.vaconMotorSpeed,
                  value: device.telemetry.motorSpeedVerified
                      ? _value(device.telemetry.motorSpeedRpm, 'RPM')
                      : l10n.vaconUnverified,
                ),
                _Detail(
                  label: l10n.vaconMotorCurrent,
                  value: device.telemetry.motorCurrentVerified
                      ? _value(device.telemetry.currentA, 'A')
                      : l10n.vaconUnverified,
                ),
                _Detail(
                  label: l10n.vaconControlState,
                  value: device.telemetry.statusText ?? '—',
                ),
                _Detail(
                  label: l10n.vaconFault,
                  value: device.telemetry.faultCode ?? '—',
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('vacon-history-${device.id}'),
                  onPressed: onHistory,
                  icon: const Icon(Icons.history_outlined),
                  label: Text(l10n.vaconHistory),
                ),
                OutlinedButton.icon(
                  key: ValueKey('vacon-setup-${device.id}'),
                  onPressed: canManage ? onSetup : null,
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(l10n.vaconSetup),
                ),
                if (simulator) ...[
                  OutlinedButton.icon(
                    key: ValueKey('vacon-start-${device.id}'),
                    onPressed: controlAvailable
                        ? () => onCommand(VaconCommandType.start)
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.vaconSimulationStart),
                  ),
                  OutlinedButton.icon(
                    key: ValueKey('vacon-stop-${device.id}'),
                    onPressed: controlAvailable
                        ? () => onCommand(VaconCommandType.stop)
                        : null,
                    icon: const Icon(Icons.stop_outlined),
                    label: Text(l10n.vaconSimulationStop),
                  ),
                  OutlinedButton.icon(
                    key: ValueKey('vacon-frequency-${device.id}'),
                    onPressed: controlAvailable ? onFrequency : null,
                    icon: const Icon(Icons.speed_outlined),
                    label: Text(l10n.vaconSimulationFrequency),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.vaconReadOnlySetup,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _connectionLabel(BuildContext context, VaconConnectionState state) =>
      switch (state) {
        VaconConnectionState.stale => context.l10n.collectorStale,
        VaconConnectionState.offline => context.l10n.collectorOffline,
        VaconConnectionState.disabled => context.l10n.vaconControlDisabled,
        VaconConnectionState.online => context.l10n.vaconDataUnavailable,
      };

  Color _statusColor(bool fresh) =>
      fresh ? const Color(0xFF15803D) : const Color(0xFF9A6700);

  String _format(BuildContext context, DateTime value) => DateFormat(
        'dd.MM HH:mm:ss',
        LanguageScope.of(context).language.code,
      ).format(value.toLocal());

  String _value(double? value, String unit) =>
      value == null ? '—' : '${value.toStringAsFixed(1)} $unit';
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
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
              value,
              maxLines: 2,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
