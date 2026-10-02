import 'package:fjellfisk/models/app_notification.dart';
import 'package:fjellfisk/l10n/app_localizations.dart';
import 'package:fjellfisk/theme/app_theme.dart';
import 'package:fjellfisk/widgets/notification_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bell shows badge only for unread notifications', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(
            actions: [NotificationBell(unreadCount: 0, onPressed: () {})],
          ),
        ),
      ),
    );

    expect(find.text('0'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(
            actions: [NotificationBell(unreadCount: 2, onPressed: () {})],
          ),
        ),
      ),
    );

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('center marks one and all notifications as read', (tester) async {
    var singleMarks = 0;
    var allMarks = 0;
    final notifications = [
      _notification(id: 'first'),
      _notification(id: 'second')
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NotificationCenterSheet(
            notifications: Stream.value(notifications),
            onMarkRead: (_) async => singleMarks++,
            onMarkAllRead: (_) async => allMarks++,
            onOpen: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Varsler'), findsOneWidget);
    expect(find.byTooltip('Marker som lest'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Marker som lest').first);
    await tester.pump();
    expect(singleMarks, 1);

    await tester.tap(find.text('Marker alle som lest'));
    await tester.pump();
    expect(allMarks, 1);
  });

  testWidgets('center stays visible when opened as a bottom sheet',
      (tester) async {
    final notification = _notification(id: 'bottom-sheet');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => Align(
                    alignment: Alignment.bottomCenter,
                    child: NotificationCenterSheet(
                      notifications: Stream.value([notification]),
                      onMarkRead: (_) async {},
                      onMarkAllRead: (_) async {},
                      onOpen: (_) async {},
                    ),
                  ),
                ),
                child: const Text('Open notifications'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Varsler'), findsOneWidget);
    expect(find.text('Kort varseltekst'), findsOneWidget);
    expect(tester.getSize(find.byType(NotificationCenterSheet)).height,
        greaterThan(200));
  });

  testWidgets('notification tap marks read before opening target',
      (tester) async {
    final events = <String>[];
    final notification = _notification(
      id: 'tank',
      type: AppNotificationType.highMortality,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: NotificationCenterSheet(
              notifications: Stream.value([notification]),
              onMarkRead: (_) async => events.add('read'),
              onMarkAllRead: (_) async {},
              onOpen: (_) async => events.add('open-tank'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Høy dødelighet i K1'));
    await tester.pumpAndSettle();

    expect(events, ['read', 'open-tank']);
  });

  testWidgets('system notifications use the selected UI language',
      (tester) async {
    final notification = _notification(
      id: 'mortality',
      type: AppNotificationType.highMortality,
    ).copyWith();
    final translated = AppNotification(
      id: notification.id,
      eventKey: notification.eventKey,
      type: notification.type,
      title: notification.title,
      body: notification.body,
      facilityId: notification.facilityId,
      sectionId: notification.sectionId,
      sectionName: notification.sectionName,
      tankId: notification.tankId,
      tankName: notification.tankName,
      relatedId: notification.relatedId,
      targetFishCount: notification.targetFishCount,
      primaryValue: 12,
      occurredAt: notification.occurredAt,
      isRead: notification.isRead,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NotificationCenterSheet(
            notifications: Stream.value([translated]),
            onMarkRead: (_) async {},
            onMarkAllRead: (_) async {},
            onOpen: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('High mortality in K1'), findsOneWidget);
    expect(find.textContaining('12 deaths in the last 7 days'), findsOneWidget);
  });

  testWidgets('user-written notification content is not translated',
      (tester) async {
    final note = AppNotification(
      id: 'note',
      eventKey: 'note',
      type: AppNotificationType.tankNote,
      title: 'Nytt driftsnotat på K1',
      body: 'Kontroller filteret før neste fôring.',
      facilityId: 'facility',
      sectionId: 'section',
      sectionName: 'Tunnel',
      tankId: 'tank',
      tankName: 'K1',
      relatedId: 'source',
      targetFishCount: 100,
      occurredAt: DateTime(2026, 10, 1, 12),
      isRead: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('pl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NotificationCenterSheet(
            notifications: Stream.value([note]),
            onMarkRead: (_) async {},
            onMarkAllRead: (_) async {},
            onOpen: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nowa notatka operacyjna dla K1'), findsOneWidget);
    expect(find.text('Kontroller filteret før neste fôring.'), findsOneWidget);
  });
}

AppNotification _notification({
  required String id,
  AppNotificationType type = AppNotificationType.diaryEntry,
}) {
  return AppNotification(
    id: id,
    eventKey: id,
    type: type,
    title: type == AppNotificationType.highMortality
        ? 'Høy dødelighet'
        : 'Nytt dagbokinnlegg',
    body: 'Kort varseltekst',
    facilityId: 'facility',
    sectionId: 'section',
    sectionName: 'Tunnel',
    tankId: 'tank',
    tankName: 'K1',
    relatedId: 'source',
    targetFishCount: 100,
    occurredAt: DateTime(2026, 10, 1, 12),
    isRead: false,
  );
}
