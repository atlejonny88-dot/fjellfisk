import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/language_controller.dart';
import '../l10n/localizations.dart';
import '../services/excel_service.dart';
import '../services/addon_service.dart';
import '../services/collector_claim_service.dart';
import '../services/dashboard_temperature_service.dart';
import '../services/dashboard_snapshot_cache.dart';
import '../services/dashboard_production_data_service.dart';
import '../services/notification_service.dart';
import '../services/remote_addon_service.dart';
import '../services/user_service.dart';
import '../services/web_update_guard.dart';
import '../models/app_notification.dart';
import '../utils/tank_status.dart';
import '../utils/ui_motion.dart';
import '../widgets/dashboard_v3_widgets.dart';
import '../widgets/dashboard_temperature_kpi.dart';
import '../widgets/dashboard_refresh_warning.dart';
import '../widgets/diary_log_panel.dart';
import '../widgets/notification_center.dart';
import 'admin_users_screen.dart';
import 'addons_screen.dart';
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
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _diaryKey = GlobalKey();
  late Future<Map<String, dynamic>> _dashboardFuture;
  final DashboardSnapshotCache<Map<String, dynamic>> _dashboardCache =
      DashboardSnapshotCache<Map<String, dynamic>>();
  late Future<String> _roleFuture;
  late Stream<List<AppNotification>> _notificationStream;
  StreamSubscription<List<AppNotification>>? _notificationSubscription;
  List<AppNotification> _latestNotifications = const <AppNotification>[];
  bool _isRefreshing = false;
  int _diaryRefreshKey = 0;
  Timer? _webUpdateTimer;
  Timer? _sensorRefresh;
  late final AddOnService _addOnService;
  CollectorClaimService? _collectorApi;
  late final DashboardTemperatureConfigurationStore _temperatureStore;
  late final DashboardProductionDataService _dashboardDataService;

  @override
  void initState() {
    super.initState();
    _dashboardDataService = DashboardProductionDataService(
      source: FirestoreDashboardProductionDataSource(
        FirebaseFirestore.instance,
      ),
    );
    _dashboardFuture = _loadDashboardAndCache();
    _roleFuture = UserService.getCurrentUserRole();
    _temperatureStore = FirestoreDashboardTemperatureConfigurationStore();
    _collectorApi = CollectorClaimService.fromEnvironment();
    _addOnService = _collectorApi!.isConfigured
        ? RemoteAddOnService(
            api: _collectorApi!,
            facilityId: widget.facilityId,
          )
        : MockAddOnService.shared;
    unawaited(_addOnService.loadSections());
    if (_addOnService is RemoteAddOnService) {
      unawaited(_addOnService.refresh());
      _sensorRefresh = Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(_addOnService.refresh()),
      );
    }
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
    _sensorRefresh?.cancel();
    if (_addOnService is RemoteAddOnService) _addOnService.dispose();
    _collectorApi?.dispose();
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

  Future<Map<String, dynamic>> _loadDashboardAndCache({
    bool forceServer = false,
  }) =>
      _dashboardCache.load(
        () => _dashboardDataService.load(
          facilityId: widget.facilityId,
          forceServer: forceServer,
        ),
      );

  Future<void> _refresh({bool showFeedback = false}) async {
    if (_isRefreshing) return;

    final future = _loadDashboardAndCache(forceServer: true);
    setState(() {
      _isRefreshing = true;
      _diaryRefreshKey++;
      _dashboardCache.clearError();
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
      _logDashboardLoadError(error, stackTrace);
      // A previous complete dashboard remains usable while a temporary
      // network or Firebase error is retried.
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

  void _openAddOns() {
    Navigator.push(
      context,
      subtleFadeSlideRoute<void>(
        context: context,
        builder: (_) => AddOnsScreen(facilityId: widget.facilityId),
      ),
    );
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
    final cause = error is DashboardDataLoadException ? error.cause : error;
    if (cause is TimeoutException) {
      return context.l10n.dashboardLoadTimeout;
    }
    if (cause is FirebaseException) {
      if (cause.code == 'permission-denied') {
        return context.l10n.dashboardPermissionDenied;
      }
      if (cause.code == 'unavailable') {
        return context.l10n.dashboardUnavailable;
      }
    }
    return context.l10n.dashboardLoadFailed;
  }

  void _logDashboardLoadError(Object error, [StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    if (error is DashboardDataLoadException) {
      debugPrint(
        'Fjellfisk dashboard read failed '
        'operation=${error.operation.name} '
        'category=${error.category} '
        'durationMs=${error.elapsed.inMilliseconds}',
      );
      return;
    }
    debugPrint('Fjellfisk dashboard refresh error: $error\n$stackTrace');
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
                    final dashboard = _dashboardCache.value ?? snapshot.data;
                    if (snapshot.hasError && dashboard == null) {
                      if (kDebugMode) {
                        _logDashboardLoadError(snapshot.error!);
                      }
                      return DashboardErrorState(
                        message: _dashboardErrorMessage(snapshot.error),
                        onRetry: _refreshFromUser,
                      );
                    }
                    if (dashboard == null) {
                      return const DashboardLoadingState();
                    }
                    return _dashboardContent(
                      dashboard,
                      refreshError: _dashboardCache.lastRefreshError,
                    );
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
      onAddOns: _openAddOns,
      onAdminUsers: _openAdminUsers,
      onExport: _exportExcel,
      onLogout: _logout,
    );
  }

  Widget _dashboardContent(
    Map<String, dynamic> data, {
    Object? refreshError,
  }) {
    final l10n = context.l10n;
    final sectionRows = data['sectionRows'] as List<Map<String, dynamic>>;
    final biomassKg = data['biomassKg'] as double;
    final recommendedFeedKg = data['recommendedFeedKg'] as double;
    final feedTodayKg = data['feedTodayKg'] as double;
    final activeTemperatureTanks =
        data['activeTemperatureTanks'] as Set<DashboardTemperatureTankKey>;

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
                  if (refreshError != null) ...[
                    const SizedBox(height: 12),
                    DashboardRefreshWarning(onRetry: _refreshFromUser),
                  ],
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
                      StreamBuilder<DashboardTemperatureConfiguration>(
                        stream: _temperatureStore.watch(widget.facilityId),
                        builder: (context, snapshot) => DashboardTemperatureKpi(
                          service: _addOnService,
                          facilityId: widget.facilityId,
                          configuration: snapshot.data ??
                              const DashboardTemperatureConfiguration
                                  .unconfigured(),
                          activeTanks: activeTemperatureTanks,
                        ),
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
          DashboardActionCard(
            title: l10n.addOns,
            subtitle: l10n.addOnsSubtitle,
            icon: Icons.extension_outlined,
            onTap: _openAddOns,
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
