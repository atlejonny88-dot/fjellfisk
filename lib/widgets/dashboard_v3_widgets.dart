import 'package:flutter/material.dart';

import '../l10n/language_controller.dart';
import '../l10n/localizations.dart';
import '../models/app_notification.dart';
import '../utils/ui_motion.dart';
import 'notification_center.dart';

class DashboardTopBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardTopBar({
    super.key,
    required this.facilityName,
    required this.userLabel,
    required this.isDesktop,
    this.isRefreshing = false,
    this.notificationStream,
    this.onNotifications,
    this.language = AppLanguage.norwegian,
    this.onLanguageChanged,
    required this.onRefresh,
    required this.onLogout,
  });

  final String facilityName;
  final String userLabel;
  final bool isDesktop;
  final bool isRefreshing;
  final Stream<List<AppNotification>>? notificationStream;
  final VoidCallback? onNotifications;
  final AppLanguage language;
  final ValueChanged<AppLanguage>? onLanguageChanged;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64,
      automaticallyImplyLeading: !isDesktop,
      centerTitle: false,
      backgroundColor: const Color(0xFF082C51),
      foregroundColor: Colors.white,
      elevation: 0,
      shape: const Border(
        bottom: BorderSide(color: Color(0xFF173F64)),
      ),
      titleSpacing: isDesktop ? 28 : 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDesktop) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: const Icon(Icons.terrain, size: 21),
            ),
            const SizedBox(width: 11),
          ],
          Text(
            'Fjellfisk',
            style: TextStyle(
              fontSize: isDesktop ? 22 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '3.0',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: isDesktop ? 17 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        if (isDesktop)
          IconButton(
            tooltip: context.l10n.refreshDashboard,
            onPressed: isRefreshing ? null : onRefresh,
            icon: _RefreshIcon(
              isRefreshing: isRefreshing,
              color: Colors.white,
              size: 20,
            ),
          ),
        if (onLanguageChanged != null)
          _LanguageMenuButton(
            language: language,
            onSelected: onLanguageChanged!,
          ),
        if (onNotifications != null) _notificationsButton(),
        if (isDesktop) ...[
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF315477),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facilityName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  userLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
        if (isDesktop)
          IconButton(
            tooltip: context.l10n.logout,
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _notificationsButton() {
    final callback = onNotifications;
    final stream = notificationStream;
    if (callback == null || stream == null) return const SizedBox.shrink();

    return StreamBuilder<List<AppNotification>>(
      stream: stream,
      builder: (context, snapshot) {
        final unread = snapshot.hasData
            ? snapshot.data!
                .where((notification) => !notification.isRead)
                .length
            : 0;
        return NotificationBell(unreadCount: unread, onPressed: callback);
      },
    );
  }
}

class _RefreshIcon extends StatefulWidget {
  const _RefreshIcon({
    required this.isRefreshing,
    required this.size,
    this.color,
  });

  final bool isRefreshing;
  final double size;
  final Color? color;

  @override
  State<_RefreshIcon> createState() => _RefreshIconState();
}

class _RefreshIconState extends State<_RefreshIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _RefreshIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRefreshing != widget.isRefreshing) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.isRefreshing && !uiMotionDisabled(context)) {
      _controller.repeat();
      return;
    }
    _controller
      ..stop()
      ..value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.refresh, size: widget.size, color: widget.color);
    if (!widget.isRefreshing || uiMotionDisabled(context)) return icon;
    return RotationTransition(turns: _controller, child: icon);
  }
}

