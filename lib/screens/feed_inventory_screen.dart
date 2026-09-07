import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/user_service.dart';

class FeedInventoryScreen extends StatefulWidget {
  const FeedInventoryScreen({super.key});

  @override
  State<FeedInventoryScreen> createState() => _FeedInventoryScreenState();
}

class _FeedInventoryScreenState extends State<FeedInventoryScreen> {
  final _feedRef = FirebaseFirestore.instance.collection('feed_inventory');
  final _historyRef =
      FirebaseFirestore.instance.collection('feed_inventory_history');

  bool _canWrite(String role) {
    return role == 'admin' || role == 'ansatt';
  }

  Future<void> _ensureDefaultFeedTypes() async {
    final defaults = {
      'nutra_sprint_05': {
        'name': 'Skretting Nutra Sprint 0.5',
        'pelletSizeMm': 0.5,
        'bags': 0,
        'kgPerBag': 20,
      },
      'nutra_sprint_08': {
        'name': 'Skretting Nutra Sprint 0.8',
        'pelletSizeMm': 0.8,
        'bags': 0,
        'kgPerBag': 20,
      },
      'nutra_sprint_10': {
        'name': 'Skretting Nutra Sprint 1.0',
        'pelletSizeMm': 1.0,
        'bags': 0,
        'kgPerBag': 20,
      },
      'nutra_olympic_20': {
        'name': 'Skretting Nutra Olympic 2.0',
        'pelletSizeMm': 2.0,
        'bags': 0,
        'kgPerBag': 20,
      },
      'polarfeed_150': {
        'name': 'Polarfeed Laksens Valg 150',
        'pelletSizeMm': 1.5,
        'bags': 0,
        'kgPerBag': 25,
      },
      'polarfeed_300': {
        'name': 'Polarfeed Laksens Valg 300',
        'pelletSizeMm': 3.0,
        'bags': 0,
        'kgPerBag': 25,
      },
    };

    for (final entry in defaults.entries) {
      final doc = _feedRef.doc(entry.key);
      final snap = await doc.get();
      final now = Timestamp.now();

      if (!snap.exists) {
        final bags = entry.value['bags'] as int;
        final kgPerBag = entry.value['kgPerBag'] as int;
        await doc.set({
          ...entry.value,
          'stockKg': bags * kgPerBag,
          'active': true,
          'createdAt': now,
          'updatedAt': now,
        });
        continue;
      }

      final data = snap.data() ?? <String, dynamic>{};
      final updates = <String, dynamic>{};

      if (!data.containsKey('pelletSizeMm')) {
        updates['pelletSizeMm'] = entry.value['pelletSizeMm'];
      }
      if (!data.containsKey('active')) {
        updates['active'] = true;
      }
      if (!data.containsKey('stockKg')) {
        updates['stockKg'] = _toInt(data['bags']) * _toDouble(data['kgPerBag']);
      }
      if (!data.containsKey('createdAt')) {
        updates['createdAt'] = data['updatedAt'] is Timestamp
            ? data['updatedAt']
            : FieldValue.serverTimestamp();
      }
      if (updates.isNotEmpty) {
        updates['updatedAt'] = now;
        await doc.update(updates);
      }
    }
  }

