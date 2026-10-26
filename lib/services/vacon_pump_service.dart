import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/vacon_pump.dart';
import 'user_service.dart';

enum VaconCommand { start, stop, setFrequency, faultReset }

class VaconPumpService {
  VaconPumpService(this.facilityId);

  final String facilityId;

  CollectionReference<Map<String, dynamic>> get _pumps => FirebaseFirestore
      .instance.collection('facilities').doc(facilityId)
      .collection('vaconPumps');

  CollectionReference<Map<String, dynamic>> get _commands => FirebaseFirestore
      .instance.collection('facilities').doc(facilityId)
      .collection('vaconPumpCommands');

  Stream<List<VaconPump>> watchPumps() => _pumps.snapshots().map(
        (snapshot) => snapshot.docs.map(VaconPump.fromDoc).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
      );

  Future<void> addPump({required String name, required String ip, int port = 502}) async {
    if (await UserService.getCurrentUserRole() != 'admin') {
      throw StateError('Bare administrator kan legge til pumper.');
    }
    final parts = ip.split('.');
    if (parts.length != 4 ||
        parts.any((part) => int.tryParse(part) == null ||
          int.parse(part) < 0 || int.parse(part) > 255) ||
        port < 1 || port > 65535) {
      throw ArgumentError('Ugyldig IP-adresse eller port.');
    }
    await _pumps.add({
      'name': name.trim(),
      'ip': ip,
      'port': port,
      'model': 'Ukjent',
      'minHz': 0.0,
      'maxHz': 50.0,
      'commissioned': false,
      'remoteControlEnabled': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Queues an intent only. The trusted VPN gateway MUST independently
  /// re-authorize, validate live interlocks, enforce TTL/rate limits, write
  /// Modbus and verify readback before marking a command as executed.
  Future<void> requestCommand(
    VaconPump pump,
    VaconCommand command, {
    double? frequencyHz,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || await UserService.getCurrentUserRole() != 'admin') {
      throw StateError('Du mangler tillatelse til fjernstyring.');
    }

    // A server read is mandatory; never authorize against offline cache.
    final latestDoc = await _pumps.doc(pump.id).get(
          const GetOptions(source: Source.server),
        );
    if (!latestDoc.exists) throw StateError('Pumpen finnes ikke.');
    final current = VaconPump.fromDoc(latestDoc);
    if (!current.canRequestControl) {
      throw StateError('Pumpen er ikke klargjort eller gir ikke ferske data.');
    }
    if (command == VaconCommand.setFrequency &&
        (frequencyHz == null ||
            !frequencyHz.isFinite ||
            frequencyHz < current.minHz ||
            frequencyHz > current.maxHz)) {
      throw ArgumentError('Frekvensen er utenfor tillatt område.');
    }
    if (command != VaconCommand.setFrequency && frequencyHz != null) {
      throw ArgumentError('Denne kommandoen skal ikke ha en frekvensverdi.');
    }

    await _commands.add({
      'pumpId': current.id,
      'type': command.name,
      'value': frequencyHz,
      'status': 'queued',
      'requestedByUid': user.uid,
      'requestedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(seconds: 15)),
      ),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCommands(String pumpId) {
    return _commands.where('pumpId', isEqualTo: pumpId).snapshots();
  }
}
