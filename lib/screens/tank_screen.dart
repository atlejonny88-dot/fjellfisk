import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../services/firestore_service.dart';
import '../services/excel_service.dart';
import '../services/user_service.dart';
import '../services/fcr_service.dart';
import '../services/growth_forecast_service.dart';
import '../services/tank_info_service.dart';
import '../utils/tank_status.dart';
import 'tank_chart_screen.dart';
import 'tank_mortality_chart_screen.dart';
import 'tank_history_screen.dart';
import 'move_fish_screen.dart';
import 'tank_info_screen.dart';
import 'weight_samples_screen.dart';

class TankScreen extends StatefulWidget {
  final String facilityId;
  final String sectionId;
  final String tankId;
  final String tankName;
  final int fishCount;

  const TankScreen({
    super.key,
    required this.facilityId,
    required this.sectionId,
    required this.tankId,
    required this.tankName,
    required this.fishCount,
  });

  @override
  State<TankScreen> createState() => _TankScreenState();
}

class _TankScreenState extends State<TankScreen> {
  final deadCtrl = TextEditingController();
  final feedCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final tempCtrl = TextEditingController();
  String? _selectedFeedInventoryId;
  bool _showFeedInventoryPicker = false;

  @override
  void dispose() {
    deadCtrl.dispose();
    feedCtrl.dispose();
    weightCtrl.dispose();
    tempCtrl.dispose();
    super.dispose();
  }

  bool _canWrite(String role) {
    return role == 'admin' || role == 'ansatt';
  }

  double _toDouble(dynamic value) {
    return TankInfoService.toDouble(value);
  }

