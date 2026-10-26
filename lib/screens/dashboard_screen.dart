import '../utils/data_values.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/language_controller.dart';
import '../l10n/localizations.dart';
import '../services/excel_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../services/web_update_guard.dart';
import '../models/app_notification.dart';
import '../utils/tank_status.dart';
import '../utils/ui_motion.dart';
import '../widgets/dashboard_v3_widgets.dart';
import '../widgets/diary_log_panel.dart';
import '../widgets/notification_center.dart';
import 'admin_users_screen.dart';
import 'feed_inventory_screen.dart';
import 'production_report_screen.dart';
import 'section_screen.dart';
import 'tank_screen.dart';

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
  late Stream<List<AppNotification>> _notificationStream;
  StreamSubscription<List<AppNotification>>? _notificationSubscription;
  List<AppNotification> _latestNotifications = const <AppNotification>[];
  bool _isRefreshing = false;
  int _diaryRefreshKey = 0;
  Timer? _webUpdateTimer;

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
    // The bell and sheet can listen at the same time. Keep the last value so a
    // newly opened sheet does not wait for the next Firestore event.
    _notificationStream =
        NotificationService.notificationsStream().asBroadcastStream();
    _notificationSubscription = _notificationStream.listen(
      (notifications) {
        if (mounted) {
          setState(() => _latestNotifications = notifications);
        }
      },
    );
    unawaited(_syncNotifications());
    _webUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _syncWebUpdateNotification(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _notificationSubscription?.cancel();
    _webUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _exportExcel() async {
    try {
      await ExcelService.exportFacility(
        facilityId: widget.facilityId,
        facilityName: widget.facilityName,
        labels: context.l10n,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.excelExportComplete)),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Fjellfisk Excel export error: $error\n$stackTrace');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.excelExportFailed)),
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
    CollectionReference<Map<String, dynamic>> logsRef, {
    required bool forceServer,
  }) async {
    final snap = await _getQuery(
      logsRef.orderBy('date', descending: true).limit(50),
      forceServer: forceServer,
    );
    for (final doc in snap.docs) {
      final weight = _weightFromLog(doc.data());
      if (weight > 0) return weight;
    }
    return 0;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getQuery(
    Query<Map<String, dynamic>> query, {
    required bool forceServer,
  }) async {
    if (!forceServer) return query.get();

    try {
      return await query.get(const GetOptions(source: Source.server));
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable' &&
          error.code != 'deadline-exceeded' &&
          error.code != 'network-request-failed') {
        rethrow;
      }
      return query.get(const GetOptions(source: Source.cache));
    }
  }

  double _toDouble(Object? value) => DataValues.decimal(value);

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

  Future<Map<String, dynamic>> _loadDashboard(
      {bool forceServer = false}) async {
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

    final sectionsSnap = await _getQuery(
      _sectionsRef,
      forceServer: forceServer,
    );
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

      final tanksSnap = await _getQuery(
        section.reference.collection('tanks'),
        forceServer: forceServer,
      );
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

        final latestWeight = await _latestWeight(
          logsRef,
          forceServer: forceServer,
        );
        final biomass = _biomassKg(fishCount, latestWeight);
        final dailyFeed = biomass * (_feedPercent(latestWeight) / 100);
        sectionBiomassKg += biomass;
        sectionFeedKg += dailyFeed;
        totalBiomassKg += biomass;
        recommendedFeedKg += dailyFeed;

        final logsSnap = await _getQuery(
          logsRef,
          forceServer: forceServer,
        );
        for (final log in logsSnap.docs) {
          final data = log.data();
          final dateRaw = data['date'];
          final date = dateRaw is Timestamp ? dateRaw.toDate() : null;
          if (date != null &&
              !date.isBefore(startOfToday) &&
              !date.isAfter(now)) {
            final mortality = data['mortality'] ?? data['dead'] ?? 0;
            final feed = data['feedKg'] ?? 0;
            mortalityToday += DataValues.integer(mortality);
            feedTodayKg += DataValues.decimal(feed);
          }

          final temp = DataValues.decimal(data['temperature']);
          if (temp > 0 &&
              date != null &&
              !date.isAfter(now) &&
              !date.isBefore(now.subtract(const Duration(hours: 24)))) {
            tempSum += temp;
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

  Future<void> _refresh({bool showFeedback = false}) async {
    if (_isRefreshing) return;

    final future = _loadDashboard(forceServer: true).timeout(_loadTimeout);
    setState(() {
      _isRefreshing = true;
      _diaryRefreshKey++;
      _dashboardFuture = future;
      _roleFuture = UserService.getCurrentUserRole();
    });
    try {
      await future;
      unawaited(_syncNotifications());
      if (!mounted || !showFeedback) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.dashboardUpdated)),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Fjellfisk dashboard refresh error: $error\n$stackTrace');
      }
      // FutureBuilder shows a local retry state.
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _refreshFromUser() => _refresh(showFeedback: true);

  Future<void> _changeLanguage(AppLanguage language) async {
    try {
      await LanguageScope.of(context).select(language);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
            'Fjellfisk språkvalg kunne ikke lagres: $error\n$stackTrace');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.languageSaveFailed)),
      );
    }
  }

  Future<void> _syncNotifications() async {
    await NotificationService.syncOperationalNotifications(
      facilityId: widget.facilityId,
    );
    await _syncWebUpdateNotification();
  }

  Future<void> _syncWebUpdateNotification() {
    final buildId = webUpdateAvailableBuild();
    if (buildId == null || buildId.isEmpty) return Future.value();
    return NotificationService.syncWebUpdateNotification(
      facilityId: widget.facilityId,
      buildId: buildId,
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logoutQuestion),
        content: Text(context.l10n.logoutConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.logout),
            label: Text(context.l10n.logout),
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

  Future<void> _openNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Align(
        alignment: Alignment.bottomCenter,
        child: NotificationCenterSheet(
          notifications: _notificationStream,
          initialNotifications: _latestNotifications,
          onMarkRead: NotificationService.markRead,
          onMarkAllRead: NotificationService.markAllRead,
          onOpen: _openNotificationTarget,
        ),
      ),
    );
  }

  Future<void> _openNotificationTarget(AppNotification notification) async {
    switch (notification.type) {
      case AppNotificationType.highMortality:
      case AppNotificationType.tankNote:
        await _openTankFromNotification(notification);
      case AppNotificationType.lowFeedStock:
        _openFeedInventory();
      case AppNotificationType.diaryEntry:
        _scrollToDiary();
      case AppNotificationType.appUpdate:
        requestWebUpdate();
    }
  }

  Future<void> _openTankFromNotification(
    AppNotification notification,
  ) async {
    final tankUnavailable = context.l10n.tankUnavailable;
    if (notification.sectionId.isEmpty || notification.tankId.isEmpty) {
      _showNotificationNavigationError();
      return;
    }

    try {
      final tank = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(widget.facilityId)
          .collection('sections')
          .doc(notification.sectionId)
          .collection('tanks')
          .doc(notification.tankId)
          .get();
      if (!tank.exists) {
        _showNotificationNavigationError(
          tankUnavailable,
        );
        return;
      }
      if (!mounted) return;
      final data = tank.data() ?? const <String, dynamic>{};
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => TankScreen(
            facilityId: widget.facilityId,
            sectionId: notification.sectionId,
            tankId: notification.tankId,
            tankName: (data['name'] ?? notification.tankName).toString(),
            fishCount: TankStatus.fishCountFrom(data['fishCount']),
          ),
        ),
      );
      if (mounted) _refresh();
    } on FirebaseException catch (error) {
      if (kDebugMode) {
        debugPrint('Fjellfisk varsel-navigering: ${error.code} $error');
      }
      _showNotificationNavigationError();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Fjellfisk varsel-navigering: $error\n$stackTrace');
      }
      _showNotificationNavigationError();
    }
  }

  void _showNotificationNavigationError([String? message]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? context.l10n.contentUnavailable)));
  }

  void _openSection(Map<String, dynamic> section) {
    Navigator.push(
      context,
      subtleFadeSlideRoute(
        context: context,
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

  String _decimal(num value, [int digits = 1]) =>
      NumberFormat.decimalPatternDigits(
        locale: LanguageScope.of(context).language.code,
        decimalDigits: digits,
      ).format(value);

  String _biomassLabel(double biomassKg) {
    if (biomassKg >= 1000) {
      return '${_decimal(biomassKg / 1000, 2)} tonn';
    }
    return '${_decimal(biomassKg)} kg';
  }

  String _dashboardErrorMessage(Object? error) {
    if (error is TimeoutException) {
      return context.l10n.dashboardLoadTimeout;
    }
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return context.l10n.dashboardPermissionDenied;
      }
      if (error.code == 'unavailable') {
        return context.l10n.dashboardUnavailable;
      }
    }
    return context.l10n.dashboardLoadFailed;
  }

  @override
  Widget build(BuildContext context) {
    final userLabel =
        FirebaseAuth.instance.currentUser?.email ?? context.l10n.signedInUser;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1080;
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: DashboardTopBar(
            facilityName: widget.facilityName,
            userLabel: userLabel,
            isDesktop: isDesktop,
            isRefreshing: _isRefreshing,
            notificationStream: _notificationStream,
            onNotifications: _openNotifications,
            language: LanguageScope.of(context).language,
            onLanguageChanged: _changeLanguage,
            onRefresh: _refreshFromUser,
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
                        onRetry: _refreshFromUser,
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
    final l10n = context.l10n;
    final sectionRows = data['sectionRows'] as List<Map<String, dynamic>>;
    final biomassKg = data['biomassKg'] as double;
    final recommendedFeedKg = data['recommendedFeedKg'] as double;
    final feedTodayKg = data['feedTodayKg'] as double;
    final avgTemp = data['avgTemp'] as double;

    return RefreshIndicator(
      onRefresh: _refreshFromUser,
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
                    isRefreshing: _isRefreshing,
                    onRefresh: _refreshFromUser,
                  ),
                  const SizedBox(height: 20),
                  ResponsiveDashboardGrid(
                    minItemWidth: 190,
                    children: [
                      DashboardKpiCard(
                        title: l10n.activeTanks,
                        value: '${data['activeTanks']}',
                        detail: l10n.tanksOfTotal(data['tanks'] as int),
                        note: l10n.emptyTanks(data['emptyTanks'] as int),
                        icon: Icons.radar,
                        accent: const Color(0xFF0B63E5),
                      ),
                      DashboardKpiCard(
                        title: l10n.biomass,
                        value: _biomassLabel(biomassKg),
                        detail: l10n.fishCount(data['fish'] as int),
                        note: l10n.activeBiomass,
                        icon: Icons.scale_outlined,
                        accent: const Color(0xFF15945C),
                      ),
                      DashboardKpiCard(
                        title: l10n.feedToday,
                        value: '${_decimal(feedTodayKg)} kg',
                        detail: l10n.actualRecorded,
                        note: l10n.recommendedFeed(_decimal(recommendedFeedKg)),
                        icon: Icons.set_meal_outlined,
                        accent: const Color(0xFF6C55C7),
                      ),
                      DashboardKpiCard(
                        title: l10n.deadToday,
                        value: '${data['mortalityToday']}',
                        detail: l10n.recordedMortality,
                        note: data['mortalityToday'] == 0
                            ? l10n.noneRecordedToday
                            : l10n.numberOfFish,
                        icon: Icons.warning_amber_rounded,
                        accent: const Color(0xFFD43838),
                      ),
                      DashboardKpiCard(
                        title: l10n.averageTemperature,
                        value: avgTemp > 0
                            ? '${_decimal(avgTemp)} °C'
                            : l10n.noData,
                        detail: l10n.recordedMeasurements,
                        note: avgTemp > 0
                            ? l10n.updatedFromTankLogs
                            : l10n.notEnoughData,
                        icon: Icons.device_thermostat,
                        accent: const Color(0xFF1678D2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  KeyedSubtree(
                    key: _diaryKey,
                    child: DiaryLogPanel(
                      key: ValueKey(_diaryRefreshKey),
                      facilityId: widget.facilityId,
                      facilityName: widget.facilityName,
                    ),
                  ),
                  const SizedBox(height: 26),
                  DashboardSectionHeading(
                    title: l10n.buildings,
                    subtitle: l10n.sectionsWithTanks(
                      data['sections'] as int,
                      data['tanks'] as int,
                    ),
                    action: IconButton.outlined(
                      tooltip: l10n.exportFacilityToExcel,
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
                  DashboardSectionHeading(
                    title: l10n.operationalTools,
                    subtitle: l10n.operationalToolsSubtitle,
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
    final l10n = context.l10n;
    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, snapshot) {
        final actions = <Widget>[
          DashboardActionCard(
            title: l10n.productionReport,
            subtitle: l10n.reportSubtitle,
            icon: Icons.summarize_outlined,
            onTap: _openProductionReport,
          ),
          DashboardActionCard(
            title: l10n.feedInventory,
            subtitle: l10n.feedInventorySubtitle,
            icon: Icons.inventory_2_outlined,
            onTap: _openFeedInventory,
          ),
          DashboardActionCard(
            title: l10n.excelExport,
            subtitle: l10n.excelSubtitle,
            icon: Icons.download_outlined,
            onTap: _exportExcel,
          ),
        ];
        if (snapshot.data == 'admin') {
          actions.add(
            DashboardActionCard(
              title: l10n.usersAndAccess,
              subtitle: l10n.accessSubtitle,
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
