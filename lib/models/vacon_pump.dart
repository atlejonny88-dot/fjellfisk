import 'package:cloud_firestore/cloud_firestore.dart';

/// Snapshot produced by a trusted, always-on gateway. Never infer RUNNING
/// from a successful command submission.
class VaconPump {
  const VaconPump({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.model,
    required this.commissioned,
    required this.remoteControlEnabled,
    required this.running,
    required this.connection,
    required this.measuredAt,
    required this.actualHz,
    required this.setpointHz,
    required this.motorCurrentA,
    required this.motorPowerKw,
    required this.faultCode,
    required this.minHz,
    required this.maxHz,
  });

  final String id;
  final String name;
  final String ip;
  final int port;
  final String model;
  final bool commissioned;
  final bool remoteControlEnabled;
  final bool running;
  final String connection;
  final DateTime? measuredAt;
  final double? actualHz;
  final double? setpointHz;
  final double? motorCurrentA;
  final double? motorPowerKw;
  final int? faultCode;
  final double minHz;
  final double maxHz;

  bool get isFresh {
    final date = measuredAt;
    if (date == null) return false;
    final age = DateTime.now().difference(date);
    return age >= Duration.zero && age < const Duration(seconds: 20);
  }

  bool get canRequestControl =>
      commissioned && remoteControlEnabled && connection == 'online' && isFresh;

  static double? _number(dynamic v) => v is num ? v.toDouble() : null;

  factory VaconPump.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final rawDate = d['measuredAt'];
    return VaconPump(
      id: doc.id,
      name: (d['name'] ?? doc.id).toString(),
      ip: (d['ip'] ?? '').toString(),
      port: d['port'] is int ? d['port'] as int : 502,
      model: (d['model'] ?? 'Ukjent modell').toString(),
      commissioned: d['commissioned'] == true,
      remoteControlEnabled: d['remoteControlEnabled'] == true,
      running: d['running'] == true,
      connection: (d['connection'] ?? 'offline').toString(),
      measuredAt: rawDate is Timestamp ? rawDate.toDate() : null,
      actualHz: _number(d['actualHz']),
      setpointHz: _number(d['setpointHz']),
      motorCurrentA: _number(d['motorCurrentA']),
      motorPowerKw: _number(d['motorPowerKw']),
      faultCode: d['faultCode'] is int ? d['faultCode'] as int : null,
      minHz: _number(d['minHz']) ?? 0,
      maxHz: _number(d['maxHz']) ?? 50,
    );
  }
}
