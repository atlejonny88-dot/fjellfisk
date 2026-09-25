import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/fish_transfer_service.dart';
import '../services/user_service.dart';
import '../services/web_update_guard.dart';
import '../utils/data_values.dart';

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

  bool _saving = false;
  bool _completed = false;
  String? _transferId;
  late final _tanksFuture = _loadAllTanks();
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
        if (tank.id != widget.fromTankId ||
            section.id != widget.fromSectionId) {
          allTanks.add(tank);
        }
      }
    }

    return allTanks;
  }

  Future<void> _moveFish() async {
    if (_saving || _completed) return;
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0 || selectedTankPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Velg mottakerkar og et antall større enn null.')));
      return;
    }
    setState(() => _saving = true);
    setWebSavePending(true);
    try {
      final role = await UserService.getCurrentUserRole();
      if (role != 'admin' && role != 'ansatt') {
        throw const FormatException('Du har ikke skrivetilgang.');
      }
      final db = FirebaseFirestore.instance;
      final from = db
          .collection('facilities')
          .doc(widget.facilityId)
          .collection('sections')
          .doc(widget.fromSectionId)
          .collection('tanks')
          .doc(widget.fromTankId);
      _transferId ??= from.collection('logs').doc().id;
      await FishTransferService.move(
          from: from,
          to: db.doc(selectedTankPath!),
          amount: amount,
          transferId: _transferId!);
      _completed = true;
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
    } catch (error, stack) {
      debugPrint('Flytting feilet: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is FormatException
                ? error.message
                : 'Kunne ikke flytte fisk. Prøv igjen.')));
      }
    } finally {
      setWebSavePending(false);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !_saving || _completed,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Flytt fisk'),
          ),
          body:
              FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            future: _tanksFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Kar for flytting: ${snapshot.error}');
                return const Center(
                    child: Text('Kunne ikke hente kar. Prøv igjen.'));
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

              return AbsorbPointer(
                  absorbing: _saving || _completed,
                  child: ListView(
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
                          final name =
                              (data['name'] ?? 'Ukjent kar').toString();
                          final count = DataValues.integer(data['fishCount']);

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
                        onPressed: _saving || _completed ? null : _moveFish,
                      ),
                    ],
                  ));
            },
          ),
        ));
  }
}