class _LanguageMenuButton extends StatelessWidget {
  const _LanguageMenuButton({
    required this.language,
    required this.onSelected,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<AppLanguage>(
      tooltip: l10n.changeLanguage,
      onSelected: onSelected,
      color: Colors.white,
      itemBuilder: (context) => [
        _item(AppLanguage.norwegian, l10n.norwegian),
        _item(AppLanguage.english, 'English'),
        _item(AppLanguage.polish, 'Polski'),
      ],
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: AnimatedSwitcher(
          duration: uiMotionDuration(context),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: Text(
            language.flag,
            key: ValueKey(language.code),
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  PopupMenuEntry<AppLanguage> _item(AppLanguage value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Text(value.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

class DashboardNavigation extends StatelessWidget {
  const DashboardNavigation({
    super.key,
    required this.facilityName,
    required this.userLabel,
    required this.roleFuture,
    required this.onDashboard,
    required this.onDiary,
    required this.onReport,
    required this.onFeedInventory,
    required this.onAdminUsers,
    required this.onExport,
    required this.onLogout,
    this.closeDrawerOnSelect = false,
  });

  final String facilityName;
  final String userLabel;
  final Future<String> roleFuture;
  final VoidCallback onDashboard;
  final VoidCallback onDiary;
  final VoidCallback onReport;
  final VoidCallback onFeedInventory;
  final VoidCallback onAdminUsers;
  final VoidCallback onExport;
  final VoidCallback onLogout;
  final bool closeDrawerOnSelect;

  void _run(BuildContext context, VoidCallback action) {
    if (closeDrawerOnSelect) {
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) => action());
      return;
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DashboardNavLabel(l10n.overview),
                  const SizedBox(height: 7),
                  DashboardNavTile(
                    label: l10n.dashboard,
                    icon: Icons.dashboard_outlined,
                    selected: true,
                    onTap: () => _run(context, onDashboard),
                  ),
                  DashboardNavTile(
                    label: l10n.diary,
                    icon: Icons.menu_book_outlined,
                    onTap: () => _run(context, onDiary),
                  ),
                  const SizedBox(height: 14),
                  DashboardNavLabel(l10n.tools),
                  const SizedBox(height: 7),
                  DashboardNavTile(
                    label: l10n.productionReport,
                    icon: Icons.summarize_outlined,
                    onTap: () => _run(context, onReport),
                  ),
                  DashboardNavTile(
                    label: l10n.feedInventory,
                    icon: Icons.inventory_2_outlined,
                    onTap: () => _run(context, onFeedInventory),
                  ),
                  DashboardNavTile(
                    label: l10n.excelExport,
                    icon: Icons.download_outlined,
                    onTap: () => _run(context, onExport),
                  ),
                  FutureBuilder<String>(
                    future: roleFuture,
                    builder: (context, snapshot) {
                      if (snapshot.data != 'admin') {
                        return const SizedBox.shrink();
                      }
                      return DashboardNavTile(
                        label: l10n.usersAndAccess,
                        icon: Icons.admin_panel_settings_outlined,
                        onTap: () => _run(context, onAdminUsers),
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFFDCE4EE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.facility,
                    style: const TextStyle(
                      color: Color(0xFF687A92),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    facilityName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.user,
                    style: const TextStyle(
                      color: Color(0xFF687A92),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    userLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const Divider(height: 24),
                  TextButton.icon(
                    onPressed: () => _run(context, onLogout),
                    icon: const Icon(Icons.logout),
                    label: Text(l10n.logout),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardNavLabel extends StatelessWidget {
  const DashboardNavLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF8A98AA),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class DashboardNavTile extends StatelessWidget {
  const DashboardNavTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF3FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border(
              left: BorderSide(
                color: selected ? const Color(0xFF0B63E5) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? const Color(0xFF0B63E5)
                    : const Color(0xFF526681),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF0B63E5)
                        : const Color(0xFF34445D),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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

class DashboardHeading extends StatelessWidget {
  const DashboardHeading({
    super.key,
    required this.facilityName,
    this.isRefreshing = false,
    required this.onRefresh,
  });

  final String facilityName;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.dashboard,
              style: const TextStyle(
                color: Color(0xFF0A1733),
                fontSize: 27,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              facilityName,
              style: const TextStyle(
                color: Color(0xFF61718A),
                fontSize: 14,
              ),
            ),
          ],
        );
        if (constraints.maxWidth < 560) return title;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: title),
            OutlinedButton.icon(
              onPressed: isRefreshing ? null : onRefresh,
              icon: _RefreshIcon(
                isRefreshing: isRefreshing,
                size: 18,
              ),
              label: Text(isRefreshing ? l10n.updating : l10n.refresh),
            ),
          ],
        );
      },
    );
  }
}

class ResponsiveDashboardGrid extends StatelessWidget {
  const ResponsiveDashboardGrid({
    super.key,
    required this.children,
    required this.minItemWidth,
    this.spacing = 14,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final rawCount =
            ((constraints.maxWidth + spacing) / (minItemWidth + spacing))
                .floor();
        final columnCount = rawCount.clamp(1, children.length);
        final itemWidth =
            (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class DashboardKpiCard extends StatelessWidget {
  const DashboardKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.detail,
    required this.note,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String detail;
  final String note;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFDCE4EE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF102A43).withValues(alpha: 0.045),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: accent.withValues(alpha: 0.12)),
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF34445D),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: uiMotionDuration(context),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: FittedBox(
              key: ValueKey(value),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFF07142D),
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF65758B), fontSize: 11.5),
          ),
          const SizedBox(height: 3),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardSectionHeading extends StatelessWidget {
  const DashboardSectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0A1733),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF65758B),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class DashboardSectionCard extends StatelessWidget {
  const DashboardSectionCard({
    super.key,
    required this.name,
    required this.activeTanks,
    required this.emptyTanks,
    required this.fishCount,
    required this.biomassLabel,
    required this.feedLabel,
    required this.onTap,
  });

  final String name;
  final int activeTanks;
  final int emptyTanks;
  final int fishCount;
  final String biomassLabel;
  final String feedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: const BorderSide(color: Color(0xFFDCE4EE)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.factory_outlined,
                      size: 21,
                      color: Color(0xFF0B63E5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0A1733),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF61718A)),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 13),
              DashboardSectionMetric(
                label: l10n.tanks,
                value: l10n.activeAndEmptyTanks(activeTanks, emptyTanks),
              ),
              DashboardSectionMetric(label: l10n.fish, value: '$fishCount'),
              DashboardSectionMetric(label: l10n.biomass, value: biomassLabel),
              DashboardSectionMetric(
                label: l10n.recommendedFeedLabel,
                value: feedLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardSectionMetric extends StatelessWidget {
  const DashboardSectionMetric({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF61718A), fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardActionCard extends StatelessWidget {
  const DashboardActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: const BorderSide(color: Color(0xFFDCE4EE)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFF0B63E5),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF61718A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF61718A)),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardEmptySections extends StatelessWidget {
  const DashboardEmptySections({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFDCE4EE)),
      ),
      child: Column(
        children: [
          const Icon(Icons.factory_outlined,
              size: 34, color: Color(0xFF7A8AA0)),
          const SizedBox(height: 9),
          Text(
            '${l10n.noData}: ${l10n.buildings.toLowerCase()}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class DashboardLoadingState extends StatelessWidget {
  const DashboardLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(context.l10n.loading),
        ],
      ),
    );
  }
}

class DashboardErrorState extends StatelessWidget {
  const DashboardErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xFFDCE4EE)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 42,
                  color: Color(0xFF61718A),
                ),
                const SizedBox(height: 14),
                Text(
                  '${l10n.dashboard}: ${l10n.noData}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
