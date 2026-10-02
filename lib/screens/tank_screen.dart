import 'dart:async';

import '../utils/data_values.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../services/firestore_service.dart';
import '../services/excel_service.dart';
import '../services/user_service.dart';
import '../services/fcr_service.dart';
import '../services/growth_forecast_service.dart';
import '../services/tank_info_service.dart';
import '../services/registration_round.dart';
import '../services/web_update_guard.dart';
import '../l10n/localizations.dart';
import '../widgets/tank_registration_actions.dart';
import '../utils/tank_status.dart';
import '../utils/ui_motion.dart';
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
  final _saveState = RegistrationSave();
  bool _openingNext = false;
  bool _showSaveFeedback = false;
  String? _registrationId;
  Timer? _saveFeedbackTimer;
  late int _fishCount;
  late final Future<String> _roleFuture;
  late Future<double> _weightFuture;

  @override
  void initState() {
    super.initState();
    _fishCount = widget.fishCount;
    RegistrationRound.session.setUser(UserService.currentUserId);
    _roleFuture = UserService.getCurrentUserRole();
    _weightFuture = _getLatestWeight();
    _saveState.addListener(_saveChanged);
  }

  void _saveChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _saveFeedbackTimer?.cancel();
    _saveState.dispose();
    deadCtrl.dispose();
    feedCtrl.dispose();
    weightCtrl.dispose();
    tempCtrl.dispose();
    super.dispose();
  }

  bool _canWrite(String role) {
    return role == 'admin' || role == 'ansatt';
  }

  double _toDouble(dynamic value) => DataValues.decimal(value);

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

  int _toInt(dynamic value) => DataValues.integer(value);

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
    final parsed = DataValues.number(stockKg);
    if (parsed != null) return parsed.toDouble();

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
    if (weight <= 0) return context.l10n.noAverageWeightRegistered;
    if (weight < 2) {
      return context.l10n.weightUntilFeed(
        (2 - weight).toStringAsFixed(1),
        'Nutra Sprint 0.8',
      );
    }
    if (weight < 5) {
      return context.l10n.weightUntilFeed(
        (5 - weight).toStringAsFixed(1),
        'Nutra Sprint 1.0',
      );
    }
    if (weight < 15) {
      return context.l10n.weightUntilFeed(
        (15 - weight).toStringAsFixed(1),
        'Nutra Olympic 2.0',
      );
    }
    if (weight < 100) {
      return context.l10n.weightUntilFeed(
        (100 - weight).toStringAsFixed(1),
        'Polarfeed Laksens Valg 150',
      );
    }
    if (weight < 300) {
      return context.l10n.weightUntilFeed(
        (300 - weight).toStringAsFixed(1),
        'Polarfeed Laksens Valg 300',
      );
    }
    return context.l10n.finishFeedLargeFish;
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
      text: _fishCount.toString(),
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.adjustFishCount),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.l10n.newFishCount,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCount = int.tryParse(controller.text) ?? _fishCount;

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
            child: Text(context.l10n.save),
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
          fromFishCount: _fishCount,
        ),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSaveConfirmation() {
    _saveFeedbackTimer?.cancel();
    setState(() => _showSaveFeedback = true);
    _saveFeedbackTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showSaveFeedback = false);
    });
  }

  double _parseNumber(String text, String label, {bool positive = false}) {
    if (text.trim().isEmpty) return 0;
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null ||
        !value.isFinite ||
        (positive ? value <= 0 : value < 0)) {
      throw FormatException(context.l10n.invalidValue(label));
    }
    return value;
  }

  Future<void> _save({bool goNext = false}) async {
    if (_saveState.busy || _openingNext) return;
    final l10n = context.l10n;
    try {
      final saved = await _saveState.run(() async {
        final deadText = deadCtrl.text.trim();
        final dead = deadText.isEmpty ? 0 : int.tryParse(deadText);
        if (dead == null || dead < 0) {
          throw FormatException(l10n.invalidMortality);
        }
        final feed = _parseNumber(feedCtrl.text, l10n.feed);
        final typedWeight =
            _parseNumber(weightCtrl.text, l10n.averageWeight, positive: true);
        final temp = _parseNumber(tempCtrl.text, l10n.temperature);
        if ([deadCtrl, feedCtrl, weightCtrl, tempCtrl]
            .every((controller) => controller.text.trim().isEmpty)) {
          throw FormatException(l10n.enterAtLeastOneRegistration);
        }
        final selectedFeedId = _selectedFeedInventoryId;
        final role = await UserService.getCurrentUserRole();
        if (!_canWrite(role)) {
          throw FormatException(l10n.noRegistrationAccess);
        }
        // Refresh the count before saving again on the same screen.
        final tank =
            await _logsRef.parent!.get(const GetOptions(source: Source.server));
        if (!tank.exists) {
          throw FormatException(l10n.tankNoLongerExists);
        }
        final count = TankStatus.fishCountFrom(tank.data()?['fishCount']);
        if (count <= 0) {
          throw FormatException(l10n.emptyTankBeforeRegistration);
        }
        if (dead > count) {
          throw FormatException(l10n.mortalityExceedsFishCount);
        }
        final weightToSave =
            typedWeight > 0 ? typedWeight : await _getLatestWeight();
        String? feedType = feed > 0 ? _recommendedFeed(weightToSave) : null;
        double? pelletSizeMm;
        if (feed > 0 && selectedFeedId != null) {
          final feedSnap = await _feedInventoryRef.doc(selectedFeedId).get();
          final feedData = feedSnap.data();
          if (!feedSnap.exists || feedData == null) {
            throw FormatException(l10n.selectedFeedTypeMissing);
          }
          final availableKg = _stockKg(feedData);
          if (availableKg + 0.0001 < feed) {
            throw FormatException(
              l10n.insufficientFeedInStock(availableKg.toStringAsFixed(1)),
            );
          }
          feedType = (feedData['name'] ?? selectedFeedId).toString();
          final pellet = _toDouble(feedData['pelletSizeMm']);
          if (pellet > 0) pelletSizeMm = pellet;
        }
        if (!mounted) {
          throw FormatException(l10n.registrationCancelled);
        }
        _registrationId ??= _logsRef.doc().id;
        final countAfter = await FirestoreService.addDailyLog(
          facilityId: widget.facilityId,
          sectionId: widget.sectionId,
          tankId: widget.tankId,
          mortality: dead,
          feedKg: feed,
          // A feed-only entry is not a new weight measurement.
          avgWeight: typedWeight,
          temperature: temp,
          registrationId: _registrationId,
          feedInventoryId: feed > 0 ? selectedFeedId : null,
          feedType: feedType,
          pelletSizeMm: pelletSizeMm,
        );
        RegistrationRound.session.markReviewed(
          widget.facilityId,
          widget.sectionId,
          widget.tankId,
        );
        if (!mounted) return;
        _registrationId = null;
        _fishCount = countAfter;
        for (final controller in [deadCtrl, feedCtrl, weightCtrl, tempCtrl]) {
          controller.clear();
        }
        _weightFuture = Future.value(weightToSave);
      });
      if (!mounted || !saved) return;
      _showSaveConfirmation();
      _message(l10n.registrationSaved);
      if (goNext) await _openNextTank();
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
    } catch (error, stack) {
      debugPrint('Kunne ikke lagre registrering: $error\n$stack');
      if (mounted) _message(l10n.registrationSaveFailed);
    }
  }

  Future<void> _openNextTank() async {
    if (_saveState.busy || _openingNext) return;
    setState(() => _openingNext = true);
    var navigating = false;
    try {
      if ([deadCtrl, feedCtrl, weightCtrl, tempCtrl]
          .any((controller) => controller.text.trim().isNotEmpty)) {
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.unsavedChanges),
            content: Text(context.l10n.leaveWithoutSaving),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.cancel)),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.l10n.nextTank)),
            ],
          ),
        );
        if (leave != true || !mounted) return;
      }
      final snapshot = await _logsRef.parent!.parent
          .orderBy('createdAt')
          .get(const GetOptions(source: Source.server));
      final next = RegistrationRound.session.next(
        widget.facilityId,
        widget.sectionId,
        widget.tankId,
        snapshot.docs
            .map((doc) => <String, dynamic>{
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList(),
      );
      if (!mounted) return;
      if (next == null) {
        _message(context.l10n.allTanksReviewed);
        return;
      }
      // Replace only the tank route so Back still returns directly to its section.
      Navigator.of(context).pushReplacement(subtleFadeSlideRoute<void>(
        context: context,
        builder: (_) => TankScreen(
          facilityId: widget.facilityId,
          sectionId: widget.sectionId,
          tankId: next['id'].toString(),
          tankName: (next['name'] ?? next['id']).toString(),
          fishCount: TankStatus.fishCountFrom(next['fishCount']),
        ),
      ));
      navigating = true;
    } catch (error, stack) {
      debugPrint('Kunne ikke åpne neste kar: $error\n$stack');
      if (mounted) {
        _message(context.l10n.nextTankOpenFailed);
      }
    } finally {
      if (mounted && !navigating) setState(() => _openingNext = false);
    }
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
          fishCount: _fishCount,
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
          fishCount: _fishCount,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _weightFuture = _getLatestWeight());
    });
  }

  String _formatDateTime(Object? value) {
    if (value is! Timestamp) return context.l10n.unknownTime;

    final date = value.toDate();
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (isToday) return context.l10n.todayAt('$hour:$minute');
    return '$day.$month.${date.year} $hour:$minute';
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
    final l10n = context.l10n;
    var saving = false;
    var saved = false;
    final noteRef = note?.reference ?? _tankNotesRef.doc();
    final controller = TextEditingController(
      text: (note?.data()['text'] ?? '').toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          note == null
              ? context.l10n.newOperationalNote
              : context.l10n.editOperationalNote,
        ),
        content: TextField(
          controller: controller,
          maxLength: 300,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: context.l10n.notes,
            hintText: context.l10n.noteHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!saving) Navigator.pop(dialogContext);
            },
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (saving || saved) return;
              final text = controller.text.trim();
              if (text.isEmpty) return;
              saving = true;
              setWebSavePending(true);
              try {
                if (!_canWrite(await UserService.getCurrentUserRole())) {
                  throw FormatException(l10n.noWriteAccess);
                }
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
                  await noteRef.set({
                    ...data,
                    'createdAt': now,
                    'createdByUid': user?.uid,
                    'createdByEmail': user?.email ?? 'ukjent',
                  });
                } else {
                  await note.reference.set(data, SetOptions(merge: true));
                }

                saved = true;
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.operationalNoteSaved)),
                );
              } catch (error) {
                debugPrint('Driftsnotat: $error');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.operationalNoteSaveFailed),
                  ),
                );
              } finally {
                saving = false;
                setWebSavePending(false);
              }
            },
            child: Text(context.l10n.save),
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
        SnackBar(content: Text(context.l10n.operationalNoteCompleted)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.operationalNoteSaveFailed)),
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
                Expanded(
                  child: Text(
                    context.l10n.notes,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (canWrite)
                  IconButton(
                    tooltip: activeNote == null
                        ? context.l10n.newNote
                        : context.l10n.edit,
                    icon: Icon(activeNote == null ? Icons.add : Icons.edit),
                    onPressed: () => _openNoteDialog(note: activeNote),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (activeNote == null)
              Text(
                context.l10n.noActiveOperationalNote,
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
                      '${context.l10n.writtenBy((data?['updatedByEmail'] ?? data?['createdByEmail'] ?? 'ukjent').toString())}\n'
                      '${_formatDateTime(data?['updatedAt'] ?? data?['createdAt'])}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (canWrite) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.check),
                          label: Text(context.l10n.markCompleted),
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
                  label: Text(context.l10n.createOperationalNote),
                  onPressed: () => _openNoteDialog(),
                ),
              ),
            if (resolvedNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(context.l10n.completedNotes(resolvedNotes.length)),
                children: resolvedNotes.map((note) {
                  final noteData = note.data();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(noteData['text']?.toString() ?? ''),
                    subtitle: Text(
                      '${context.l10n.completedAt(_formatDateTime(noteData['resolvedAt']))}\n'
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
          return Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(context.l10n.notes),
              subtitle: Text(context.l10n.tankNotesUnavailable),
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
        labels: context.l10n,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.excelExportComplete)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.excelExportFailed)),
      );
    }
  }

  Widget _fcrCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: FcrService.calculateTankFcr(
        facilityId: widget.facilityId,
        sectionId: widget.sectionId,
        tankId: widget.tankId,
        currentFishCount: _fishCount,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('FCR'),
              subtitle: Text(context.l10n.calculating),
            ),
          );
        }

        final data = snapshot.data!;

        if (data['hasData'] != true) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('FCR'),
              subtitle: Text(context.l10n.notEnoughData),
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
              '${context.l10n.startWeight}: ${startWeight.toStringAsFixed(1)} g\n'
              '${context.l10n.endWeight}: ${endWeight.toStringAsFixed(1)} g\n'
              '${context.l10n.biomassGain}: ${biomassGainKg.toStringAsFixed(1)} kg\n'
              '${context.l10n.feedUsed}: ${feedKg.toStringAsFixed(1)} kg',
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
          return Card(
            child: ListTile(
              leading: const Icon(Icons.trending_up),
              title: Text(context.l10n.growthForecast),
              subtitle: Text(context.l10n.calculating),
            ),
          );
        }

        final data = snapshot.data!;

        if (data['hasData'] != true) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.trending_up),
              title: Text(context.l10n.growthForecast),
              subtitle: Text(context.l10n.notEnoughData),
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
            title: Text(context.l10n.growthForecast),
            subtitle: Text(
              '${context.l10n.currentAverageWeight}: ${lastWeight.toStringAsFixed(1)} g\n'
              '${context.l10n.forecastDays(30)}: ${forecast30.toStringAsFixed(1)} g\n'
              '${context.l10n.forecastDays(60)}: ${forecast60.toStringAsFixed(1)} g\n'
              '${context.l10n.forecastDays(90)}: ${forecast90.toStringAsFixed(1)} g\n'
              '${context.l10n.sgrOverDays(sgr.toStringAsFixed(2), daysMeasured)}',
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
            title: Text(context.l10n.otherFeedType),
            subtitle: Text(
              _selectedFeedInventoryId == null
                  ? context.l10n.recommendedFeedUsed
                  : context.l10n.selectedFeedDrawnFromInventory,
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
                      context.l10n.feedInventoryLoadFailed,
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
                    return Text(
                      context.l10n.noActiveFeedUsesRecommended,
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
                        decoration: InputDecoration(
                          labelText: context.l10n.selectFeedType,
                          helperText: context.l10n.feedSelectionOptionalHint,
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
                          label: Text(context.l10n.useRecommendedFeedType),
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
      future: _roleFuture,
      builder: (context, roleSnapshot) {
        final role = roleSnapshot.data ?? 'leser';
        final canWrite = _canWrite(role);
        final isActive = TankStatus.isActiveFishCount(_fishCount);

        return PopScope(
          canPop: !_saveState.busy && !_openingNext,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.tankName),
              actions: [
                if (canWrite)
                  IconButton(
                    icon: const Icon(Icons.download),
                    onPressed:
                        _saveState.busy || _openingNext ? null : _exportExcel,
                  ),
              ],
            ),
            body: FutureBuilder<double>(
              future: _weightFuture,
              builder: (context, snapshot) {
                final latestWeight = snapshot.data ?? 0;
                final displayWeight =
                    typedWeight > 0 ? typedWeight : latestWeight;

                final biomassKg = _biomassKg(
                  fishCount: _fishCount,
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
                          title: Text(context.l10n.readerAccess),
                          subtitle: Text(
                            context.l10n.readOnlyRole(role),
                          ),
                        ),
                      ),
                    Card(
                      child: ListTile(
                        title: Text(context.l10n.numberOfFish),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fishCount.toString(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (canWrite)
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: _saveState.busy || _openingNext
                                    ? null
                                    : _editFishCount,
                              ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.scale),
                        title: Text(context.l10n.biomass),
                        subtitle: Text(
                          !isActive
                              ? context.l10n.emptyTankActivateHint
                              : displayWeight <= 0
                                  ? context.l10n.averageWeightMissingForBiomass
                                  : '${context.l10n.averageWeight}: ${displayWeight.toStringAsFixed(1)} g\n'
                                      '${biomassKg.toStringAsFixed(1)} kg\n'
                                      '${biomassTon.toStringAsFixed(2)} tonn',
                        ),
                      ),
                    ),
                    if (!isActive)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.pause_circle),
                          title: Text(context.l10n.emptyTank),
                          subtitle: Text(context.l10n.emptyTankActivateHint),
                        ),
                      ),
                    _notesSection(
                        canWrite:
                            canWrite && !_saveState.busy && !_openingNext),
                    if (_showLegacyInfoCards && isActive)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.restaurant),
                          title: Text(context.l10n.recommendedFeedLabel),
                          subtitle: Text(
                            '${context.l10n.latestAverageWeightLine(displayWeight > 0 ? '${displayWeight.toStringAsFixed(1)} g' : context.l10n.notRegistered)}\n'
                            '${_recommendedFeed(displayWeight)}\n'
                            '${context.l10n.pelletSize}: ${_pelletSize(displayWeight)}\n'
                            '${_nextFeedMessage(displayWeight)}',
                          ),
                        ),
                      ),
                    if (_showLegacyInfoCards && isActive)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.local_dining),
                          title: Text(context.l10n.dailyFeedRation),
                          subtitle: Text(
                            displayWeight <= 0
                                ? context.l10n.registerAverageWeightForFeed
                                : '${context.l10n.biomass}: ${biomassKg.toStringAsFixed(1)} kg\n'
                                    '${context.l10n.feedPercent}: ${feedPercent.toStringAsFixed(1)} %\n'
                                    '${context.l10n.recommendedFeedLabel}: ${dailyFeedKg.toStringAsFixed(1)} kg/dag',
                          ),
                        ),
                      ),
                    if (_showLegacyInfoCards && isActive) _fcrCard(),
                    if (_showLegacyInfoCards && isActive) _growthForecastCard(),
                    if (canWrite && isActive) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: deadCtrl,
                        enabled: !_saveState.busy && !_openingNext,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.l10n.mortalityInput,
                        ),
                      ),
                      TextField(
                        controller: feedCtrl,
                        enabled: !_saveState.busy && !_openingNext,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.l10n.feedKgInput,
                        ),
                      ),
                      AbsorbPointer(
                        absorbing: _saveState.busy || _openingNext,
                        child: _feedInventoryPicker(),
                      ),
                      TextField(
                        controller: weightCtrl,
                        enabled: !_saveState.busy && !_openingNext,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.l10n.averageWeightOptional,
                          helperText: context.l10n.leaveWeightEmptyHint,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      TextField(
                        controller: tempCtrl,
                        enabled: !_saveState.busy && !_openingNext,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.l10n.temperatureInput,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TankRegistrationActions(
                      canWrite: canWrite,
                      isActive: isActive,
                      saving: _saveState.busy,
                      openingNext: _openingNext,
                      hasSaved: _saveState.hasSaved,
                      showSavedFeedback: _showSaveFeedback,
                      onSave: () => _save(),
                      onSaveNext: () => _save(goNext: true),
                      onNext: _openNextTank,
                      onInfo: _openTankInfo,
                      onWeightSample: _openWeightSamples,
                      onMove: _openMoveFish,
                      onHistory: _openHistory,
                      onGrowth: _openGrowthChart,
                      onMortality: _openMortalityChart,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
