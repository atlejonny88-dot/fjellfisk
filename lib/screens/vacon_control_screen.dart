import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/language_controller.dart';
import '../l10n/localizations.dart';
import '../models/vacon_control.dart';
import '../services/user_service.dart';
import '../services/vacon_control_service.dart';
import '../theme/app_theme.dart';

/// Add-ons > VACON Control.
///
/// This V4 surface is intentionally simulator-only. It neither opens a socket
/// nor has access to Modbus registers, a VPN, credentials or a real gateway.
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

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MockVaconControlService.shared;
    _roleFuture = (widget.roleLoader ?? UserService.getCurrentUserRole)();
    _service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _requestSimulation(
    VaconDevice device,
    String role,
    VaconCommandType command, {
    double? frequencyHz,
  }) async {
    if (_commandBusy) return;
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

    final entitlement = _service.entitlementForFacility(widget.facilityId);
    setState(() => _commandBusy = true);
    try {
      final result = await _service.requestSimulation(
        access: VaconAccessContext(
          facilityId: widget.facilityId,
          canRead: role == 'admin' || role == 'ansatt' || role == 'leser',
          canControl: role == 'admin',
          hasEntitlement: entitlement.enabled,
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.vaconCommandBlocked)),
      );
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.vaconControlName)),
      body: FutureBuilder<String>(
        future: _roleFuture,
        builder: (context, roleSnapshot) {
          if (!roleSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final role = roleSnapshot.data!;
          final entitlement =
              _service.entitlementForFacility(widget.facilityId);
          final sites = _service.sitesForFacility(widget.facilityId);
          final devices = _service.devicesForFacility(widget.facilityId);
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
                    _SafetyBanner(entitled: entitlement.enabled),
                    const SizedBox(height: 22),
                    Text(
                      context.l10n.vaconDevices,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
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
                            site: _siteFor(sites, device.siteId),
                            canControl: role == 'admin' && entitlement.enabled,
                            busy: _commandBusy,
                            onCommand: (command) =>
                                _requestSimulation(device, role, command),
                            onFrequency: () => _askFrequency(device, role),
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

  VaconSite? _siteFor(List<VaconSite> sites, String id) {
    for (final site in sites) {
      if (site.id == id) return site;
    }
    return null;
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.entitled});

  final bool entitled;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  context.l10n.vaconSimulationBadge,
                  style: const TextStyle(
                    color: Color(0xFF624600),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.vaconPhysicalControlLocked,
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
    required this.site,
    required this.canControl,
    required this.busy,
    required this.onCommand,
    required this.onFrequency,
  });

  final VaconDevice device;
  final VaconSite? site;
  final bool canControl;
  final bool busy;
  final ValueChanged<VaconCommandType> onCommand;
  final VoidCallback onFrequency;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final controlAvailable =
        canControl && device.canSimulateControlAt(now) && !busy;
    final locale = LanguageScope.of(context).language.code;
    final timestamp = DateFormat('dd.MM HH:mm:ss', locale)
        .format(device.telemetry.measuredAt.toLocal());
    final status = device.connection == VaconConnectionState.online &&
            device.telemetry.isFreshAt(now)
        ? (device.telemetry.running ? l10n.vaconRunning : l10n.vaconStopped)
        : l10n.vaconControlDisabled;
    final statusColor = device.connection == VaconConnectionState.online &&
            device.telemetry.isFreshAt(now)
        ? const Color(0xFF15803D)
        : const Color(0xFF9A6700);

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
                _StatusChip(label: status, color: statusColor),
                _StatusChip(
                  label: device.controlMode == VaconControlMode.simulationOnly
                      ? l10n.vaconSimulationBadge
                      : l10n.vaconControlDisabled,
                  color: const Color(0xFF0B63E5),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 24,
              runSpacing: 14,
              children: [
                _Detail(label: l10n.vaconSite, value: site?.name ?? '—'),
                _Detail(
                    label: l10n.vaconModelProfile,
                    value: device.modelProfile.name),
                _Detail(
                  label: l10n.vaconGatewayEndpoint,
                  value: '${device.endpointLabel}:${device.port}',
                ),
                _Detail(label: l10n.vaconUnitId, value: '${device.unitId}'),
                _Detail(
                  label: l10n.vaconPolling,
                  value: '${device.pollingInterval.inSeconds} s',
                ),
                _Detail(label: l10n.vaconLastMeasurement, value: timestamp),
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
                  label: l10n.vaconReferenceFrequency,
                  value: _value(device.telemetry.referenceHz, 'Hz'),
                ),
                _Detail(
                  label: l10n.vaconMotorCurrent,
                  value: _value(device.telemetry.currentA, 'A'),
                ),
                _Detail(
                  label: l10n.vaconMotorPower,
                  value: _value(device.telemetry.powerKw, 'kW'),
                ),
                _Detail(
                  label: l10n.vaconControlState,
                  value: device.telemetry.statusText ?? '—',
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
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
                OutlinedButton.icon(
                  key: ValueKey('vacon-reset-${device.id}'),
                  onPressed: controlAvailable
                      ? () => onCommand(VaconCommandType.faultReset)
                      : null,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(l10n.vaconSimulationReset),
                ),
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
