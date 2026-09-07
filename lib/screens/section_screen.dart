import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../services/user_service.dart';
import '../utils/tank_status.dart';
import '../widgets/tank_overview_card.dart';
import 'tank_screen.dart';

class SectionScreen extends StatefulWidget {
  final String facilityId;
  final String sectionId;
  final String sectionName;

  const SectionScreen({
    super.key,
    required this.facilityId,
    required this.sectionId,
    required this.sectionName,
  });

  @override
  State<SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen> {
  int _refreshKey = 0;
  late final Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = UserService.getCurrentUserRole();
  }

  CollectionReference<Map<String, dynamic>> get _tanksRef {
    return FirebaseFirestore.instance
        .collection('facilities')
        .doc(widget.facilityId)
        .collection('sections')
        .doc(widget.sectionId)
        .collection('tanks');
  }

  void _refresh() {
    setState(() {
      _refreshKey++;
    });
  }

  Future<void> _addTank(BuildContext context) async {
    final nameController = TextEditingController();
    final fishController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nytt kar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Navn på kar',
                hintText: 'F.eks. K1',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fishController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Antall fisk',
                hintText: 'F.eks. 12500',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final fishCount = int.tryParse(fishController.text) ?? 0;

              if (name.isEmpty) return;

              await _tanksRef.add({
                'name': name,
                'fishCount': fishCount,
                'createdAt': Timestamp.now(),
              });

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Opprett'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTank(String tankId) async {
    await _tanksRef.doc(tankId).delete();
  }

  Future<Map<String, dynamic>> _tankSummary(
    QueryDocumentSnapshot<Map<String, dynamic>> tankDoc,
  ) async {
    final data = tankDoc.data();

    final tankName = (data['name'] ?? 'Ukjent kar').toString();
    final fishCount = TankStatus.fishCountFrom(data['fishCount']);
    final isActive = TankStatus.isActiveFishCount(fishCount);

    final logsSnap = await tankDoc.reference
        .collection('logs')
        .orderBy('date', descending: true)
        .limit(50)
        .get();
    Map<String, dynamic>? activeNote;
    var notesUnavailable = false;

    try {
      final notesSnap = await tankDoc.reference
          .collection('tankNotes')
          .where('status', isEqualTo: 'active')
          .limit(10)
          .get();
      activeNote = _latestActiveNote(notesSnap.docs);
    } on FirebaseException catch (error, stackTrace) {
      if (error.code == 'permission-denied') {
        notesUnavailable = true;
        if (kDebugMode) {
          debugPrint(
            'Driftsnotater er ikke tilgjengelige for ${tankDoc.id}: $error',
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            'Firestore-feil ved lesing av driftsnotater for ${tankDoc.id}: '
            '$error\n$stackTrace',
          );
        }
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Uventet feil ved lesing av driftsnotater for ${tankDoc.id}: '
          '$error\n$stackTrace',
        );
      }
    }

    double latestWeight = 0;
    double latestTemperature = 0;
    double feedKgLast24h = 0;
    DateTime? latestWeightDate;
    int mortality7d = 0;

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final last24Hours = now.subtract(const Duration(hours: 24));

    if (isActive) {
      for (final log in logsSnap.docs) {
        final logData = log.data();

        final dateRaw = logData['date'];
        final date = dateRaw is Timestamp ? dateRaw.toDate() : null;

        final mortality = logData['mortality'] ?? logData['dead'] ?? 0;
        if (date != null && date.isAfter(sevenDaysAgo) && mortality is num) {
          mortality7d += mortality.toInt();
        }

        if (date != null && date.isAfter(last24Hours) && !date.isAfter(now)) {
          feedKgLast24h += _toDouble(logData['feedKg']);
        }

        final weight = _latestValidWeight(logData);
        if (latestWeight <= 0 && weight > 0) {
          latestWeight = weight;
          latestWeightDate = date;
        }

        final temperature = _toDouble(logData['temperature']);
        if (latestTemperature <= 0 && temperature > 0) {
          latestTemperature = temperature;
        }
      }
    }