  Future<void> _adjustBags({
    required String docId,
    required String name,
    required int currentBags,
  }) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Juster $name'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Antall sekker (+ / -)',
            hintText: 'F.eks. 10 eller -3',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          ElevatedButton(
            onPressed: () async {
              final change = int.tryParse(controller.text.trim()) ?? 0;
              if (change == 0) {
                Navigator.pop(context);
                return;
              }

              final newBags = currentBags + change;
              final finalBags = newBags < 0 ? 0 : newBags;
              final feedSnap = await _feedRef.doc(docId).get();
              final kgPerBag = _toDouble(feedSnap.data()?['kgPerBag']);
              final stockKgAfter = finalBags * kgPerBag;

              await _feedRef.doc(docId).update({
                'bags': finalBags,
                if (kgPerBag > 0) 'stockKg': stockKgAfter,
                'updatedAt': Timestamp.now(),
              });

              await _historyRef.add({
                'feedId': docId,
                'feedType': name,
                'change': change,
                'bagsBefore': currentBags,
                'bagsAfter': finalBags,
                if (kgPerBag > 0) 'stockKgAfter': stockKgAfter,
                'user': UserService.currentUser?.email ?? 'ukjent',
                'timestamp': Timestamp.now(),
              });

              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Lagre'),
          ),
        ],
      ),
    );
  }

  Future<void> _editKgPerBag({
    required String docId,
    required String name,
    required double currentKg,
  }) async {
    final controller = TextEditingController(
      text: currentKg.toStringAsFixed(0),
    );

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Kg per sekk - $name'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Kg per sekk',
            hintText: 'F.eks. 25',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          ElevatedButton(
            onPressed: () async {
              final kg = _parseDouble(controller.text) ?? currentKg;
              final safeKg = kg <= 0 ? currentKg : kg;

              await _feedRef.doc(docId).update({
                'kgPerBag': safeKg,
                'updatedAt': Timestamp.now(),
              });

              await _historyRef.add({
                'feedId': docId,
                'feedType': name,
                'change': 0,
                'bagsBefore': null,
                'bagsAfter': null,
                'kgPerBagBefore': currentKg,
                'kgPerBagAfter': safeKg,
                'user': UserService.currentUser?.email ?? 'ukjent',
                'timestamp': Timestamp.now(),
                'note': 'Endret kg per sekk',
              });

              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Lagre'),
          ),
        ],
      ),
    );
  }

  Future<void> _openFeedTypeDialog({
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    final isEditing = doc != null;
    final nameController = TextEditingController(
      text: (data['name'] ?? '').toString(),
    );
    final pelletController = TextEditingController(
      text: _toDouble(data['pelletSizeMm']) > 0
          ? _toDouble(data['pelletSizeMm']).toStringAsFixed(1)
          : '',
    );
    final kgController = TextEditingController(
      text: _toDouble(data['kgPerBag']) > 0
          ? _toDouble(data['kgPerBag']).toStringAsFixed(1)
          : '25',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEditing ? 'Endre fôrtype' : 'Ny fôrtype'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Navn',
                  hintText: 'F.eks. Nutra Olympic 3.0',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pelletController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Pelletstørrelse mm',
                  hintText: 'F.eks. 3.0',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kgController,
                enabled: !isEditing,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Kg per sekk',
                  hintText: 'F.eks. 25',
                  helperText: isEditing
                      ? 'Bruk blyanten på kortet for å endre kg per sekk.'
                      : null,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final pellet = _parseDouble(pelletController.text);
              final kgPerBag = _parseDouble(kgController.text) ?? 25;

              if (name.isEmpty || pellet == null || pellet <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Navn og pelletstørrelse må fylles ut.'),
                  ),
                );
                return;
              }

              final now = Timestamp.now();

              if (isEditing) {
                final beforeName = (data['name'] ?? doc.id).toString();
                final beforePellet = _toDouble(data['pelletSizeMm']);

                await doc.reference.update({
                  'name': name,
                  'pelletSizeMm': pellet,
                  'active': _toBool(data['active'], fallback: true),
                  'updatedAt': now,
                });

                await _historyRef.add({
                  'feedId': doc.id,
                  'feedType': beforeName,
                  'change': 0,
                  'user': UserService.currentUser?.email ?? 'ukjent',
                  'timestamp': now,
                  'note':
                      'Endret fôrtype: $beforeName (${_formatPellet(beforePellet)}) -> $name (${_formatPellet(pellet)})',
                });
              } else {
                final newDoc = _feedRef.doc();
                await newDoc.set({
                  'name': name,
                  'pelletSizeMm': pellet,
                  'active': true,
                  'bags': 0,
                  'kgPerBag': kgPerBag <= 0 ? 25 : kgPerBag,
                  'stockKg': 0,
                  'createdAt': now,
                  'updatedAt': now,
                });

                await _historyRef.add({
                  'feedId': newDoc.id,
                  'feedType': name,
                  'change': 0,
                  'user': UserService.currentUser?.email ?? 'ukjent',
                  'timestamp': now,
                  'note': 'La til ny fôrtype (${_formatPellet(pellet)})',
                });
              }

              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Lagre'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive({
    required String docId,
    required String name,
    required bool active,
    required double stockKg,
  }) async {
    final nextActive = !active;

    if (!nextActive && stockKg > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fôrtype med sekker på lager kan ikke deaktiveres.'),
        ),
      );
      return;
    }

    await _feedRef.doc(docId).update({
      'active': nextActive,
      'updatedAt': Timestamp.now(),
    });

    await _historyRef.add({
      'feedId': docId,
      'feedType': name,
      'change': 0,
      'user': UserService.currentUser?.email ?? 'ukjent',
      'timestamp': Timestamp.now(),
      'note': nextActive ? 'Aktiverte fôrtype' : 'Deaktiverte fôrtype',
    });
  }

  String _formatKg(double kg) {
    if (kg >= 1000) {
      return '${(kg / 1000).toStringAsFixed(2)} tonn';
    }
    return '${kg.toStringAsFixed(1)} kg';
  }

  String _formatPellet(double pellet) {
    if (pellet <= 0) return 'Pellet ikke satt';
    return '${pellet.toStringAsFixed(1)} mm';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return _parseDouble(value?.toString()) ?? 0;
  }

  double _stockKg(Map<String, dynamic> data) {
    final stockKg = data['stockKg'];
    if (stockKg is num) return stockKg.toDouble();
    return _toInt(data['bags']) * _toDouble(data['kgPerBag']);
  }

  double? _parseDouble(String? value) {
    if (value == null) return null;
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  bool _toBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    return fallback;
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FeedInventoryHistoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: UserService.getCurrentUserRole(),
      builder: (context, roleSnapshot) {
        final role = roleSnapshot.data ?? 'leser';
        final canWrite = _canWrite(role);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Fôrlager'),
            actions: [
              IconButton(
                tooltip: 'Historikk',
                icon: const Icon(Icons.history),
                onPressed: _openHistory,
              ),
            ],
          ),
          floatingActionButton: canWrite
              ? FloatingActionButton.extended(
                  onPressed: _openFeedTypeDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Ny fôrtype'),
                )
              : null,
          body: FutureBuilder<void>(
            future: _ensureDefaultFeedTypes(),
            builder: (context, setupSnapshot) {
              if (setupSnapshot.hasError) {
                return Center(child: Text('Feil: ${setupSnapshot.error}'));
              }

              if (setupSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _feedRef.orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Feil: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  double totalKg = 0;
                  for (final doc in docs) {
                    final data = doc.data();
                    final active = _toBool(data['active'], fallback: true);

                    if (active) {
                      totalKg += _stockKg(data);
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2),
                          title: const Text('Aktivt fôrlager'),
                          subtitle: Text(_formatKg(totalKg)),
                        ),
                      ),
                      if (!canWrite)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.visibility),
                            title: const Text('Lesetilgang'),
                            subtitle: Text(
                              'Du er logget inn som $role og kan kun se lager.',
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      ...docs.map((doc) {
                        final data = doc.data();

                        final name = (data['name'] ?? doc.id).toString();
                        final bags = _toInt(data['bags']);
                        final kgPerBag = _toDouble(data['kgPerBag']);
                        final pelletSizeMm = _toDouble(data['pelletSizeMm']);
                        final active = _toBool(data['active'], fallback: true);
                        final total = _stockKg(data);
                        final cardColor =
                            active ? null : Theme.of(context).disabledColor;

                        return Card(
                          color: active ? null : const Color(0xFFF1F3F5),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: active
                                          ? const Color(0xFFD9F0FF)
                                          : const Color(0xFFE0E0E0),
                                      child: Icon(
                                        Icons.inventory,
                                        color: active
                                            ? const Color(0xFF0B3C5D)
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: cardColor,
                                            ),
                                          ),
                                          if (!active)
                                            Text(
                                              'Inaktiv fôrtype',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (canWrite)
                                      Switch(
                                        value: active,
                                        onChanged: (_) => _toggleActive(
                                          docId: doc.id,
                                          name: name,
                                          active: active,
                                          stockKg: total,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _chip(
                                      icon: Icons.grain,
                                      label: _formatPellet(pelletSizeMm),
                                      color: const Color(0xFF6A1B9A),
                                    ),
                                    _chip(
                                      icon: Icons.shopping_bag,
                                      label: '$bags sekker',
                                      color: const Color(0xFF328CC1),
                                    ),
                                    _chip(
                                      icon: Icons.scale,
                                      label:
                                          '${kgPerBag.toStringAsFixed(1)} kg/sekk',
                                      color: const Color(0xFF1565C0),
                                    ),
                                    _chip(
                                      icon: Icons.warehouse,
                                      label: _formatKg(total),
                                      color: const Color(0xFF2E7D32),
                                    ),
                                  ],
                                ),
                                if (canWrite) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.add),
                                          label: const Text('Juster sekker'),
                                          onPressed: active
                                              ? () => _adjustBags(
                                                    docId: doc.id,
                                                    name: name,
                                                    currentBags: bags,
                                                  )
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        tooltip: 'Endre fôrtype',
                                        icon: const Icon(Icons.edit_note),
                                        onPressed: () =>
                                            _openFeedTypeDialog(doc: doc),
                                      ),
                                      IconButton(
                                        tooltip: 'Endre kg per sekk',
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _editKgPerBag(
                                          docId: doc.id,
                                          name: name,
                                          currentKg: kgPerBag,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class FeedInventoryHistoryScreen extends StatelessWidget {
  const FeedInventoryHistoryScreen({super.key});

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Ukjent dato';
    final date = timestamp.toDate();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final historyRef = FirebaseFirestore.instance
        .collection('feed_inventory_history')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lagerhistorikk'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: historyRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Feil: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text('Ingen lagerhistorikk ennå'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final feedType = (data['feedType'] ?? 'Ukjent fôr').toString();
              final user = (data['user'] ?? 'ukjent').toString();
              final timestamp = data['timestamp'];
              final note = (data['note'] ?? '').toString();

              final changeRaw = data['change'] ?? 0;
              final change = changeRaw is int
                  ? changeRaw
                  : int.tryParse(changeRaw.toString()) ?? 0;

              final bagsAfter = data['bagsAfter'];

              final kgBefore = data['kgPerBagBefore'];
              final kgAfter = data['kgPerBagAfter'];

              final isKgChange = kgBefore != null && kgAfter != null;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: change >= 0
                        ? const Color(0xFFDFF5E1)
                        : const Color(0xFFFFE0E0),
                    child: Icon(
                      isKgChange
                          ? Icons.edit
                          : change >= 0
                              ? Icons.add
                              : Icons.remove,
                      color: isKgChange
                          ? Colors.blue
                          : change >= 0
                              ? Colors.green
                              : Colors.red,
                    ),
                  ),
                  title: Text(feedType),
                  subtitle: Text(
                    isKgChange
                        ? 'Kg/sekk: $kgBefore -> $kgAfter\n'
                            '$user • ${_formatDate(timestamp is Timestamp ? timestamp : null)}'
                        : '${change > 0 ? '+' : ''}$change sekker'
                            '${bagsAfter != null ? ' • Etter: $bagsAfter sekker' : ''}\n'
                            '$user • ${_formatDate(timestamp is Timestamp ? timestamp : null)}'
                            '${note.isNotEmpty ? '\n$note' : ''}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
