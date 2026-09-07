import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/excel_service.dart';
import '../services/user_service.dart';
import '../utils/tank_status.dart';
import '../widgets/dashboard_v3_widgets.dart';
import '../widgets/diary_log_panel.dart';
import 'admin_users_screen.dart';
import 'feed_inventory_screen.dart';
import 'production_report_screen.dart';
import 'section_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const DashboardScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Duration _loadTimeout = Duration(seconds: 25);

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _diaryKey = GlobalKey();
  late Future<Map<String, dynamic>> _dashboardFuture;
  late Future<String> _roleFuture;

  CollectionReference<Map<String, dynamic>> get _sectionsRef {
    return FirebaseFirestore.instance
        .collection('facilities')
        .doc(widget.facilityId)
        .collection('sections');
  }

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard().timeout(_loadTimeout);
    _roleFuture = UserService.getCurrentUserRole();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _exportExcel() async {
    try {
      await ExcelService.exportFacility(
        facilityId: widget.facilityId,
        facilityName: widget.facilityName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel eksport fullført')),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Fjellfisk Excel export error: $error\n$stackTrace');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kunne ikke eksportere Excel. Prøv igjen.'),
        ),
      );
    }
  }

  double _biomassKg(int fishCount, double avgWeightGram) {
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

  Future<double> _latestWeight(
    CollectionReference<Map<String, dynamic>> logsRef,
  ) async {
    final snap =
        await logsRef.orderBy('date', descending: true).limit(50).get();
    for (final doc in snap.docs) {
      final weight = _weightFromLog(doc.data());
      if (weight > 0) return weight;
    }
    return 0;
  }

  double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
    }
    return 0;
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

  Future<Map<String, dynamic>> _loadDashboard() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    int totalSections = 0;
    int totalTanks = 0;
    int activeTanks = 0;
    int emptyTanks = 0;
    int totalFish = 0;
    int mortalityToday = 0;
    double totalBiomassKg = 0;
    double recommendedFeedKg = 0;
    double feedTodayKg = 0;
    double tempSum = 0;
    int tempCount = 0;
    final sectionRows = <Map<String, dynamic>>[];

    final sectionsSnap = await _sectionsRef.get();
    totalSections = sectionsSnap.docs.length;

    for (final section in sectionsSnap.docs) {
      final sectionData = section.data();
      final sectionName = (sectionData['name'] ?? section.id).toString();
      int sectionTanks = 0;
      int sectionActiveTanks = 0;
      int sectionEmptyTanks = 0;
      int sectionFish = 0;
      double sectionBiomassKg = 0;
      double sectionFeedKg = 0;

      final tanksSnap = await section.reference.collection('tanks').get();
      sectionTanks = tanksSnap.docs.length;
      totalTanks += sectionTanks;

      for (final tank in tanksSnap.docs) {
        final tankData = tank.data();
        final fishCount = TankStatus.fishCountFrom(tankData['fishCount']);
        final isActive = TankStatus.isActiveFishCount(fishCount);

        if (isActive) {
          sectionActiveTanks++;
          activeTanks++;
          sectionFish += fishCount;
          totalFish += fishCount;
        } else {
          sectionEmptyTanks++;
          emptyTanks++;
        }

        final logsRef = tank.reference.collection('logs');
        if (!isActive) continue;

        final latestWeight = await _latestWeight(logsRef);
        final biomass = _biomassKg(fishCount, latestWeight);
        final dailyFeed = biomass * (_feedPercent(latestWeight) / 100);
        sectionBiomassKg += biomass;
        sectionFeedKg += dailyFeed;
        totalBiomassKg += biomass;
        recommendedFeedKg += dailyFeed;

        final logsSnap = await logsRef.get();
        for (final log in logsSnap.docs) {
          final data = log.data();
          final dateRaw = data['date'];
          final date = dateRaw is Timestamp ? dateRaw.toDate() : null;
          if (date != null &&
              !date.isBefore(startOfToday) &&
              !date.isAfter(now)) {
            final mortality = data['mortality'] ?? data['dead'] ?? 0;
            final feed = data['feedKg'] ?? 0;
            if (mortality is num) mortalityToday += mortality.toInt();
            if (feed is num) feedTodayKg += feed.toDouble();
          }

          final temp = data['temperature'];
          if (temp is num && temp > 0) {
            tempSum += temp.toDouble();
            tempCount++;
          }
        }
      }

      sectionRows.add({
        'id': section.id,
        'name': sectionName,
        'tanks': sectionTanks,
        'activeTanks': sectionActiveTanks,
        'emptyTanks': sectionEmptyTanks,
        'fish': sectionFish,
        'biomassKg': sectionBiomassKg,
        'recommendedFeedKg': sectionFeedKg,
      });
    }

    return {
      'sections': totalSections,
      'tanks': totalTanks,
      'activeTanks': activeTanks,
      'emptyTanks': emptyTanks,
      'fish': totalFish,
      'biomassKg': totalBiomassKg,
      'recommendedFeedKg': recommendedFeedKg,
      'mortalityToday': mortalityToday,
      'feedTodayKg': feedTodayKg,
      'avgTemp': tempCount == 0 ? 0.0 : tempSum / tempCount,
      'sectionRows': sectionRows,
    };
  }

  Future<void> _refresh() async {
    final future = _loadDashboard().timeout(_loadTimeout);
    setState(() {
      _dashboardFuture = future;
      _roleFuture = UserService.getCurrentUserRole();
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder shows a local retry state.
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logg ut?'),
        content: const Text('Er du sikker på at du vil logge ut?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Logg ut'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openFeedInventory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FeedInventoryScreen()),
    ).then((_) => _refresh());
  }

  void _openProductionReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductionReportScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
        ),
      ),
    ).then((_) => _refresh());
  }

  void _openAdminUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
    ).then((_) => _refresh());
  }

  void _openSection(Map<String, dynamic> section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionScreen(
          facilityId: widget.facilityId,
          sectionId: section['id'].toString(),
          sectionName: section['name'].toString(),
        ),
      ),
    ).then((_) => _refresh());
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToDiary() {
    final diaryContext = _diaryKey.currentContext;
    if (diaryContext == null) return;
    Scrollable.ensureVisible(
      diaryContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      alignment: 0.04,
    );
  }

  String _decimal(num value, [int digits = 1]) {
    return value.toStringAsFixed(digits).replaceAll('.', ',');
  }

  String _biomassLabel(double biomassKg) {
    if (biomassKg >= 1000) {
      return '${_decimal(biomassKg / 1000, 2)} tonn';
    }
    return '${_decimal(biomassKg)} kg';
  }

  String _dashboardErrorMessage(Object? error) {
    if (error is TimeoutException) {
      return 'Det tok for lang tid å hente driftsdata. Kontroller nettet og prøv igjen.';
    }
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Brukeren mangler tilgang til driftsdata. Kontakt administrator.';
      }
      if (error.code == 'unavailable') {
        return 'Driftsdata er midlertidig utilgjengelige. Kontroller nettet og prøv igjen.';
      }
    }
    return 'Dashboardet kunne ikke lastes akkurat nå. Prøv igjen.';
  }

  @override
  Widget build(BuildContext context) {
    final userLabel =
        FirebaseAuth.instance.currentUser?.email ?? 'Innlogget bruker';
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1080;
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: DashboardTopBar(
            facilityName: widget.facilityName,
            userLabel: userLabel,
            isDesktop: isDesktop,
            onRefresh: _refresh,
            onLogout: _logout,
          ),
          drawer: isDesktop
              ? null
              : Drawer(
                  child: SafeArea(
                    child: _navigation(userLabel, closeDrawer: true),
                  ),
                ),
          body: Row(
            children: [
              if (isDesktop)
                SizedBox(width: 238, child: _navigation(userLabel)),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _dashboardFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      if (kDebugMode) {
                        debugPrint(
                          'Fjellfisk dashboard load error: ${snapshot.error}',
                        );
                      }
                      return DashboardErrorState(
                        message: _dashboardErrorMessage(snapshot.error),
                        onRetry: _refresh,
                      );
                    }
                    if (!snapshot.hasData) {
                      return const DashboardLoadingState();
                    }
                    return _dashboardContent(snapshot.data!);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _navigation(String userLabel, {bool closeDrawer = false}) {
    return DashboardNavigation(
      facilityName: widget.facilityName,
      userLabel: userLabel,
      roleFuture: _roleFuture,
      closeDrawerOnSelect: closeDrawer,
      onDashboard: _scrollToTop,
      onDiary: _scrollToDiary,
      onReport: _openProductionReport,
      onFeedInventory: _openFeedInventory,
      onAdminUsers: _openAdminUsers,
      onExport: _exportExcel,
      onLogout: _logout,
    );
  }

  Widget _dashboardContent(Map<String, dynamic> data) {
    final sectionRows = data['sectionRows'] as List<Map<String, dynamic>>;
    final biomassKg = data['biomassKg'] as double;
    final recommendedFeedKg = data['recommendedFeedKg'] as double;
    final feedTodayKg = data['feedTodayKg'] as double;
    final avgTemp = data['avgTemp'] as double;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: MediaQuery.sizeOf(context).width >= 1080,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardHeading(
                    facilityName: widget.facilityName,
                    onRefresh: _refresh,
                  ),
                  const SizedBox(height: 20),
                  ResponsiveDashboardGrid(
                    minItemWidth: 190,
                    children: [
                      DashboardKpiCard(
                        title: 'Aktive kar',
                        value: '${data['activeTanks']}',
                        detail: 'av ${data['tanks']} kar',
                        note: '${data['emptyTanks']} tomme kar',
                        icon: Icons.radar,
                        accent: const Color(0xFF0B63E5),
                      ),
                      DashboardKpiCard(
                        title: 'Biomasse',
                        value: _biomassLabel(biomassKg),
                        detail: '${data['fish']} fisk',
                        note: 'Aktiv biomasse',
                        icon: Icons.scale_outlined,
                        accent: const Color(0xFF15945C),
                      ),
                      DashboardKpiCard(
                        title: 'Fôr i dag',
                        value: '${_decimal(feedTodayKg)} kg',
                        detail: 'Faktisk registrert',
                        note: 'Anbefalt ${_decimal(recommendedFeedKg)} kg',
                        icon: Icons.set_meal_outlined,
                        accent: const Color(0xFF6C55C7),
                      ),
                      DashboardKpiCard(
                        title: 'Døde i dag',
                        value: '${data['mortalityToday']}',
                        detail: 'Registrert dødelighet',
                        note: data['mortalityToday'] == 0
                            ? 'Ingen registrert i dag'
                            : 'Antall fisk',
                        icon: Icons.warning_amber_rounded,
                        accent: const Color(0xFFD43838),
                      ),
                      DashboardKpiCard(
                        title: 'Snittemperatur',
                        value: avgTemp > 0
                            ? '${_decimal(avgTemp)} °C'
                            : 'Ingen data',
                        detail: 'Registrerte målinger',
                        note: avgTemp > 0
                            ? 'Oppdatert fra karlogger'
                            : 'Ikke nok data',
                        icon: Icons.device_thermostat,
                        accent: const Color(0xFF1678D2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  KeyedSubtree(
                    key: _diaryKey,
                    child: DiaryLogPanel(
                      facilityId: widget.facilityId,
                      facilityName: widget.facilityName,
                    ),
                  ),
                  const SizedBox(height: 26),
                  DashboardSectionHeading(
                    title: 'Bygg',
                    subtitle:
                        '${data['sections']} seksjoner med ${data['tanks']} kar',
                    action: IconButton.outlined(
                      tooltip: 'Eksporter anlegget til Excel',
                      onPressed: _exportExcel,
                      icon: const Icon(Icons.download_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (sectionRows.isEmpty)
                    const DashboardEmptySections()
                  else
                    ResponsiveDashboardGrid(
                      minItemWidth: 290,
                      children: sectionRows.map((section) {
                        return DashboardSectionCard(
                          name: section['name'].toString(),
                          activeTanks: section['activeTanks'] as int,
                          emptyTanks: section['emptyTanks'] as int,
                          fishCount: section['fish'] as int,
                          biomassLabel: _biomassLabel(
                            section['biomassKg'] as double,
                          ),
                          feedLabel:
                              '${_decimal(section['recommendedFeedKg'] as double)} kg',
                          onTap: () => _openSection(section),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 28),
                  const DashboardSectionHeading(
                    title: 'Driftsverktøy',
                    subtitle: 'Rapporter, lager og administrasjon',
                  ),
                  const SizedBox(height: 12),
                  _actionGrid(),
                  const SizedBox(height: 28),
                  const Center(
                    child: Text(
                      'Fjellfisk 3.0',
                      style: TextStyle(
                        color: Color(0xFF7A8AA0),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionGrid() {
    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, snapshot) {
        final actions = <Widget>[
          DashboardActionCard(
            title: 'Produksjonsrapport',
            subtitle: 'Se nøkkeltall for valgt periode',
            icon: Icons.summarize_outlined,
            onTap: _openProductionReport,
          ),
          DashboardActionCard(
            title: 'Fôrlager',
            subtitle: 'Se beholdning og lagerhistorikk',
            icon: Icons.inventory_2_outlined,
            onTap: _openFeedInventory,
          ),
          DashboardActionCard(
            title: 'Excel-eksport',
            subtitle: 'Eksporter komplett anleggsoversikt',
            icon: Icons.download_outlined,
            onTap: _exportExcel,
          ),
        ];
        if (snapshot.data == 'admin') {
          actions.add(
            DashboardActionCard(
              title: 'Brukere & Tilganger',
              subtitle: 'Endre roller og tilgang',
              icon: Icons.admin_panel_settings_outlined,
              onTap: _openAdminUsers,
            ),
          );
        }
        return ResponsiveDashboardGrid(
          minItemWidth: 260,
          children: actions,
        );
      },
    );
  }
}
