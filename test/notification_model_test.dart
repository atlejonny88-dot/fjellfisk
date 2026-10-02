import 'package:fjellfisk/models/app_notification.dart';
import 'package:fjellfisk/services/notification_service.dart';
import 'package:fjellfisk/utils/feed_inventory_alert_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationDeduplication', () {
    test('creates a new cycle only when a condition becomes active', () {
      expect(
        NotificationDeduplication.activationCycle(
          wasActive: false,
          cycle: 0,
          isActive: true,
        ),
        1,
      );
      expect(
        NotificationDeduplication.activationCycle(
          wasActive: true,
          cycle: 1,
          isActive: true,
        ),
        isNull,
      );
      expect(
        NotificationDeduplication.activationCycle(
          wasActive: true,
          cycle: 1,
          isActive: false,
        ),
        isNull,
      );
      expect(
        NotificationDeduplication.activationCycle(
          wasActive: false,
          cycle: 1,
          isActive: true,
        ),
        2,
      );
    });

    test('uses a Firestore-safe deterministic document id', () {
      final first = NotificationDeduplication.documentIdFor('diary:facility/a');
      final second =
          NotificationDeduplication.documentIdFor('diary:facility/a');

      expect(first, second);
      expect(first, isNot(contains('/')));
      expect(
        NotificationDeduplication.eventKeyForCycle('low-feed:feed-a', 2),
        'low-feed:feed-a:2',
      );
    });
  });

  test('missing legacy notification fields use safe fallbacks', () {
    final notification = AppNotification.fromMap('legacy', {
      'type': 'unknown-type',
      'title': '',
      'targetFishCount': 'not-a-number',
    });

    expect(notification.id, 'legacy');
    expect(notification.eventKey, 'legacy');
    expect(notification.title, 'Nytt varsel');
    expect(notification.targetFishCount, 0);
    expect(notification.isRead, isFalse);
  });

  test('unread count ignores notifications marked as read', () {
    final notifications = [
      _notification(id: 'unread', isRead: false),
      _notification(id: 'read', isRead: true),
    ];

    expect(NotificationService.unreadCount(notifications), 1);
  });

  test('low feed stock means less than one configured bag remains', () {
    expect(
      FeedInventoryAlertPolicy.hasLowStock({
        'stockKg': 19.9,
        'kgPerBag': 20,
        'active': true,
      }),
      isTrue,
    );
    expect(
      FeedInventoryAlertPolicy.hasLowStock({
        'stockKg': 20,
        'kgPerBag': 20,
        'active': true,
      }),
      isFalse,
    );
    expect(
      FeedInventoryAlertPolicy.hasLowStock({
        'stockKg': 0,
        'active': true,
      }),
      isFalse,
    );
  });
}

AppNotification _notification({required String id, required bool isRead}) {
  return AppNotification(
    id: id,
    eventKey: id,
    type: AppNotificationType.diaryEntry,
    title: 'Varsel',
    body: '',
    facilityId: 'facility',
    sectionId: '',
    sectionName: '',
    tankId: '',
    tankName: '',
    relatedId: '',
    targetFishCount: 0,
    occurredAt: DateTime(2026, 10, 1),
    isRead: isRead,
  );
}
