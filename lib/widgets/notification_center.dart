import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_notification.dart';
import '../l10n/localizations.dart';
import '../utils/ui_motion.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  Timer? _pulseTimer;
  var _pulsing = false;

  @override
  void didUpdateWidget(covariant NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unreadCount > oldWidget.unreadCount) _pulseOnce();
  }

  void _pulseOnce() {
    if (uiMotionDisabled(context)) return;
    _pulseTimer?.cancel();
    setState(() => _pulsing = true);
    _pulseTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _pulsing = false);
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = widget.unreadCount > 0;
    final l10n = context.l10n;
    final label = hasUnread
        ? l10n.unreadNotifications(widget.unreadCount)
        : l10n.noUnreadNotifications;
    final duration = uiMotionDuration(context);
    return Semantics(
      button: true,
      label: label,
      child: AnimatedScale(
        duration: duration,
        curve: Curves.easeOut,
        scale: _pulsing ? 1.08 : 1,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: l10n.notifications,
              onPressed: widget.onPressed,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            Positioned(
              right: 3,
              top: 3,
              child: ExcludeSemantics(
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale:
                          Tween<double>(begin: 0.82, end: 1).animate(animation),
                      child: child,
                    ),
                  ),
                  child: hasUnread
                      ? Container(
                          key: ValueKey(
                            'badge-${widget.unreadCount > 99 ? '99+' : widget.unreadCount}',
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 17,
                            minHeight: 17,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD92D20),
                            border: Border.all(
                              color: const Color(0xFF082C51),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            widget.unreadCount > 99
                                ? '99+'
                                : widget.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : const SizedBox(key: ValueKey('no-badge')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationCenterSheet extends StatefulWidget {
  const NotificationCenterSheet({
    super.key,
    required this.notifications,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onOpen,
  });

  final Stream<List<AppNotification>> notifications;
  final Future<void> Function(AppNotification notification) onMarkRead;
  final Future<void> Function(Iterable<AppNotification> notifications)
      onMarkAllRead;
  final Future<void> Function(AppNotification notification) onOpen;

  @override
  State<NotificationCenterSheet> createState() =>
      _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<NotificationCenterSheet> {
  final Set<String> _busyNotifications = <String>{};
  var _markingAll = false;

  Future<void> _open(AppNotification notification) async {
    if (_busyNotifications.contains(notification.id)) return;
    setState(() => _busyNotifications.add(notification.id));
    try {
      if (!notification.isRead) await widget.onMarkRead(notification);
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onOpen(notification);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenNotification)),
      );
    } finally {
      if (mounted) setState(() => _busyNotifications.remove(notification.id));
    }
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead || _busyNotifications.contains(notification.id)) {
      return;
    }
    setState(() => _busyNotifications.add(notification.id));
    try {
      await widget.onMarkRead(notification);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotMarkNotificationRead)),
      );
    } finally {
      if (mounted) setState(() => _busyNotifications.remove(notification.id));
    }
  }

  Future<void> _markAllRead(List<AppNotification> notifications) async {
    if (_markingAll || notifications.every((item) => item.isRead)) return;
    setState(() => _markingAll = true);
    try {
      await widget.onMarkAllRead(notifications);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotMarkAllNotificationsRead)),
      );
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.84;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetHeight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: StreamBuilder<List<AppNotification>>(
            stream: widget.notifications,
            builder: (context, snapshot) {
              final notifications = snapshot.data ?? const <AppNotification>[];
              final unread = notifications.where((item) => !item.isRead).length;
              return Material(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF0B63E5),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.notifications,
                              style: const TextStyle(
                                color: Color(0xFF0A1733),
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (unread > 0)
                            TextButton(
                              onPressed: _markingAll
                                  ? null
                                  : () => _markAllRead(notifications),
                              child: Text(
                                _markingAll ? l10n.marking : l10n.markAllRead,
                              ),
                            ),
                          IconButton(
                            tooltip: l10n.closeNotifications,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: snapshot.hasError
                          ? _NotificationMessage(
                              icon: Icons.notifications_off_outlined,
                              title: l10n.notificationsUnavailable,
                              detail: l10n.notificationsUnavailableDetail,
                            )
                          : !snapshot.hasData
                              ? const Center(child: CircularProgressIndicator())
                              : notifications.isEmpty
                                  ? _NotificationMessage(
                                      icon: Icons.notifications_none_rounded,
                                      title: l10n.noNotifications,
                                      detail: l10n.noNotificationsDetail,
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 10, 12, 20),
                                      itemCount: notifications.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final notification =
                                            notifications[index];
                                        final busy = _busyNotifications
                                            .contains(notification.id);
                                        return _NotificationTile(
                                          key: ValueKey(notification.id),
                                          notification: notification,
                                          busy: busy,
                                          onTap: () => _open(notification),
                                          onMarkRead: notification.isRead
                                              ? null
                                              : () => _markRead(notification),
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile({
    super.key,
    required this.notification,
    required this.busy,
    required this.onTap,
    required this.onMarkRead,
  });

  final AppNotification notification;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  var _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final presentation = _presentation(notification.type);
    final l10n = context.l10n;
    final duration = uiMotionDuration(context);
    return AnimatedSlide(
      duration: duration,
      curve: Curves.easeOut,
      offset: _shown || uiMotionDisabled(context)
          ? Offset.zero
          : const Offset(0, 0.025),
      child: AnimatedOpacity(
        duration: duration,
        curve: Curves.easeOut,
        opacity: _shown || uiMotionDisabled(context) ? 1 : 0,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.white : const Color(0xFFEAF3FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: notification.isRead
                  ? const Color(0xFFDCE4EE)
                  : const Color(0xFFB9D4F5),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.busy ? null : widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: presentation.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(presentation.icon, color: presentation.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _localizedTitle(l10n),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: const Color(0xFF0A1733),
                                    fontWeight: notification.isRead
                                        ? FontWeight.w700
                                        : FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0B63E5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          if (_localizedBody(l10n).isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              _localizedBody(l10n),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF5F7088),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            _formatDate(context, notification.occurredAt),
                            style: const TextStyle(
                              color: Color(0xFF7A8AA0),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.busy)
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 8),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (widget.onMarkRead != null)
                      IconButton(
                        tooltip: l10n.markAsRead,
                        onPressed: widget.onMarkRead,
                        icon: const Icon(Icons.done_rounded, size: 20),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _localizedTitle(AppLocalizations l10n) {
    switch (widget.notification.type) {
      case AppNotificationType.highMortality:
        return widget.notification.tankName.isEmpty
            ? l10n.highMortality
            : l10n.highMortalityTank(widget.notification.tankName);
      case AppNotificationType.lowFeedStock:
        return widget.notification.tankName.isEmpty
            ? l10n.lowFeedStockItem(widget.notification.relatedId)
            : l10n.lowFeedStockItem(widget.notification.tankName);
      case AppNotificationType.tankNote:
        return widget.notification.tankName.isEmpty
            ? widget.notification.title
            : l10n.newTankNote(widget.notification.tankName);
      case AppNotificationType.diaryEntry:
        return l10n.newDiaryEntry;
      case AppNotificationType.appUpdate:
        return l10n.newVersionAvailable;
    }
  }

  String _localizedBody(AppLocalizations l10n) {
    switch (widget.notification.type) {
      case AppNotificationType.highMortality:
        if (widget.notification.primaryValue > 0) {
          return l10n.deathsLast7Days(widget.notification.primaryValue.round());
        }
        return widget.notification.body;
      case AppNotificationType.lowFeedStock:
        if (widget.notification.primaryValue > 0 ||
            widget.notification.secondaryValue > 0) {
          return l10n.feedStockBody(
            _decimal(widget.notification.primaryValue),
            _decimal(widget.notification.secondaryValue),
          );
        }
        return widget.notification.body;
      case AppNotificationType.appUpdate:
        return l10n.updateWhenSaved;
      case AppNotificationType.tankNote:
      case AppNotificationType.diaryEntry:
        return widget.notification.body;
    }
  }

  String _decimal(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');

  String _formatDate(BuildContext context, DateTime value) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final local = value.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final time = DateFormat('HH:mm').format(local);
    if (date == today) return l10n.todayAt(time);
    if (date == today.subtract(const Duration(days: 1))) {
      return l10n.yesterdayAt(time);
    }
    return DateFormat(
            'dd.MM.yyyy HH:mm', Localizations.localeOf(context).languageCode)
        .format(local);
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: const Color(0xFF7A8AA0)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF5F7088)),
            ),
          ],
        ),
      ),
    );
  }
}

_NotificationPresentation _presentation(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.highMortality:
      return const _NotificationPresentation(
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFD43838),
      );
    case AppNotificationType.lowFeedStock:
      return const _NotificationPresentation(
        icon: Icons.inventory_2_outlined,
        color: Color(0xFFD28200),
      );
    case AppNotificationType.tankNote:
      return const _NotificationPresentation(
        icon: Icons.sticky_note_2_outlined,
        color: Color(0xFF9A6700),
      );
    case AppNotificationType.diaryEntry:
      return const _NotificationPresentation(
        icon: Icons.menu_book_outlined,
        color: Color(0xFF0B63E5),
      );
    case AppNotificationType.appUpdate:
      return const _NotificationPresentation(
        icon: Icons.system_update_alt_rounded,
        color: Color(0xFF6C55C7),
      );
  }
}

class _NotificationPresentation {
  const _NotificationPresentation({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}
