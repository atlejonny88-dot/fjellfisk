import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationType {
  highMortality,
  lowFeedStock,
  tankNote,
  diaryEntry,
  appUpdate,
}

extension AppNotificationTypeValue on AppNotificationType {
  String get value {
    switch (this) {
      case AppNotificationType.highMortality:
        return 'highMortality';
      case AppNotificationType.lowFeedStock:
        return 'lowFeedStock';
      case AppNotificationType.tankNote:
        return 'tankNote';
      case AppNotificationType.diaryEntry:
        return 'diaryEntry';
      case AppNotificationType.appUpdate:
        return 'appUpdate';
    }
  }

  static AppNotificationType fromValue(Object? value) {
    switch (value?.toString()) {
      case 'highMortality':
        return AppNotificationType.highMortality;
      case 'lowFeedStock':
        return AppNotificationType.lowFeedStock;
      case 'tankNote':
        return AppNotificationType.tankNote;
      case 'diaryEntry':
        return AppNotificationType.diaryEntry;
      case 'appUpdate':
        return AppNotificationType.appUpdate;
      default:
        return AppNotificationType.diaryEntry;
    }
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.eventKey,
    required this.type,
    required this.title,
    required this.body,
    required this.facilityId,
    required this.sectionId,
    required this.sectionName,
    required this.tankId,
    required this.tankName,
    required this.relatedId,
    required this.targetFishCount,
    this.primaryValue = 0,
    this.secondaryValue = 0,
    required this.occurredAt,
    required this.isRead,
  });

  final String id;
  final String eventKey;
  final AppNotificationType type;
  final String title;
  final String body;
  final String facilityId;
  final String sectionId;
  final String sectionName;
  final String tankId;
  final String tankName;
  final String relatedId;
  final int targetFishCount;
  final double primaryValue;
  final double secondaryValue;
  final DateTime occurredAt;
  final bool isRead;

  AppNotification copyWith({
    String? eventKey,
    String? id,
  }) {
    return AppNotification(
      id: id ?? this.id,
      eventKey: eventKey ?? this.eventKey,
      type: type,
      title: title,
      body: body,
      facilityId: facilityId,
      sectionId: sectionId,
      sectionName: sectionName,
      tankId: tankId,
      tankName: tankName,
      relatedId: relatedId,
      targetFishCount: targetFishCount,
      primaryValue: primaryValue,
      secondaryValue: secondaryValue,
      occurredAt: occurredAt,
      isRead: isRead,
    );
  }

  Map<String, dynamic> toCreateMap(String userId) {
    return {
      'userId': userId,
      'eventKey': eventKey,
      'type': type.value,
      'title': _shortText(title, 160),
      'body': _shortText(body, 400),
      'facilityId': facilityId,
      'sectionId': sectionId,
      'sectionName': _shortText(sectionName, 160),
      'tankId': tankId,
      'tankName': _shortText(tankName, 160),
      'relatedId': relatedId,
      'targetFishCount': targetFishCount < 0 ? 0 : targetFishCount,
      'primaryValue':
          primaryValue.isFinite && primaryValue >= 0 ? primaryValue : 0,
      'secondaryValue':
          secondaryValue.isFinite && secondaryValue >= 0 ? secondaryValue : 0,
      'occurredAt': Timestamp.fromDate(occurredAt),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'readAt': null,
    };
  }

  factory AppNotification.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return AppNotification.fromMap(document.id, document.data());
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic>? data) {
    final values = data ?? const <String, dynamic>{};
    return AppNotification(
      id: id,
      eventKey: _text(values['eventKey'], fallback: id),
      type: AppNotificationTypeValue.fromValue(values['type']),
      title: _text(values['title'], fallback: 'Nytt varsel'),
      body: _text(values['body']),
      facilityId: _text(values['facilityId']),
      sectionId: _text(values['sectionId']),
      sectionName: _text(values['sectionName']),
      tankId: _text(values['tankId']),
      tankName: _text(values['tankName']),
      relatedId: _text(values['relatedId']),
      targetFishCount: _integer(values['targetFishCount']),
      primaryValue: _decimal(values['primaryValue']),
      secondaryValue: _decimal(values['secondaryValue']),
      occurredAt:
          _date(values['occurredAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      isRead: values['isRead'] == true,
    );
  }

  static String _shortText(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return trimmed.substring(0, maxLength);
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int _integer(Object? value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is num && value.isFinite) {
      return value.toInt().clamp(0, 2147483647).toInt();
    }
    return int.tryParse(value?.toString() ?? '')
            ?.clamp(0, 2147483647)
            .toInt() ??
        0;
  }

  static double _decimal(Object? value) {
    if (value is num && value.isFinite) {
      return value.toDouble().clamp(0, 1e12).toDouble();
    }
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '')
            ?.clamp(0, 1e12)
            .toDouble() ??
        0;
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
}

class NotificationDeduplication {
  static String documentIdFor(String key) {
    return base64Url.encode(utf8.encode(key)).replaceAll('=', '');
  }

  static int? activationCycle({
    required bool wasActive,
    required int cycle,
    required bool isActive,
  }) {
    if (!isActive || wasActive) return null;
    return cycle + 1;
  }

  static String eventKeyForCycle(String key, int cycle) => '$key:$cycle';
}
