import 'dart:async';

import 'package:flutter/material.dart';

import '../models/vacon_pump.dart';
import '../services/user_service.dart';
import '../services/vacon_pump_service.dart';

/// Add-ons > VACON Control. The UI is intentionally fail-closed until a gateway is
/// commissioned. All values are telemetry, not optimistic command state.
class VaconPumpScreen extends StatefulWidget {
  const VaconPumpScreen({super.key, required this.facilityId});
  final String facilityId;

  @override
  State<VaconPumpScreen> createState() => _VaconPumpScreenState();
}

class _VaconPumpScreenState extends State<VaconPumpScreen> {
  late final VaconPumpService _service;
  late final Future<bool> _isAdmin;
  Timer? _freshnessTicker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = VaconPumpService(widget.facilityId);
    _isAdmin = UserService.getCurrentUserRole().then((role) => role == 'admin');
    _freshnessTicker = Timer.periodic(
      const Duration(seconds: 5),
      (_) { if (mounted) setState(() {}); },
    );
  }

  @override
  void dispose() {
    _freshnessTicker?.cancel();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _addPump() async {
    final name = TextEditingController();
    final ip = TextEditingController();
    final port = TextEditingController(text: '502');
    final values = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Legg til VACON-pumpe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Navn')),
            TextField(controller: ip, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'IP i VPN-nettet')),
            TextField(controller: port, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Modbus TCP-port')),
            const SizedBox(height: 12),
            const Text('Pumpen opprettes som INAKTIV. Fjernstyring kan bare '
                'aktiveres av en kontrollert idriftsettelsesprosess.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, [name.text, ip.text, port.text]),
            child: const Text('Legg til'),
          ),
        ],
      ),
    );
    name.dispose();
    ip.dispose();
    port.dispose();
    if (values == null) return;
    try {
      await _service.addPump(
        name: values[0],
        ip: values[1],
        port: int.parse(values[2]),
      );
      _message('Pumpen er registrert, men ikke aktivert.');
    } catch (error) {
      _message('Kunne ikke legge til pumpe: ' + error.toString());
    }
  }

  Future<void> _sendCommand(
    VaconPump pump,
    VaconCommand command, {
    double? hz,
  }) async {
    if (_busy || !pump.canRequestControl) return;
    final description = switch (command) {
      VaconCommand.start => 'START',
      VaconCommand.stop => 'STOPP',
      VaconCommand.setFrequency => 'SETT FREKVENS til ' + hz.toString() + ' Hz',
      VaconCommand.faultReset => 'KVITTER FEIL',
    };
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bekreft fjernkommando'),
        content: Text(description + ' – ' + pump.name +
            '\n\nDette er en fjernkommando til fysisk utstyr. '
            'Kontroller at det er trygt og at lokalt personell er informert.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Avbryt')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send forespørsel')),
        ],
      ),
    );
    if (accepted != true) return;
    setState(() => _busy = true);
    try {
      await _service.requestCommand(pump, command, frequencyHz: hz);
      _message('Forespørsel sendt. Kontroller bekreftet status fra pumpen.');
    } catch (error) {
      _message('Kommandoen ble ikke sendt: ' + error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _askFrequency(VaconPump pump) async {
    final input = TextEditingController(
      text: pump.setpointHz?.toStringAsFixed(1) ??
          pump.actualHz?.toStringAsFixed(1) ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ny frekvensreferanse'),
        content: TextField(
          controller: input,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Hz',
            helperText: 'Tillatt område: ' +
                pump.minHz.toString() + '–' + pump.maxHz.toString() + ' Hz',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Avbryt')),
          FilledButton(onPressed: () => Navigator.pop(ctx, input.text),
              child: const Text('Neste')),
        ],
      ),
    );
    input.dispose();
    if (result == null) return;
    final hz = double.tryParse(result.replaceAll(',', '.'));
    if (hz == null || !hz.isFinite ||
        hz < pump.minHz || hz > pump.maxHz) {
      _message('Ugyldig frekvens.');
      return;
    }
    await _sendCommand(pump, VaconCommand.setFrequency, hz: hz);
  }

  Widget _metric(String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 22, bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _pumpCard(VaconPump pump, bool admin) {
    final online = pump.connection == 'online' && pump.isFresh;
    final canControl = admin && pump.canRequestControl && !_busy;
    String hz(double? value) => value == null ? '–' : value.toStringAsFixed(1) + ' Hz';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(pump.name,
              style: Theme.of(context).textTheme.titleLarge)),
            Chip(label: Text(online ? (pump.running ? 'I drift' : 'Stoppet')
                : 'Frakoblet / utdaterte data')),
          ]),
          Text(pump.model + ' · ' + pump.ip + ':' + pump.port.toString()),
          if (!pump.commissioned)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Venter på idriftsettelse – fjernstyring deaktivert.',
                style: TextStyle(color: Colors.deepOrange)),
            ),
          const SizedBox(height: 12),
          Wrap(children: [
            _metric('Faktisk frekvens', online ? hz(pump.actualHz) : '–'),
            _metric('Referanse', online ? hz(pump.setpointHz) : '–'),
            _metric('Motorstrøm', online && pump.motorCurrentA != null
                ? pump.motorCurrentA!.toStringAsFixed(1) + ' A' : '–'),
            _metric('Effekt', online && pump.motorPowerKw != null
                ? pump.motorPowerKw!.toStringAsFixed(1) + ' kW' : '–'),
            _metric('Feilkode', online ? (pump.faultCode?.toString() ?? '–') : '–'),
          ]),
          const Divider(),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: canControl ? () => _sendCommand(pump, VaconCommand.start) : null,
              icon: const Icon(Icons.play_arrow), label: const Text('Start'),
            ),
            OutlinedButton.icon(
              onPressed: canControl ? () => _sendCommand(pump, VaconCommand.stop) : null,
              icon: const Icon(Icons.stop), label: const Text('Stopp'),
            ),
            OutlinedButton.icon(
              onPressed: canControl ? () => _askFrequency(pump) : null,
              icon: const Icon(Icons.speed), label: const Text('Endre Hz'),
            ),
            OutlinedButton.icon(
              onPressed: canControl ? () => _sendCommand(pump, VaconCommand.faultReset) : null,
              icon: const Icon(Icons.restart_alt), label: const Text('Kvitter feil'),
            ),
          ]),
          const SizedBox(height: 8),
          const Text('Kommandoer blir først utført når en godkjent gateway '
              'har kontrollert sikkerhet, TTL og lokal styring.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add-ons / VACON Control')),
      floatingActionButton: FutureBuilder<bool>(
        future: _isAdmin,
        builder: (context, snap) => snap.data == true
            ? FloatingActionButton.extended(
                onPressed: _addPump,
                icon: const Icon(Icons.add),
                label: const Text('Legg til pumpe'),
              )
            : const SizedBox.shrink(),
      ),
      body: FutureBuilder<bool>(
        future: _isAdmin,
        builder: (context, role) {
          if (!role.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<List<VaconPump>>(
            stream: _service.watchPumps(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(
                child: Text('Kan ikke lese pumper: ' + snapshot.error.toString()));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final pumps = snapshot.data!;
              if (pumps.isEmpty) return const Center(
                child: Text('Ingen VACON-pumper registrert ennå.'));
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  for (final pump in pumps) _pumpCard(pump, role.data == true),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
