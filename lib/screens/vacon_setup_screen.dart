import 'package:flutter/material.dart';

import '../l10n/localizations.dart';
import '../models/vacon_control.dart';
import '../services/vacon_control_service.dart';
import '../theme/app_theme.dart';

class VaconSetupScreen extends StatefulWidget {
  const VaconSetupScreen({
    super.key,
    required this.facilityId,
    required this.service,
    this.device,
  });

  final String facilityId;
  final VaconControlService service;
  final VaconDevice? device;

  @override
  State<VaconSetupScreen> createState() => _VaconSetupScreenState();
}

class _VaconSetupScreenState extends State<VaconSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _manufacturer;
  late final TextEditingController _model;
  late final TextEditingController _ipAddress;
  late final TextEditingController _subnetMask;
  late final TextEditingController _gateway;
  late final TextEditingController _dns;
  late final TextEditingController _port;
  late final TextEditingController _unitId;
  late final TextEditingController _minHz;
  late final TextEditingController _maxHz;
  late final TextEditingController _edgeServer;
  late bool _monitoringEnabled;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final device = widget.device;
    _name = TextEditingController(text: device?.name ?? '');
    _manufacturer =
        TextEditingController(text: device?.manufacturer ?? 'Danfoss');
    _model = TextEditingController(
        text: device?.modelProfile.name ?? 'VACON 100 FLOW');
    _ipAddress = TextEditingController(text: device?.endpointLabel ?? '');
    _subnetMask =
        TextEditingController(text: device?.subnetMask ?? '255.255.255.0');
    _gateway = TextEditingController(text: device?.gateway ?? '');
    _dns = TextEditingController(text: device?.dns ?? '');
    _port = TextEditingController(text: '${device?.port ?? 502}');
    _unitId = TextEditingController(text: '${device?.unitId ?? 255}');
    _minHz = TextEditingController(text: '${device?.minHz ?? 0}');
    _maxHz = TextEditingController(text: '${device?.maxHz ?? 50}');
    _edgeServer = TextEditingController(text: device?.edgeServerId ?? '');
    _monitoringEnabled = device?.monitoringEnabled ?? true;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _manufacturer,
      _model,
      _ipAddress,
      _subnetMask,
      _gateway,
      _dns,
      _port,
      _unitId,
      _minHz,
      _maxHz,
      _edgeServer,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  VaconDeviceConfiguration? _configuration() {
    if (!_formKey.currentState!.validate()) return null;
    final port = int.tryParse(_port.text.trim());
    final unitId = int.tryParse(_unitId.text.trim());
    final minHz = double.tryParse(_minHz.text.trim().replaceAll(',', '.'));
    final maxHz = double.tryParse(_maxHz.text.trim().replaceAll(',', '.'));
    if (port == null ||
        unitId == null ||
        minHz == null ||
        maxHz == null ||
        maxHz <= minHz) {
      _showError();
      return null;
    }
    return VaconDeviceConfiguration(
      displayName: _name.text.trim(),
      manufacturer: _manufacturer.text.trim(),
      model: _model.text.trim(),
      ipAddress: _ipAddress.text.trim(),
      subnetMask: _subnetMask.text.trim(),
      gateway: _gateway.text.trim(),
      dns: _dns.text.trim(),
      modbusTcpPort: port,
      modbusUnitId: unitId,
      minFrequencyHz: minHz,
      maxFrequencyHz: maxHz,
      edgeServerId: _edgeServer.text.trim(),
      monitoringEnabled: _monitoringEnabled,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final configuration = _configuration();
    if (configuration == null) return;
    setState(() => _saving = true);
    try {
      await widget.service.saveDevice(
        facilityId: widget.facilityId,
        deviceId: widget.device?.id,
        configuration: configuration,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) _showError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    final device = widget.device;
    if (device == null || _testing) return;
    setState(() => _testing = true);
    try {
      await widget.service.testConnection(
        facilityId: widget.facilityId,
        deviceId: device.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.vaconConnectionTestUnavailable)),
      );
    } catch (_) {
      if (mounted) _showError();
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _showError() => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.vaconBackendUnavailable)),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vaconSetup)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Notice(text: l10n.vaconReadOnlyMonitoring),
                    const SizedBox(height: 20),
                    _Section(
                      title: l10n.vaconSetup,
                      children: [
                        _text(_name, l10n.vaconDeviceName),
                        _text(_manufacturer, l10n.vaconManufacturer),
                        _text(_model, l10n.vaconModel),
                        _text(_edgeServer, l10n.vaconEdgeServer),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.vaconMonitoringEnabled),
                          value: _monitoringEnabled,
                          onChanged: (value) => setState(
                            () => _monitoringEnabled = value,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: l10n.vaconConnection,
                      children: [
                        _text(_ipAddress, l10n.vaconIpAddress),
                        _text(_subnetMask, l10n.vaconSubnetMask),
                        _text(_gateway, l10n.vaconGateway),
                        _text(_dns, l10n.vaconDns),
                        _text(
                          _port,
                          l10n.vaconModbusPort,
                          keyboardType: TextInputType.number,
                        ),
                        _text(
                          _unitId,
                          l10n.vaconUnitId,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: l10n.vaconFrequencyLimits,
                      children: [
                        _text(
                          _minHz,
                          l10n.vaconMinimumFrequency,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                        _text(
                          _maxHz,
                          l10n.vaconMaximumFrequency,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(l10n.save),
                        ),
                        OutlinedButton.icon(
                          onPressed: widget.device == null || _testing
                              ? null
                              : _testConnection,
                          icon: const Icon(Icons.network_check_outlined),
                          label: Text(l10n.vaconTestConnection),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _text(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
          validator: (value) => value == null || value.trim().isEmpty
              ? context.l10n.vaconFieldRequired
              : null,
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: AppTheme.oceanBlue),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );
}