    final biomassKg = isActive
        ? _biomassKg(
            fishCount: fishCount,
            avgWeightGram: latestWeight,
          )
        : 0.0;

    final feedPercent = isActive ? _feedPercent(latestWeight) : 0.0;
    final feedKgDay = biomassKg * (feedPercent / 100);

    final status = _status(
      isActive: isActive,
      latestWeight: latestWeight,
      latestWeightDate: latestWeightDate,
      mortality7d: mortality7d,
    );
    return {
      'id': tankDoc.id,
      'name': tankName,
      'fishCount': fishCount,
      'isActive': isActive,
      'latestWeight': latestWeight,
      'latestWeightDate': latestWeightDate,
      'latestTemperature': latestTemperature,
      'biomassKg': biomassKg,
      'feedKgDay': feedKgDay,
      'feedKgLast24h': feedKgLast24h,
      'mortality7d': mortality7d,
      'statusText': status['text'],
      'statusColor': status['color'],
      'statusIcon': status['icon'],
      'statusLevel': status['level'],
      'activeNote': activeNote,
      'notesUnavailable': notesUnavailable,
    };
  }

  double _biomassKg({
    required int fishCount,
    required double avgWeightGram,
  }) {
    if (fishCount <= 0 || avgWeightGram <= 0) return 0;
    return fishCount * avgWeightGram / 1000;
  }

  double _feedPercent(double weight) {
    if (weight <= 0) return 0;
    if (weight < 100) return 1.5;
    if (weight < 300) return 1.0;
    if (weight < 1000) return 0.8;
    return 0.6;
  }

  double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  double _latestValidWeight(Map<String, dynamic> data) {
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

  Map<String, dynamic>? _latestActiveNote(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return null;

    docs.sort((a, b) {
      final aDate = _noteSortDate(a.data());
      final bDate = _noteSortDate(b.data());
      return bDate.compareTo(aDate);
    });

    final doc = docs.first;
    return {
      'id': doc.id,
      ...doc.data(),
    };
  }

  DateTime _noteSortDate(Map<String, dynamic> data) {
    final updatedAt = data['updatedAt'];
    if (updatedAt is Timestamp) return updatedAt.toDate();

    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatNoteDate(Object? value) {
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

  String _shortNoteText(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= 95) return trimmed;
    return '${trimmed.substring(0, 92)}...';
  }

  Future<void> _showNoteDialog(
    BuildContext context,
    Map<String, dynamic> note,
  ) async {
    final text = (note['text'] ?? '').toString();
    final email = (note['updatedByEmail'] ?? note['createdByEmail'] ?? 'ukjent')
        .toString();
    final timestamp = note['updatedAt'] ?? note['createdAt'];

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Driftsnotat'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text),
              const SizedBox(height: 12),
              Text(
                'Skrevet av: $email\n${_formatNoteDate(timestamp)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Lukk'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _status({
    required bool isActive,
    required double latestWeight,
    required DateTime? latestWeightDate,
    required int mortality7d,
  }) {
    if (!isActive) {
      return {
        'text': 'Tomt kar',
        'level': 'empty',
        'color': const Color(0xFF7F8997),
        'icon': Icons.pause_circle,
      };
    }

    if (mortality7d >= 100) {
      return {
        'text': 'Høy dødelighet',
        'level': 'critical',
        'color': const Color(0xFFD53C3C),
        'icon': Icons.warning,
      };
    }

    if (latestWeight <= 0) {
      return {
        'text': 'Mangler snittvekt',
        'level': 'observation',
        'color': const Color(0xFFE49600),
        'icon': Icons.info,
      };
    }

    final daysSinceWeight = latestWeightDate == null
        ? 0
        : DateTime.now().difference(latestWeightDate).inDays;

    if (latestWeightDate != null && daysSinceWeight > 30) {
      return {
        'text': 'Gammel snittvekt',
        'level': 'observation',
        'color': const Color(0xFFE49600),
        'icon': Icons.schedule,
      };
    }

    return {
      'text': 'Normal drift',
      'level': 'active',
      'color': const Color(0xFF0BA765),
      'icon': Icons.check_circle,
    };
  }

  String _formatFish(int value) {
    return value.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ' ',
        );
  }

  String _formatDecimal(double value, {int decimals = 1}) {
    return value.toStringAsFixed(decimals).replaceAll('.', ',');
  }

  String _formatBiomass(double biomassKg) {
    if (biomassKg <= 0) return 'Ikke nok data';
    if (biomassKg >= 1000) {
      return '${_formatDecimal(biomassKg / 1000, decimals: 2)} tonn';
    }
    return '${_formatDecimal(biomassKg)} kg';
  }

  String _statusLabel(String level) {
    switch (level) {
      case 'critical':
        return 'Kritisk';
      case 'observation':
        return 'Observasjon';
      case 'empty':
        return 'Tomt kar';
      default:
        return 'Aktiv';
    }
  }

  String _statusMessage({
    required String level,
    required String statusText,
    required int mortality7d,
  }) {
    switch (level) {
      case 'critical':
        return 'Høy dødelighet · $mortality7d døde siste 7 dager';
      case 'observation':
        return '$statusText · følg opp nye målinger';
      case 'empty':
        return 'Ikke i bruk · kan åpnes og fylles senere';
      default:
        return mortality7d > 0
            ? 'Normal drift · dødelighet 7d: $mortality7d'
            : 'Alt innen normale verdier';
    }
  }

  Future<void> _confirmDeleteTank(
    BuildContext context,
    String tankId,
    String tankName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Slette $tankName?'),
        content: const Text(
          'Karet fjernes fra oversikten. Denne handlingen kan ikke angres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD53C3C),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Slett kar'),
          ),
        ],
      ),
    );

    if (confirmed == true) await _deleteTank(tankId);
  }

  void _openTank(BuildContext context, Map<String, dynamic> tank) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TankScreen(
          facilityId: widget.facilityId,
          sectionId: widget.sectionId,
          tankId: tank['id'].toString(),
          tankName: tank['name'].toString(),
          fishCount: tank['fishCount'] as int,
        ),
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fjellfisk 3.0',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Oppdater karoversikt',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        key: ValueKey(_refreshKey),
        stream: _tanksRef.orderBy('createdAt').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Firestore-feil:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Text('Laster kar...'),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.water, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Ingen kar i ${widget.sectionName} ennå',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _addTank(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Opprett første kar'),
                    ),
                  ],
                ),
              ),
            );
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait(docs.map(_tankSummary)),
            builder: (context, summarySnapshot) {
              if (summarySnapshot.hasError) {
                return Center(
                  child: Text('Feil: ${summarySnapshot.error}'),
                );
              }

              if (!summarySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final tanks = summarySnapshot.data!;
              return FutureBuilder<String>(
                future: _roleFuture,
                builder: (context, roleSnapshot) {
                  return _TankOverviewContent(
                    sectionName: widget.sectionName,
                    tanks: tanks,
                    isAdmin: roleSnapshot.data == 'admin',
                    onAddTank: () => _addTank(context),
                    cardBuilder: (tank) => _buildTankCard(
                      context,
                      tank,
                      isAdmin: roleSnapshot.data == 'admin',
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTankCard(
    BuildContext context,
    Map<String, dynamic> tank, {
    required bool isAdmin,
  }) {
    final isActive = tank['isActive'] as bool;
    final fishCount = tank['fishCount'] as int;
    final latestWeight = tank['latestWeight'] as double;
    final latestTemperature = tank['latestTemperature'] as double;
    final biomassKg = tank['biomassKg'] as double;
    final feedKgLast24h = tank['feedKgLast24h'] as double;
    final mortality7d = tank['mortality7d'] as int;
    final statusText = tank['statusText'].toString();
    final statusLevel = tank['statusLevel'].toString();
    final statusColor = tank['statusColor'] as Color;
    final activeNote = tank['activeNote'] as Map<String, dynamic>?;
    final noteText = activeNote == null
        ? null
        : _shortNoteText((activeNote['text'] ?? '').toString());
    final noteAuthor = activeNote == null
        ? null
        : (activeNote['updatedByEmail'] ??
                activeNote['createdByEmail'] ??
                'ukjent')
            .toString();
    final noteTimestamp = activeNote?['updatedAt'] ?? activeNote?['createdAt'];

    return TankOverviewCard(
      name: tank['name'].toString(),
      isActive: isActive,
      fishCountLabel: isActive ? '${_formatFish(fishCount)} stk' : '0 stk',
      biomassLabel: isActive ? _formatBiomass(biomassKg) : 'Ikke i bruk',
      weightLabel: !isActive
          ? 'Ingen'
          : latestWeight > 0
              ? '${_formatDecimal(latestWeight)} g'
              : 'Ingen data',
      feedLabel: !isActive ? 'Ingen' : '${_formatDecimal(feedKgLast24h)} kg',
      mortalityLabel: !isActive ? 'Ingen' : '$mortality7d stk',
      temperatureLabel: !isActive
          ? 'Ingen'
          : latestTemperature > 0
              ? '${_formatDecimal(latestTemperature)} °C'
              : 'Ingen data',
      statusLabel: _statusLabel(statusLevel),
      statusMessage: _statusMessage(
        level: statusLevel,
        statusText: statusText,
        mortality7d: mortality7d,
      ),
      statusColor: statusColor,
      statusIcon: tank['statusIcon'] as IconData,
      noteText: noteText,
      noteMeta: noteText == null
          ? null
          : '$noteAuthor · ${_formatNoteDate(noteTimestamp)}',
      notesUnavailable: tank['notesUnavailable'] as bool? ?? false,
      onNoteTap: activeNote == null
          ? null
          : () => _showNoteDialog(context, activeNote),
      onDelete: isAdmin
          ? () => _confirmDeleteTank(
                context,
                tank['id'].toString(),
                tank['name'].toString(),
              )
          : null,
      onTap: () => _openTank(context, tank),
    );
  }
}

class _TankOverviewContent extends StatefulWidget {
  const _TankOverviewContent({
    required this.sectionName,
    required this.tanks,
    required this.isAdmin,
    required this.onAddTank,
    required this.cardBuilder,
  });

  final String sectionName;
  final List<Map<String, dynamic>> tanks;
  final bool isAdmin;
  final VoidCallback onAddTank;
  final Widget Function(Map<String, dynamic> tank) cardBuilder;

  @override
  State<_TankOverviewContent> createState() => _TankOverviewContentState();
}

class _TankOverviewContentState extends State<_TankOverviewContent> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _count(String level) {
    return widget.tanks.where((tank) => tank['statusLevel'] == level).length;
  }

  bool _matchesFilter(Map<String, dynamic> tank) {
    final query = _searchController.text.trim().toLowerCase();
    final matchesSearch =
        query.isEmpty || tank['name'].toString().toLowerCase().contains(query);
    final matchesStatus = _selectedFilter == 'all' ||
        tank['statusLevel'].toString() == _selectedFilter;
    return matchesSearch && matchesStatus;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final pagePadding = isWide ? 24.0 : 16.0;
        final filteredTanks = widget.tanks.where(_matchesFilter).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pagePadding,
            isWide ? 24 : 18,
            pagePadding,
            40,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OverviewHeader(
                    sectionName: widget.sectionName,
                    searchController: _searchController,
                    isWide: isWide,
                    isAdmin: widget.isAdmin,
                    onSearchChanged: (_) => setState(() {}),
                    onAddTank: widget.onAddTank,
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatusFilterButton(
                          label: 'Alle kar',
                          count: widget.tanks.length,
                          selected: _selectedFilter == 'all',
                          onTap: () => setState(() => _selectedFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _StatusFilterButton(
                          label: 'Aktive',
                          count: _count('active'),
                          color: const Color(0xFF0BA765),
                          selected: _selectedFilter == 'active',
                          onTap: () =>
                              setState(() => _selectedFilter = 'active'),
                        ),
                        const SizedBox(width: 8),
                        _StatusFilterButton(
                          label: 'Observasjon',
                          count: _count('observation'),
                          color: const Color(0xFFE49600),
                          selected: _selectedFilter == 'observation',
                          onTap: () =>
                              setState(() => _selectedFilter = 'observation'),
                        ),
                        const SizedBox(width: 8),
                        _StatusFilterButton(
                          label: 'Kritiske',
                          count: _count('critical'),
                          color: const Color(0xFFD53C3C),
                          selected: _selectedFilter == 'critical',
                          onTap: () =>
                              setState(() => _selectedFilter = 'critical'),
                        ),
                        const SizedBox(width: 8),
                        _StatusFilterButton(
                          label: 'Tomme kar',
                          count: _count('empty'),
                          color: const Color(0xFF7F8997),
                          selected: _selectedFilter == 'empty',
                          onTap: () =>
                              setState(() => _selectedFilter = 'empty'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (filteredTanks.isEmpty)
                    const _NoMatchingTanks()
                  else
                    _ResponsiveTankGrid(
                      tanks: filteredTanks,
                      cardBuilder: widget.cardBuilder,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.sectionName,
    required this.searchController,
    required this.isWide,
    required this.isAdmin,
    required this.onSearchChanged,
    required this.onAddTank,
  });

  final String sectionName;
  final TextEditingController searchController;
  final bool isWide;
  final bool isAdmin;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddTank;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Karoversikt · $sectionName',
          style: TextStyle(
            color: const Color(0xFF0A1733),
            fontSize: isWide ? 28 : 24,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Oversikt og siste nøkkeltall for alle kar i seksjonen.',
          style: TextStyle(
            color: Color(0xFF5F7088),
            fontSize: 14,
          ),
        ),
      ],
    );

    final search = SizedBox(
      width: isWide ? 300 : double.infinity,
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        decoration: const InputDecoration(
          hintText: 'Søk etter kar...',
          prefixIcon: Icon(Icons.search),
        ),
      ),
    );

    final addButton = isAdmin
        ? FilledButton.icon(
            onPressed: onAddTank,
            icon: const Icon(Icons.add),
            label: const Text('Nytt kar'),
          )
        : null;

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          const SizedBox(height: 16),
          search,
          if (addButton != null) ...[
            const SizedBox(height: 10),
            addButton,
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        search,
        if (addButton != null) ...[
          const SizedBox(width: 10),
          addButton,
        ],
      ],
    );
  }
}

class _StatusFilterButton extends StatelessWidget {
  const _StatusFilterButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.color = const Color(0xFF0B63E5),
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : const Color(0xFF41536D);

    return Material(
      color: selected ? const Color(0xFF0B63E5) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? const Color(0xFF0B63E5) : const Color(0xFFDCE5EF),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!selected) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveTankGrid extends StatelessWidget {
  const _ResponsiveTankGrid({
    required this.tanks,
    required this.cardBuilder,
  });

  final List<Map<String, dynamic>> tanks;
  final Widget Function(Map<String, dynamic> tank) cardBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 720
                ? 2
                : 1;
        const spacing = 14.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tank in tanks)
              SizedBox(width: cardWidth, child: cardBuilder(tank)),
          ],
        );
      },
    );
  }
}

class _NoMatchingTanks extends StatelessWidget {
  const _NoMatchingTanks();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE5EF)),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off, size: 34, color: Color(0xFF7F8997)),
          SizedBox(height: 10),
          Text(
            'Ingen kar passer med valgt søk eller filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF41536D),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
