import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MoveFishScreen extends StatefulWidget {
  final String facilityId;
  final String fromSectionId;
  final String fromTankId;
  final String fromTankName;
  final int fromFishCount;

  const MoveFishScreen({
    super.key,
    required this.facilityId,
    required this.fromSectionId,
    required this.fromTankId,
    required this.fromTankName,
    required this.fromFishCount,
  });

  @override
  State<MoveFishScreen> createState() => _MoveFishScreenState();
}

class _MoveFishScreenState extends State<MoveFishScreen> {
  final amountCtrl = TextEditingController();

  String? selectedTankPath;
  String? selectedTankName;

  @override
  void dispose() {
    amountCtrl.dispose();
    super.dispose();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadAllTanks() async {
    final db = FirebaseFirestore.instance;

    final sectionsSnap = await db
        .collection('facilities')
        .doc(widget.facilityId)
        .collection('sections')
        .get();

    final allTanks = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final section in sectionsSnap.docs) {
      final tanksSnap = await section.reference
          .collection('tanks')
          .orderBy('createdAt')
          .get();

      for (final tank in tanksSnap.docs) {
        if (tank.id != widget.fromTankId) {
          allTanks.add(tank);
        }
      }
    }

    return allTanks;
  }

  Future<void> _moveFish() async {
    final amount = int.tryParse(amountCtrl.text) ?? 0;

    if (amount <= 0 || selectedTankPath == null) return;

    final db = FirebaseFirestore.instance;

    final fromRef = db
        .collection('facilities')
        .doc(widget.facilityId)
        .collection('sections')
        .doc(widget.fromSectionId)
        .collection('tanks')
        .doc(widget.fromTankId);

    final toRef = db.doc(selectedTankPath!);

    await db.runTransaction((transaction) async {
      final fromSnap = await transaction.get(fromRef);
      final toSnap = await transaction.get(toRef);

      final fromData = fromSnap.data() ?? {};
      final toData = toSnap.data() ?? {};

      final fromRaw = fromData['fishCount'] ?? 0;
      final toRaw = toData['fishCount'] ?? 0;

      final fromCount =
          fromRaw is int ? fromRaw : int.tryParse(fromRaw.toString()) ?? 0;
      final toCount =
          toRaw is int ? toRaw : int.tryParse(toRaw.toString()) ?? 0;

      if (amount > fromCount) {
        throw Exception('Ikke nok fisk i karet');
      }

      transaction.update(fromRef, {
        'fishCount': fromCount - amount,
      });

      transaction.update(toRef, {
        'fishCount': toCount + amount,
      });

      transaction.set(fromRef.collection('logs').doc(), {
        'date': Timestamp.now(),
        'mortality': 0,
        'feedKg': 0,
        'avgWeight': 0,
        'temperature': 0,
        'transferOut': amount,
        'note': 'Flyttet $amount fisk til ${selectedTankName ?? 'ukjent kar'}',
      });

      transaction.set(toRef.collection('logs').doc(), {
        'date': Timestamp.now(),
        'mortality': 0,
        'feedKg': 0,
        'avgWeight': 0,
        'temperature': 0,
        'transferIn': amount,
        'note': 'Mottok $amount fisk fra ${widget.fromTankName}',
      });
    });

    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flytt fisk'),
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: _loadAllTanks(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Feil: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tanks = snapshot.data!;

          if (tanks.isEmpty) {
            return const Center(
              child: Text('Ingen andre kar å flytte til'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Fra kar'),
                  subtitle: Text(widget.fromTankName),
                  trailing: Text('${widget.fromFishCount} fisk'),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedTankPath,
                decoration: const InputDecoration(
                  labelText: 'Flytt til kar',
                ),
                items: tanks.map((doc) {
                  final data = doc.data();
                  final name = (data['name'] ?? 'Ukjent kar').toString();
                  final rawCount = data['fishCount'] ?? 0;
                  final count = rawCount is int
                      ? rawCount
                      : int.tryParse(rawCount.toString()) ?? 0;

                  return DropdownMenuItem(
                    value: doc.reference.path,
                    child: Text('$name ($count fisk)'),
                    onTap: () {
                      selectedTankName = name;
                    },
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTankPath = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Antall fisk som skal flyttes',
                  hintText: 'F.eks. 2000',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Flytt fisk'),
                onPressed: _moveFish,
              ),
            ],
          );
        },
      ),
    );
  }
}
