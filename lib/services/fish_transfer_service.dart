import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/data_values.dart';

class FishTransferService {
  static Future<void> move({
    required DocumentReference<Map<String, dynamic>> from,
    required DocumentReference<Map<String, dynamic>> to,
    required int amount,
    required String transferId,
  }) async {
    if (amount <= 0 ||
        from.path == to.path ||
        from.path.split('/')[1] != to.path.split('/')[1]) {
      throw const FormatException(
          'Velg et annet kar og et gyldig antall fisk.');
    }
    final outLog = from.collection('logs').doc(transferId);
    final inLog = to.collection('logs').doc(transferId);
    await from.firestore.runTransaction((tx) async {
      final existing = await tx.get(outLog);
      if (existing.exists) return;
      final source = await tx.get(from);
      final destination = await tx.get(to);
      if (!source.exists || !destination.exists) {
        throw const FormatException('Et av karene finnes ikke lenger.');
      }
      final sourceCount = DataValues.integer(source.data()?['fishCount']);
      final targetCount = DataValues.integer(destination.data()?['fishCount']);
      if (amount > sourceCount || targetCount < 0) {
        throw const FormatException(
            'Kontroller fisketallet. Det er ikke nok fisk i karet.');
      }
      final common = <String, dynamic>{
        'date': Timestamp.now(),
        'mortality': 0,
        'feedKg': 0,
        'avgWeight': 0,
        'temperature': 0,
      };
      tx.update(from, {'fishCount': sourceCount - amount});
      tx.update(to, {'fishCount': targetCount + amount});
      tx.set(outLog, {
        ...common,
        'transferOut': amount,
        'note':
            'Flyttet $amount fisk til ${destination.data()?['name'] ?? to.id}'
      });
      tx.set(inLog, {
        ...common,
        'transferIn': amount,
        'note': 'Mottok $amount fisk fra ${source.data()?['name'] ?? from.id}'
      });
    });
  }
}