  double? _tryParsePositiveDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  double _weightFromLog(Map<String, dynamic> data) {
    final candidates = [
      data['avgWeight'],
      data['avgWeightGram'],
      data['averageWeight'],
      data['weight'],
    ];

    for (final value in candidates) {
      final weight = _toDouble(value);
      if (weight > 0) return weight;
    }

    return 0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  CollectionReference<Map<String, dynamic>> get _logsRef {
    return FirebaseFirestore.instance
        .collection('facilities')
        .doc(widget.facilityId)
        .collection('sections')
        .doc(widget.sectionId)
        .collection('tanks')
        .doc(widget.tankId)
        .collection('logs');
  }

  CollectionReference<Map<String, dynamic>> get _feedInventoryRef {
    return FirebaseFirestore.instance.collection('feed_inventory');
  }

  CollectionReference<Map<String, dynamic>> get _tankNotesRef {
    return FirebaseFirestore.instance
        .collection('facilities')
        .doc(widget.facilityId)
        .collection('sections')
        .doc(widget.sectionId)
        .collection('tanks')
        .doc(widget.tankId)
        .collection('tankNotes');
  }

  double _stockKg(Map<String, dynamic> data) {
    final stockKg = data['stockKg'];
    if (stockKg is num) return stockKg.toDouble();

    final bags = _toInt(data['bags']);
    final kgPerBag = _toDouble(data['kgPerBag']);
    return bags * kgPerBag;
  }

  Future<double> _getLatestWeight() async {
    final snap =
        await _logsRef.orderBy('date', descending: true).limit(50).get();

    for (final doc in snap.docs) {
      final weight = _weightFromLog(doc.data());
      if (weight > 0) return weight;
    }

    return 0;
  }

  String _recommendedFeed(double weight) {
    return TankInfoService.recommendedFeed(weight);
  }

  String _pelletSize(double weight) {
    if (weight <= 0) return '-';
    if (weight < 2) return '0.5 mm';
    if (weight < 5) return '0.8 mm';
    if (weight < 15) return '1.0 mm';
    if (weight < 100) return '2.0 mm';
    if (weight < 300) return '3 mm';
    return '6 mm';
  }

  String _nextFeedMessage(double weight) {
    if (weight <= 0) return 'Ingen snittvekt registrert ennå';
    if (weight < 2) {
      return '${(2 - weight).toStringAsFixed(1)} g igjen til Nutra Sprint 0.8';
    }
    if (weight < 5) {
      return '${(5 - weight).toStringAsFixed(1)} g igjen til Nutra Sprint 1.0';
    }
    if (weight < 15) {
      return '${(15 - weight).toStringAsFixed(1)} g igjen til Nutra Olympic 2.0';
    }
    if (weight < 100) {
      return '${(100 - weight).toStringAsFixed(1)} g igjen til Polarfeed Laksens Valg 150';
    }
    if (weight < 300) {
      return '${(300 - weight).toStringAsFixed(1)} g igjen til Polarfeed Laksens Valg 300';
    }
    return 'Sluttfôr / stor fisk';
  }

  double _biomassKg({
    required int fishCount,
    required double avgWeightGram,
  }) {
    if (fishCount <= 0 || avgWeightGram <= 0) return 0;
    return fishCount * avgWeightGram / 1000;
  }

  double _recommendedFeedPercent(double weight) {
    if (weight <= 0) return 0;
    if (weight < 100) return 1.5;
    if (weight < 300) return 1.0;
    if (weight < 1000) return 0.8;
    return 0.6;
  }

  double _recommendedDailyFeedKg({
    required double biomassKg,
    required double feedPercent,
  }) {
    if (biomassKg <= 0 || feedPercent <= 0) return 0;
    return biomassKg * (feedPercent / 100);
  }

  Future<void> _editFishCount() async {
    final controller = TextEditingController(
      text: widget.fishCount.toString(),
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Juster fisketall'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nytt antall fisk',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCount =
                  int.tryParse(controller.text) ?? widget.fishCount;

              await FirestoreService.updateFishCount(
                facilityId: widget.facilityId,
                sectionId: widget.sectionId,
                tankId: widget.tankId,
                fishCount: newCount < 0 ? 0 : newCount,
              );

              if (!mounted) return;

              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Lagre'),
          ),
        ],
      ),
    );
  }

  void _openMoveFish() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MoveFishScreen(
          facilityId: widget.facilityId,
          fromSectionId: widget.sectionId,
          fromTankId: widget.tankId,
          fromTankName: widget.tankName,
          fromFishCount: widget.fishCount,
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!TankStatus.isActiveFishCount(widget.fishCount)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Karet er tomt. Legg inn fisketall før drift registreres.'),
        ),
      );
      return;
    }

    final weightText = weightCtrl.text.trim();
    final feedText = feedCtrl.text.trim();
    final tempText = tempCtrl.text.trim();

    final dead = int.tryParse(deadCtrl.text.trim()) ?? 0;
    final feed = feedText.isEmpty ? 0.0 : _toDouble(feedText);
    final typedWeight = weightText.isEmpty ? 0.0 : _toDouble(weightText);
    final temp = tempText.isEmpty ? 0.0 : _toDouble(tempText);

    if (weightText.isNotEmpty && _tryParsePositiveDouble(weightText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ugyldig snittvekt')),
      );
      return;
    }

    final latestWeight = await _getLatestWeight();
    final weightToSave = typedWeight > 0 ? typedWeight : latestWeight;

    final newCount = widget.fishCount - dead;

    String? feedType = feed > 0 ? _recommendedFeed(weightToSave) : null;
    double? pelletSizeMm;

    if (feed > 0 && _selectedFeedInventoryId != null) {
      final feedSnap =
          await _feedInventoryRef.doc(_selectedFeedInventoryId).get();
      final feedData = feedSnap.data();

      if (!feedSnap.exists || feedData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valgt fôrtype finnes ikke.')),
        );
        return;
      }

      final availableKg = _stockKg(feedData);
      if (availableKg + 0.0001 < feed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ikke nok fôr på lager. Tilgjengelig: ${availableKg.toStringAsFixed(1)} kg.',
            ),
          ),
        );
        return;
      }

      feedType = (feedData['name'] ?? _selectedFeedInventoryId).toString();
      final pellet = _toDouble(feedData['pelletSizeMm']);
      if (pellet > 0) pelletSizeMm = pellet;
    }

    try {
      await FirestoreService.addDailyLog(
        facilityId: widget.facilityId,
        sectionId: widget.sectionId,
        tankId: widget.tankId,
        mortality: dead,
        feedKg: feed,
        avgWeight: weightToSave,
        temperature: temp,
        fishCountAfter: dead > 0 ? (newCount < 0 ? 0 : newCount) : null,
        feedInventoryId: feed > 0 && _selectedFeedInventoryId != null
            ? _selectedFeedInventoryId
            : null,
        feedType: feedType,
        pelletSizeMm: pelletSizeMm,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunne ikke lagre registrering: $error')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _openGrowthChart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TankChartScreen(
          facilityId: widget.facilityId,
          sectionId: widget.sectionId,
          tankId: widget.tankId,
          tankName: widget.tankName,
        ),
      ),
    );
  }

  void _openMortalityChart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TankMortalityChartScreen(
          facilityId: widget.facilityId,
          sectionId: widget.sectionId,
          tankId: widget.tankId,
          tankName: widget.tankName,
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TankHistoryScreen(
          facilityId: widget.facilityId,
          sectionId: widget.sectionId,
          tankId: widget.tankId,
          tankName: widget.tankName,
        ),
      ),
    );
  }

  void _openTankInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TankInfoScreen(
          facilityId: widget.facilityId,
          sectionId: widget.sectionId,
          tankId: widget.tankId,
          tankName: widget.tankName,
          fishCount: widget.fishCount,
        ),
      ),
    );
  }

  void _openWeightSamples() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeightSamplesScreen(
          facilityId: widget.facilityId,
          sectionId: widget.sectionId,
          tankId: widget.tankId,
          tankName: widget.tankName,
          fishCount: widget.fishCount,
        ),
      ),
    );
  }

  String _formatDateTime(Object? value) {
    if (value is! Timestamp) return 'Ukjent tidspunkt';

    final date = value.toDate();
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (isToday) return 'I dag kl. $hour:$minute';
    return '$day.$month.${date.year} kl. $hour:$minute';
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortNotes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    docs.sort((a, b) {
      final aDate = _noteSortDate(a.data());
      final bDate = _noteSortDate(b.data());
      return bDate.compareTo(aDate);
    });
    return docs;
  }

  DateTime _noteSortDate(Map<String, dynamic> data) {
    final updatedAt = data['updatedAt'];
    if (updatedAt is Timestamp) return updatedAt.toDate();

    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _openNoteDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? note,
  }) async {
    final controller = TextEditingController(
      text: (note?.data()['text'] ?? '').toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(note == null ? 'Nytt driftsnotat' : 'Rediger driftsnotat'),
        content: TextField(
          controller: controller,
          maxLength: 300,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Notat',
            hintText: 'F.eks. For mye spillfôr',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Avbryt'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;

              try {
                final user = UserService.currentUser;
                final now = Timestamp.now();
                final data = {
                  'text': text,
                  'status': 'active',
                  'updatedAt': now,
                  'updatedByUid': user?.uid,
                  'updatedByEmail': user?.email ?? 'ukjent',
                };

                if (note == null) {
                  await _tankNotesRef.add({
                    ...data,
                    'createdAt': now,
                    'createdByUid': user?.uid,
                    'createdByEmail': user?.email ?? 'ukjent',
                  });
                } else {
                  await note.reference.set(data, SetOptions(merge: true));
                }

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Driftsnotat lagret')),
                );
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kunne ikke lagre driftsnotat: $error'),
                  ),
                );
              }
            },
            child: const Text('Lagre'),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveNote(
    QueryDocumentSnapshot<Map<String, dynamic>> note,
  ) async {
    try {
      final user = UserService.currentUser;
      await note.reference.set({
        'status': 'resolved',
        'updatedAt': Timestamp.now(),
        'updatedByUid': user?.uid,
        'updatedByEmail': user?.email ?? 'ukjent',
        'resolvedAt': Timestamp.now(),
        'resolvedByUid': user?.uid,
        'resolvedByEmail': user?.email ?? 'ukjent',
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driftsnotat markert som ferdig')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunne ikke lagre driftsnotat: $error')),
      );
    }
  }

  Widget _noteCard({
    required bool canWrite,
    required QueryDocumentSnapshot<Map<String, dynamic>>? activeNote,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> resolvedNotes,
  }) {
    final data = activeNote?.data();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sticky_note_2, color: Color(0xFFB26A00)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Driftsnotat',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (canWrite)
                  IconButton(
                    tooltip: activeNote == null ? 'Nytt notat' : 'Rediger',
                    icon: Icon(activeNote == null ? Icons.add : Icons.edit),
                    onPressed: () => _openNoteDialog(note: activeNote),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (activeNote == null)
              Text(
                canWrite
                    ? 'Ingen aktivt driftsnotat.'
                    : 'Ingen aktivt driftsnotat.',
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF4B942)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data?['text']?.toString() ?? ''),
                    const SizedBox(height: 8),
                    Text(
                      'Skrevet av: ${(data?['updatedByEmail'] ?? data?['createdByEmail'] ?? 'ukjent')}\n'
                      '${_formatDateTime(data?['updatedAt'] ?? data?['createdAt'])}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (canWrite) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Marker som ferdig'),
                          onPressed: () => _resolveNote(activeNote),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (canWrite && activeNote == null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Opprett driftsnotat'),
                  onPressed: () => _openNoteDialog(),
                ),
              ),
            if (resolvedNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Ferdige notater (${resolvedNotes.length})'),
                children: resolvedNotes.map((note) {
                  final noteData = note.data();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(noteData['text']?.toString() ?? ''),
                    subtitle: Text(
                      'Ferdig: ${_formatDateTime(noteData['resolvedAt'])}\n'
                      '${noteData['resolvedByEmail'] ?? noteData['updatedByEmail'] ?? 'ukjent'}',
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _notesSection({required bool canWrite}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _tankNotesRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint('Kunne ikke laste driftsnotater: ${snapshot.error}');
          }
          return const Card(
            child: ListTile(
              leading: Icon(Icons.error_outline),
              title: Text('Driftsnotat'),
              subtitle: Text('Driftsnotater er ikke tilgjengelige nå.'),
            ),
          );
        }

        final notes = _sortNotes(snapshot.data?.docs ?? []);
        final activeNotes =
            notes.where((doc) => doc.data()['status'] == 'active').toList();
        final resolvedNotes =
            notes.where((doc) => doc.data()['status'] == 'resolved').toList();

        return _noteCard(
          canWrite: canWrite,
          activeNote: activeNotes.isEmpty ? null : activeNotes.first,
          resolvedNotes: resolvedNotes,
        );
      },
    );
  }

  Future<void> _exportExcel() async {
    try {
      await ExcelService.exportTank(
        facilityId: widget.facilityId,
        sectionId: widget.sectionId,
        tankId: widget.tankId,
        tankName: widget.tankName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel eksport fullført')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunne ikke eksportere Excel: $error')),
      );
    }
  }

  Widget _fcrCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: FcrService.calculateTankFcr(
        facilityId: widget.facilityId,
        sectionId: widget.sectionId,
        tankId: widget.tankId,
        currentFishCount: widget.fishCount,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.show_chart),
              title: Text('FCR'),
              subtitle: Text('Beregner...'),
            ),
          );
        }

        final data = snapshot.data!;

        if (data['hasData'] != true) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('FCR'),
              subtitle: Text(data['message']?.toString() ?? 'Ikke nok data'),
            ),
          );
        }

        final fcr = _toDouble(data['fcr']);
        final feedKg = _toDouble(data['feedKg']);
        final biomassGainKg = _toDouble(data['biomassGainKg']);
        final startWeight = _toDouble(data['startWeight']);
        final endWeight = _toDouble(data['endWeight']);

        Color color;
        if (fcr <= 1.0) {
          color = Colors.green;
        } else if (fcr <= 1.2) {
          color = Colors.orange;
        } else {
          color = Colors.red;
        }

        return Card(
          child: ListTile(
            leading: Icon(
              Icons.show_chart,
              color: color,
            ),
            title: const Text('FCR'),
            subtitle: Text(
              'Startvekt: ${startWeight.toStringAsFixed(1)} g\n'
              'Sluttvekt: ${endWeight.toStringAsFixed(1)} g\n'
              'Biomasseøkning: ${biomassGainKg.toStringAsFixed(1)} kg\n'
              'Fôr brukt: ${feedKg.toStringAsFixed(1)} kg',
            ),
            trailing: Text(
              fcr.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _growthForecastCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: GrowthForecastService.forecastTankGrowth(
        facilityId: widget.facilityId,
        sectionId: widget.sectionId,
        tankId: widget.tankId,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.trending_up),
              title: Text('Vekstprognose'),
              subtitle: Text('Beregner...'),
            ),
          );
        }

        final data = snapshot.data!;

        if (data['hasData'] != true) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.trending_up),
              title: const Text('Vekstprognose'),
              subtitle: Text(data['message']?.toString() ?? 'Ikke nok data'),
            ),
          );
        }

        final sgr = _toDouble(data['sgr']);
        final lastWeight = _toDouble(data['lastWeight']);
        final forecast30 = _toDouble(data['forecast30']);
        final forecast60 = _toDouble(data['forecast60']);
        final forecast90 = _toDouble(data['forecast90']);
        final daysMeasured = _toInt(data['daysMeasured']);

        return Card(
          child: ListTile(
            leading: const Icon(
              Icons.trending_up,
              color: Colors.blue,
            ),
            title: const Text('Vekstprognose'),
            subtitle: Text(
              'Nå: ${lastWeight.toStringAsFixed(1)} g\n'
              '30 dager: ${forecast30.toStringAsFixed(1)} g\n'
              '60 dager: ${forecast60.toStringAsFixed(1)} g\n'
              '90 dager: ${forecast90.toStringAsFixed(1)} g\n'
              'SGR: ${sgr.toStringAsFixed(2)} %/dag over $daysMeasured dager',
            ),
          ),
        );
      },
    );
  }

  Widget _feedInventoryPicker() {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Annen fôrtype fra lager'),
            subtitle: Text(
              _selectedFeedInventoryId == null
                  ? 'Ikke valgt - bruker anbefalt fôrtype'
                  : 'Valgt fôrtype trekkes fra lager',
            ),
            trailing: Icon(
              _showFeedInventoryPicker
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
            ),
            onTap: () {
              setState(() {
                _showFeedInventoryPicker = !_showFeedInventoryPicker;
              });
            },
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _showFeedInventoryPicker
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _feedInventoryRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    if (kDebugMode) {
                      debugPrint(
                          'Kunne ikke laste fôrlager: ${snapshot.error}');
                    }
                    return Text(
                      'Kunne ikke laste fôrlager nå.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }

                  final docs = [...(snapshot.data?.docs ?? [])]
                    ..removeWhere((doc) => doc.data()['active'] == false)
                    ..sort((a, b) {
                      final aData = a.data();
                      final bData = b.data();
                      final nameCompare = (aData['name'] ?? a.id)
                          .toString()
                          .compareTo((bData['name'] ?? b.id).toString());
                      if (nameCompare != 0) return nameCompare;
                      return _toDouble(aData['pelletSizeMm'])
                          .compareTo(_toDouble(bData['pelletSizeMm']));
                    });
                  if (docs.isEmpty) {
                    return const Text(
                      'Ingen aktive fôrtype i lager. Anbefalt fôrtype brukes.',
                    );
                  }

                  final selectedExists =
                      docs.any((doc) => doc.id == _selectedFeedInventoryId);
                  final value =
                      selectedExists ? _selectedFeedInventoryId : null;

                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: value,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Velg fôrtype',
                          helperText:
                              'Valgfritt. Brukes bare hvis du gir annen type enn anbefalt.',
                        ),
                        items: docs.map<DropdownMenuItem<String>>((doc) {
                          final data = doc.data();
                          final name = (data['name'] ?? doc.id).toString();
                          final pelletSize = _toDouble(data['pelletSizeMm']);
                          final stockKg = _stockKg(data);
                          final pelletText = pelletSize > 0
                              ? ' • ${pelletSize.toStringAsFixed(1)} mm'
                              : '';

                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              '$name$pelletText • ${stockKg.toStringAsFixed(1)} kg',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedFeedInventoryId = value);
                        },
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.close),
                          label: const Text('Bruk anbefalt fôrtype'),
                          onPressed: _selectedFeedInventoryId == null
                              ? null
                              : () {
                                  setState(() {
                                    _selectedFeedInventoryId = null;
                                  });
                                },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _showLegacyInfoCards => false;

  @override
  Widget build(BuildContext context) {
    final typedWeight = _toDouble(weightCtrl.text);

    return FutureBuilder<String>(
      future: UserService.getCurrentUserRole(),
      builder: (context, roleSnapshot) {
        final role = roleSnapshot.data ?? 'leser';
        final canWrite = _canWrite(role);
        final isActive = TankStatus.isActiveFishCount(widget.fishCount);

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.tankName),
            actions: [
              if (canWrite)
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: _exportExcel,
                ),
            ],
          ),
          body: FutureBuilder<double>(
            future: _getLatestWeight(),
            builder: (context, snapshot) {
              final latestWeight = snapshot.data ?? 0;
              final displayWeight =
                  typedWeight > 0 ? typedWeight : latestWeight;

              final biomassKg = _biomassKg(
                fishCount: widget.fishCount,
                avgWeightGram: displayWeight,
              );
              final biomassTon = biomassKg / 1000;

              final feedPercent = _recommendedFeedPercent(displayWeight);
              final dailyFeedKg = _recommendedDailyFeedKg(
                biomassKg: biomassKg,
                feedPercent: feedPercent,
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!canWrite)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.visibility),
                        title: const Text('Lesetilgang'),
                        subtitle: Text(
                          'Du er logget inn som $role og kan kun se data.',
                        ),
                      ),
                    ),
                  Card(
                    child: ListTile(
                      title: const Text('Antall fisk'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.fishCount.toString(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (canWrite)
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: _editFishCount,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.scale),
                      title: const Text('Biomasse'),
                      subtitle: Text(
                        !isActive
                            ? 'Ikke i bruk - legg inn fisketall for å beregne biomasse'
                            : displayWeight <= 0
                                ? 'Registrer snittvekt for å beregne biomasse'
                                : 'Snittvekt: ${displayWeight.toStringAsFixed(1)} g\n'
                                    '${biomassKg.toStringAsFixed(1)} kg\n'
                                    '${biomassTon.toStringAsFixed(2)} tonn',
                      ),
                    ),
                  ),
                  if (!isActive)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.pause_circle),
                        title: Text('Tomt kar'),
                        subtitle: Text(
                          'Ikke i bruk. Legg inn fisketall med blyanten for å aktivere karet.',
                        ),
                      ),
                    ),
                  _notesSection(canWrite: canWrite),
                  if (_showLegacyInfoCards && isActive)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.restaurant),
                        title: const Text('Anbefalt fôr'),
                        subtitle: Text(
                          'Siste snittvekt: ${displayWeight > 0 ? '${displayWeight.toStringAsFixed(1)} g' : 'ikke registrert'}\n'
                          '${_recommendedFeed(displayWeight)}\n'
                          'Pellet: ${_pelletSize(displayWeight)}\n'
                          '${_nextFeedMessage(displayWeight)}',
                        ),
                      ),
                    ),
                  if (_showLegacyInfoCards && isActive)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_dining),
                        title: const Text('Anbefalt daglig fôrrasjon'),
                        subtitle: Text(
                          displayWeight <= 0
                              ? 'Registrer snittvekt for å beregne fôrrasjon'
                              : 'Biomasse: ${biomassKg.toStringAsFixed(1)} kg\n'
                                  'Fôrprosent: ${feedPercent.toStringAsFixed(1)} %\n'
                                  'Anbefalt: ${dailyFeedKg.toStringAsFixed(1)} kg/dag',
                        ),
                      ),
                    ),
                  if (_showLegacyInfoCards && isActive) _fcrCard(),
                  if (_showLegacyInfoCards && isActive) _growthForecastCard(),
                  if (canWrite && isActive) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: deadCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Dødelighet',
                      ),
                    ),
                    TextField(
                      controller: feedCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Fôr (kg)',
                      ),
                    ),
                    _feedInventoryPicker(),
                    TextField(
                      controller: weightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Snittvekt (g) – valgfritt',
                        helperText:
                            'La stå tomt hvis fisken ikke er veid i dag',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    TextField(
                      controller: tempCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Temperatur',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _save,
                      child: const Text('Lagre'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openWeightSamples,
                      icon: const Icon(Icons.monitor_weight),
                      label: const Text('Vektprøve'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _openTankInfo,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Kar info'),
                    ),
                    const SizedBox(height: 8),
                    if (isActive)
                      ElevatedButton(
                        onPressed: _openMoveFish,
                        child: const Text('Flytt fisk'),
                      ),
                  ],
                  if (!(canWrite && isActive)) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openWeightSamples,
                      icon: const Icon(Icons.monitor_weight),
                      label: const Text('Vektprøve'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _openTankInfo,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Kar info'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _openHistory,
                    child: const Text('Historikk'),
                  ),
                  ElevatedButton(
                    onPressed: _openGrowthChart,
                    child: const Text('Vekstdiagram'),
                  ),
                  ElevatedButton(
                    onPressed: _openMortalityChart,
                    child: const Text('Dødelighetsdiagram'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
