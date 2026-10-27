import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/language_controller.dart';
import '../l10n/localizations.dart';
import '../models/addon.dart';
import '../services/addon_service.dart';
import '../services/collector_claim_service.dart';
import '../services/user_service.dart';
import '../utils/ui_motion.dart';
import 'collector_setup_screen.dart';

class AddOnsScreen extends StatefulWidget {
  const AddOnsScreen({
    super.key,
    this.service,
    this.claimService,
    this.roleLoader,
  });

  final AddOnService? service;
  final CollectorClaimService? claimService;
  final Future<String> Function()? roleLoader;

  @override
  State<AddOnsScreen> createState() => _AddOnsScreenState();
}

class _AddOnsScreenState extends State<AddOnsScreen> {
  late final AddOnService _service;
  late final CollectorClaimService _claimService;
  late final Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MockAddOnService.shared;
    _claimService =
        widget.claimService ?? CollectorClaimService.fromEnvironment();
    _roleFuture = (widget.roleLoader ?? UserService.getCurrentUserRole)();
    _service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    if (widget.claimService == null) _claimService.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openPairingDialog() async {
    final result = await showDialog<ClaimCodeResult>(
      context: context,
      builder: (_) => _CollectorPairingDialog(
        claim: _claimService.isConfigured
            ? (claimCode) => _claimService.claimCollector(
                  facilityId: widget.facilityId,
                  pairingCode: claimCode,
                )
            : _service.claimCollector,
      ),
    );
    if (!mounted || result?.isSuccess != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.collectorConnected)),
    );
  }

  Future<void> _confirmDisconnect(AddOn addOn) async {
    final shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.disconnectCollector),
        content: Text(context.l10n.disconnectCollectorDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.link_off_outlined),
            label: Text(context.l10n.disconnect),
          ),
        ],
      ),
    );
    if (shouldDisconnect != true) return;
    await _service.disconnect(addOn.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.collectorDisconnected)),
    );
  }

  void _openSetup(AddOn addOn) {
    if (!addOn.isConnected) return;
    Navigator.of(context).push(
      subtleFadeSlideRoute<void>(
        context: context,
        builder: (_) => CollectorSetupScreen(
          service: _service,
          collectorId: addOn.id,
          roleLoader: widget.roleLoader,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.addOns)),
      body: FutureBuilder<String>(
        future: _roleFuture,
        builder: (context, snapshot) {
          final canManage = snapshot.data == 'admin';
          return LayoutBuilder(
            builder: (context, constraints) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.addOns,
                        style: const TextStyle(
                          color: Color(0xFF0A1733),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.addOnsSubtitle,
                        style: const TextStyle(
                          color: Color(0xFF5F7088),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ..._service.addOns
                          .where((addOn) => addOn.type == AddOnType.collector)
                          .map(
                            (addOn) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _AddOnCard(
                                addOn: addOn,
                                canManage: canManage,
                                onConnect: _openPairingDialog,
                                onDisconnect: () => _confirmDisconnect(addOn),
                                onSetup: () => _openSetup(addOn),
                              ),
                            ),
                          ),
                    ],
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

class _AddOnCard extends StatelessWidget {
  const _AddOnCard({
    required this.addOn,
    required this.canManage,
    required this.onConnect,
    required this.onDisconnect,
    required this.onSetup,
  });

  final AddOn addOn;
  final bool canManage;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasConnectionDetails = addOn.status == AddOnStatus.connected ||
        addOn.status == AddOnStatus.offline ||
        addOn.status == AddOnStatus.error;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = hasConnectionDetails
                ? _ConnectionDetails(addOn: addOn)
                : const SizedBox.shrink();
            final actions = _actions(context);
            final header = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.sensors_outlined,
                    color: Color(0xFF0B63E5),
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.collectorAddOnName,
                        style: const TextStyle(
                          color: Color(0xFF0A1733),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.collectorAddOnDescription,
                        style: const TextStyle(
                          color: Color(0xFF5F7088),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusChip(status: addOn.status),
              ],
            );

            if (constraints.maxWidth < 640) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  if (hasConnectionDetails) ...[
                    const SizedBox(height: 18),
                    details,
                  ],
                  const SizedBox(height: 20),
                  actions,
                  if (!canManage) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.addOnsAdminOnly,
                      style: const TextStyle(color: Color(0xFF687A92)),
                    ),
                  ],
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                if (hasConnectionDetails) ...[
                  const SizedBox(height: 18),
                  details,
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    actions,
                    if (!canManage) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.addOnsAdminOnly,
                          style: const TextStyle(color: Color(0xFF687A92)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final setup = FilledButton.icon(
      key: ValueKey('collector-setup-${addOn.id}'),
      onPressed: canManage && addOn.isConnected ? onSetup : null,
      icon: const Icon(Icons.settings_outlined),
      label: Text(context.l10n.collectorSetupButton),
    );
    if (!canManage) return setup;

    final collectorAction = addOn.status == AddOnStatus.connected ||
            addOn.status == AddOnStatus.offline ||
            addOn.status == AddOnStatus.error
        ? OutlinedButton.icon(
            onPressed: onDisconnect,
            icon: const Icon(Icons.link_off_outlined),
            label: Text(context.l10n.disconnectCollector),
          )
        : FilledButton.icon(
            onPressed: onConnect,
            icon: const Icon(Icons.link_outlined),
            label: Text(context.l10n.connectCollector),
          );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [collectorAction, setup],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AddOnStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AddOnStatus.notConnected => (
          context.l10n.addOnStatusNotConnected,
          const Color(0xFF64748B),
        ),
      AddOnStatus.pending => (
          context.l10n.addOnStatusPending,
          const Color(0xFFB7791F),
        ),
      AddOnStatus.connected => (
          context.l10n.addOnStatusConnected,
          const Color(0xFF15803D),
        ),
      AddOnStatus.offline => (
          context.l10n.addOnStatusOffline,
          const Color(0xFFD97706),
        ),
      AddOnStatus.revoked => (
          context.l10n.addOnStatusRevoked,
          const Color(0xFF64748B),
        ),
      AddOnStatus.error => (
          context.l10n.addOnStatusError,
          const Color(0xFFB91C1C),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ConnectionDetails extends StatelessWidget {
  const _ConnectionDetails({required this.addOn});

  final AddOn addOn;

  @override
  Widget build(BuildContext context) {
    final items = [
      (context.l10n.collectorDevice, addOn.deviceName),
      (context.l10n.collectorReader, addOn.readerType),
      (context.l10n.collectorVersion, addOn.version),
      (
        context.l10n.collectorLastSeen,
        _formatDate(context, addOn.lastSeenAt),
      ),
      (
        context.l10n.collectorSensorCount,
        addOn.sensorCount == null
            ? null
            : context.l10n.sensorsCount(addOn.sensorCount!),
      ),
      (
        context.l10n.collectorLatestMeasurement,
        _formatDate(context, addOn.latestMeasurementAt),
      ),
    ].where((item) => item.$2 != null && item.$2!.trim().isNotEmpty).toList();

    return Wrap(
      spacing: 22,
      runSpacing: 14,
      children: items
          .map(
            (item) => SizedBox(
              width: 168,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.$1,
                    style: const TextStyle(
                      color: Color(0xFF687A92),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$2!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F3150),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  String? _formatDate(BuildContext context, DateTime? value) {
    if (value == null) return null;
    if (DateTime.now().difference(value).abs() < const Duration(minutes: 1)) {
      return context.l10n.justNow;
    }
    return DateFormat(
      'dd.MM.yyyy HH:mm',
      LanguageScope.of(context).language.code,
    ).format(value.toLocal());
  }
}

class _CollectorPairingDialog extends StatefulWidget {
  const _CollectorPairingDialog({required this.claim});

  final Future<ClaimCodeResult> Function(String claimCode) claim;

  @override
  State<_CollectorPairingDialog> createState() =>
      _CollectorPairingDialogState();
}

class _CollectorPairingDialogState extends State<_CollectorPairingDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final input = _controller.text;
    if (MockAddOnService.normalizeClaimCode(input).isEmpty) {
      setState(() => _error = context.l10n.connectionCodeRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.claim(input);
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.of(context).pop(result);
      return;
    }
    setState(() {
      _submitting = false;
      _error = _messageFor(result.type);
    });
  }

  String _messageFor(ClaimCodeResultType type) {
    return switch (type) {
      ClaimCodeResultType.invalid => context.l10n.connectionCodeInvalid,
      ClaimCodeResultType.expired => context.l10n.connectionCodeExpired,
      ClaimCodeResultType.alreadyUsed => context.l10n.connectionCodeAlreadyUsed,
      ClaimCodeResultType.busy => context.l10n.connectingCollector,
      ClaimCodeResultType.unauthorized =>
        context.l10n.collectorAuthorizationFailed,
      ClaimCodeResultType.unavailable =>
        context.l10n.collectorBackendUnavailable,
      ClaimCodeResultType.success => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.pairCollector),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.claimCodeSecurityMessage),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: context.l10n.connectionCode,
                hintText: 'FJ-8K4P-2XQ7',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link_outlined),
          label: Text(
            _submitting
                ? context.l10n.connectingCollector
                : context.l10n.connect,
          ),
        ),
      ],
    );
  }
}
