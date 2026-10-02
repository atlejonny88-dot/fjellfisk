import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../utils/data_values.dart';
import '../utils/feed_inventory_alert_policy.dart';
import '../utils/tank_status.dart';

class NotificationService {
  NotificationService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Set<String> _activeSyncs = <String>{};
  static final Map<String, DateTime> _syncPausedUntil = <String, DateTime>{};
  static final Set<String> _reportedPausedUsers = <String>{};

  static const _diaryLookback = Duration(days: 30);
  static const _syncRetryDelay = Duration(minutes: 5);

  static CollectionReference<Map<String, dynamic>> notificationsRef(
    String userId,
  ) {
    return _db.collection('users').doc(userId).collection('notifications');
  }

  static CollectionReference<Map<String, dynamic>> _statesRef(String userId) {
    return _db.collection('users').doc(userId).collection('notificationStates');
  }

  static Stream<List<AppNotification>> notificationsStream(
      {String? userId}) async* {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || _isSyncPaused(uid)) {
      yield const <AppNotification>[];
      return;
    }

    try {
      await for (final snapshot in notificationsRef(uid)
          .orderBy('occurredAt', descending: true)
          .limit(100)
          .snapshots()) {
        final notifications =
            snapshot.docs.map(AppNotification.fromDoc).toList(growable: false);
        notifications.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        yield notifications;
      }
    } on FirebaseException catch (error) {
      _pauseSync(userId: uid, source: 'senter', errorCode: error.code);
      yield const <AppNotification>[];
    } catch (_) {
      // The web SDK can wrap a Firestore error before it reaches Dart. Treat
      // it just like an unavailable notification collection instead of
      // allowing a failing stream to repeatedly retry in the UI.
      _pauseSync(userId: uid, source: 'senter');
      yield const <AppNotification>[];
    }
  }

  static int unreadCount(Iterable<AppNotification> notifications) {
    return notifications.where((notification) => !notification.isRead).length;
  }

  static Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    final uid = _requireUserId();
    await notificationsRef(uid).doc(notification.id).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markAllRead(
    Iterable<AppNotification> notifications,
  ) async {
    final unread = notifications.where((notification) => !notification.isRead);
    if (unread.isEmpty) return;

    final uid = _requireUserId();
    final batch = _db.batch();
    for (final notification in unread) {
      batch.update(notificationsRef(uid).doc(notification.id), {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Scans the existing operational data without changing it. A deterministic
  /// document ID prevents the same source event from reappearing on refresh.
  static Future<void> syncOperationalNotifications({
    required String facilityId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || facilityId.isEmpty) return;
    if (_isSyncPaused(uid)) return;

    final syncKey = '$uid:$facilityId';
    if (!_activeSyncs.add(syncKey)) return;

    try {
      final now = DateTime.now();
      if (!await _safeSource(
        userId: uid,
        source: 'dødelighet',
        operation: () => _syncHighMortality(
          userId: uid,
          facilityId: facilityId,
          now: now,
        ),
      )) {
        return;
      }
      if (!await _safeSource(
        userId: uid,
        source: 'fôrlager',
        operation: () => _syncLowFeedStock(
          userId: uid,
          facilityId: facilityId,
          now: now,
        ),
      )) {
        return;
      }
      if (!await _safeSource(
        userId: uid,
        source: 'driftsnotater',
        operation: () => _syncTankNotes(
          userId: uid,
          facilityId: facilityId,
          now: now,
        ),
      )) {
        return;
      }
      await _safeSource(
        userId: uid,
        source: 'dagbok',
        operation: () => _syncDiaryEntries(
          userId: uid,
          facilityId: facilityId,
          now: now,
        ),
      );
    } finally {
      _activeSyncs.remove(syncKey);
    }
  }

  static Future<void> syncWebUpdateNotification({
    required String facilityId,
    required String buildId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || facilityId.isEmpty || buildId.isEmpty) {
      return;
    }
    if (_isSyncPaused(uid)) return;

    await _safeSource(
      userId: uid,
      source: 'web-oppdatering',
      operation: () => _ensureEvent(
        userId: uid,
        notification: AppNotification(
          id: '',
          eventKey: 'app-update:$buildId',
          type: AppNotificationType.appUpdate,
          title: 'Ny Fjellfisk-versjon tilgjengelig',
          body: 'Oppdater appen når du har lagret eventuelle endringer.',
          facilityId: facilityId,
          sectionId: '',
          sectionName: '',
          tankId: '',
          tankName: '',
          relatedId: buildId,
          targetFishCount: 0,
          occurredAt: DateTime.now(),
          isRead: false,
        ),
      ),
    );
  }

  static Future<void> _syncHighMortality({
    required String userId,
    required String facilityId,
    required DateTime now,
  }) async {
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final sections = await _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .get();

    for (final section in sections.docs) {
      final sectionData = section.data();
      final sectionName = _text(sectionData['name'], fallback: section.id);
      final tanks = await section.reference.collection('tanks').get();

      for (final tank in tanks.docs) {
        final tankData = tank.data();
        final fishCount = TankStatus.fishCountFrom(tankData['fishCount']);
        final baseKey = 'high-mortality:$facilityId:${section.id}:${tank.id}';
        if (!TankStatus.isActiveFishCount(fishCount)) {
          await _syncCondition(
            userId: userId,
            baseKey: baseKey,
            isActive: false,
          );
          continue;
        }

        final logs = await tank.reference
            .collection('logs')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
            )
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(now))
            .orderBy('date')
            .get();

        var mortality = 0;
        QueryDocumentSnapshot<Map<String, dynamic>>? crossingLog;
        for (final log in logs.docs) {
          mortality += DataValues.integer(
            log.data()['mortality'] ?? log.data()['dead'],
          ).clamp(0, 2147483647).toInt();
          if (crossingLog == null && TankStatus.hasHighMortality7d(mortality)) {
            crossingLog = log;
          }
        }

        await _syncCondition(
          userId: userId,
          baseKey: baseKey,
          isActive: crossingLog != null,
          notification: crossingLog == null
              ? null
              : AppNotification(
                  id: '',
                  eventKey: '',
                  type: AppNotificationType.highMortality,
                  title:
                      'Høy dødelighet i ${_text(tankData['name'], fallback: tank.id)}',
                  body:
                      '$mortality døde siste 7 dager. Kontroller karet og registreringene.',
                  facilityId: facilityId,
                  sectionId: section.id,
                  sectionName: sectionName,
                  tankId: tank.id,
                  tankName: _text(tankData['name'], fallback: tank.id),
                  relatedId: crossingLog.id,
                  targetFishCount: fishCount,
                  primaryValue: mortality.toDouble(),
                  occurredAt: _date(crossingLog.data()['date']) ?? now,
                  isRead: false,
                ),
        );
      }
    }
  }

  static Future<void> _syncLowFeedStock({
    required String userId,
    required String facilityId,
    required DateTime now,
  }) async {
    final feeds = await _db.collection('feed_inventory').get();
    for (final feed in feeds.docs) {
      final data = feed.data();
      final lowStock = FeedInventoryAlertPolicy.hasLowStock(data);
      final stock = FeedInventoryAlertPolicy.stockKg(data);
      final threshold = FeedInventoryAlertPolicy.thresholdKg(data);
      final name = _text(data['name'], fallback: feed.id);
      await _syncCondition(
        userId: userId,
        baseKey: 'low-feed:${feed.id}',
        isActive: lowStock,
        notification: !lowStock
            ? null
            : AppNotification(
                id: '',
                eventKey: '',
                type: AppNotificationType.lowFeedStock,
                title: 'Lavt fôrlager: $name',
                body:
                    '${_decimal(stock)} kg igjen. Varselgrense er ${_decimal(threshold)} kg (én sekk).',
                facilityId: facilityId,
                sectionId: '',
                sectionName: '',
                tankId: '',
                // Reuse the optional display target for the feed name. This is
                // only presented in the notification and is never a tank ID.
                tankName: name,
                relatedId: feed.id,
                targetFishCount: 0,
                primaryValue: stock,
                secondaryValue: threshold,
                occurredAt: _date(data['updatedAt']) ?? now,
                isRead: false,
              ),
      );
    }
  }

  static Future<void> _syncTankNotes({
    required String userId,
    required String facilityId,
    required DateTime now,
  }) async {
    final sections = await _db
        .collection('facilities')
        .doc(facilityId)
        .collection('sections')
        .get();

    for (final section in sections.docs) {
      final sectionName = _text(section.data()['name'], fallback: section.id);
      final tanks = await section.reference.collection('tanks').get();
      for (final tank in tanks.docs) {
        final tankData = tank.data();
        final notes = await tank.reference
            .collection('tankNotes')
            .where('status', isEqualTo: 'active')
            .get();
        for (final note in notes.docs) {
          final noteData = note.data();
          final tankName = _text(tankData['name'], fallback: tank.id);
          await _ensureEvent(
            userId: userId,
            notification: AppNotification(
              id: '',
              eventKey:
                  'tank-note:$facilityId:${section.id}:${tank.id}:${note.id}',
              type: AppNotificationType.tankNote,
              title: 'Nytt driftsnotat på $tankName',
              body: _shortText(
                _text(noteData['text'], fallback: 'Driftsnotat uten tekst.'),
              ),
              facilityId: facilityId,
              sectionId: section.id,
              sectionName: sectionName,
              tankId: tank.id,
              tankName: tankName,
              relatedId: note.id,
              targetFishCount: TankStatus.fishCountFrom(tankData['fishCount']),
              occurredAt: _date(noteData['createdAt']) ??
                  _date(noteData['updatedAt']) ??
                  now,
              isRead: false,
            ),
          );
        }
      }
    }
  }

  static Future<void> _syncDiaryEntries({
    required String userId,
    required String facilityId,
    required DateTime now,
  }) async {
    final earliest = now.subtract(_diaryLookback);
    final entries = await _db
        .collection('facilities')
        .doc(facilityId)
        .collection('diaryEntries')
        .orderBy('entryDate', descending: true)
        .limit(50)
        .get();

    for (final entry in entries.docs) {
      final data = entry.data();
      if (data['status'] == 'archived') continue;
      final occurredAt = _date(data['createdAt']) ??
          _date(data['entryDate']) ??
          _date(data['updatedAt']);
      if (occurredAt == null || occurredAt.isBefore(earliest)) continue;
      await _ensureEvent(
        userId: userId,
        notification: AppNotification(
          id: '',
          eventKey: 'diary:$facilityId:${entry.id}',
          type: AppNotificationType.diaryEntry,
          title:
              'Nytt dagbokinnlegg: ${_text(data['title'], fallback: 'Uten tittel')}',
          body: _shortText(_text(data['body'])),
          facilityId: facilityId,
          sectionId: '',
          sectionName: '',
          tankId: '',
          tankName: '',
          relatedId: entry.id,
          targetFishCount: 0,
          occurredAt: occurredAt,
          isRead: false,
        ),
      );
    }
  }

  static Future<void> _ensureEvent({
    required String userId,
    required AppNotification notification,
  }) async {
    final eventKey = notification.eventKey;
    if (eventKey.isEmpty) return;
    final reference = notificationsRef(userId)
        .doc(NotificationDeduplication.documentIdFor(eventKey));
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) return;
      transaction.set(
        reference,
        notification.copyWith(id: reference.id).toCreateMap(userId),
      );
    });
  }

  static Future<void> _syncCondition({
    required String userId,
    required String baseKey,
    required bool isActive,
    AppNotification? notification,
  }) async {
    final stateReference = _statesRef(userId)
        .doc(NotificationDeduplication.documentIdFor(baseKey));
    await _db.runTransaction((transaction) async {
      final stateSnapshot = await transaction.get(stateReference);
      final state = stateSnapshot.data() ?? const <String, dynamic>{};
      final wasActive = state['active'] == true;
      final cycle = DataValues.integer(state['cycle']);
      final nextCycle = NotificationDeduplication.activationCycle(
        wasActive: wasActive,
        cycle: cycle,
        isActive: isActive,
      );

      if (nextCycle == null) {
        if (wasActive && !isActive) {
          transaction.set(
            stateReference,
            _stateData(baseKey: baseKey, active: false, cycle: cycle),
          );
        }
        return;
      }

      if (notification == null) return;
      final eventKey = NotificationDeduplication.eventKeyForCycle(
        baseKey,
        nextCycle,
      );
      final notificationReference = notificationsRef(userId)
          .doc(NotificationDeduplication.documentIdFor(eventKey));
      final existingNotification = await transaction.get(notificationReference);
      if (!existingNotification.exists) {
        transaction.set(
          notificationReference,
          notification
              .copyWith(id: notificationReference.id, eventKey: eventKey)
              .toCreateMap(userId),
        );
      }
      transaction.set(
        stateReference,
        _stateData(baseKey: baseKey, active: true, cycle: nextCycle),
      );
    });
  }

  static Map<String, dynamic> _stateData({
    required String baseKey,
    required bool active,
    required int cycle,
  }) {
    return {
      'key': baseKey,
      'active': active,
      'cycle': cycle,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Future<bool> _safeSource({
    required String userId,
    required String source,
    required Future<void> Function() operation,
  }) async {
    try {
      await operation();
      return true;
    } on FirebaseException catch (error) {
      _pauseSync(userId: userId, source: source, errorCode: error.code);
      return false;
    } catch (_) {
      _pauseSync(userId: userId, source: source);
      return false;
    }
  }

  static bool _isSyncPaused(String userId) {
    final pausedUntil = _syncPausedUntil[userId];
    if (pausedUntil == null) return false;
    if (DateTime.now().isBefore(pausedUntil)) return true;
    _syncPausedUntil.remove(userId);
    _reportedPausedUsers.remove(userId);
    return false;
  }

  static void _pauseSync({
    required String userId,
    required String source,
    String? errorCode,
  }) {
    _syncPausedUntil[userId] = DateTime.now().add(_syncRetryDelay);
    if (!kDebugMode || !_reportedPausedUsers.add(userId)) return;

    final codeSuffix =
        errorCode == null || errorCode.isEmpty ? '' : ' ($errorCode)';
    debugPrint(
      'Fjellfisk varslinger er midlertidig utilgjengelige$codeSuffix '
      'ved $source. Nytt forsøk skjer om fem minutter.',
    );
  }

  static String _requireUserId() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Ingen bruker er logget inn.');
    }
    return uid;
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num && value.isFinite) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _shortText(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 160) return trimmed;
    return '${trimmed.substring(0, 157)}...';
  }

  static String _decimal(double value) {
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }
}
