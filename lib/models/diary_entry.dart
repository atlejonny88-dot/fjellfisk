import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    required this.createdByUid,
    required this.createdByEmail,
    required this.createdByName,
    required this.updatedAt,
    required this.updatedByUid,
    required this.updatedByEmail,
    required this.entryDate,
    required this.status,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final DateTime? createdAt;
  final String createdByUid;
  final String createdByEmail;
  final String createdByName;
  final DateTime? updatedAt;
  final String updatedByUid;
  final String updatedByEmail;
  final DateTime? entryDate;
  final String status;

  bool get isArchived => status == 'archived';

  DateTime? get displayDate => entryDate ?? createdAt ?? updatedAt;

  String get authorLabel {
    final name = createdByName.trim();
    if (name.isNotEmpty) return name;

    final email = createdByEmail.trim();
    if (email.isNotEmpty) return email;

    return 'Ukjent bruker';
  }

  factory DiaryEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return DiaryEntry(
      id: document.id,
      title: _text(data['title'], fallback: 'Uten tittel'),
      body: _text(data['body']),
      category: _text(data['category'], fallback: 'Annet'),
      createdAt: _date(data['createdAt']),
      createdByUid: _text(data['createdByUid']),
      createdByEmail: _text(data['createdByEmail']),
      createdByName: _text(data['createdByName']),
      updatedAt: _date(data['updatedAt']),
      updatedByUid: _text(data['updatedByUid']),
      updatedByEmail: _text(data['updatedByEmail']),
      entryDate: _date(data['entryDate']),
      status: _text(data['status'], fallback: 'active').toLowerCase(),
    );
  }

  static String _text(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class DiaryDraft {
  const DiaryDraft({
    required this.title,
    required this.body,
    required this.category,
  });

  final String title;
  final String body;
  final String category;
}
