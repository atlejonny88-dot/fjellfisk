import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/diary_entry.dart';
import 'user_service.dart';

enum DiaryPeriod { day, month, year }

class DiaryDateRange {
  const DiaryDateRange({
    required this.start,
    required this.endExclusive,
  });

  final DateTime start;
  final DateTime endExclusive;
}

class DiaryService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const categories = <String>[
    'Hendelse',
    'Vedlikehold',
    'Observasjon',
    'Fôring',
    'Service',
    'Annet',
  ];

  static CollectionReference<Map<String, dynamic>> entriesRef(
    String facilityId,
  ) {
    return _db
        .collection('facilities')
        .doc(facilityId)
        .collection('diaryEntries');
  }

  static DiaryDateRange rangeFor(DiaryPeriod period, DateTime focusDate) {
    final localDate = DateTime(
      focusDate.year,
      focusDate.month,
      focusDate.day,
    );

    switch (period) {
      case DiaryPeriod.day:
        return DiaryDateRange(
          start: localDate,
          endExclusive: DateTime(
            localDate.year,
            localDate.month,
            localDate.day + 1,
          ),
        );
      case DiaryPeriod.month:
        return DiaryDateRange(
          start: DateTime(localDate.year, localDate.month),
          endExclusive: DateTime(localDate.year, localDate.month + 1),
        );
      case DiaryPeriod.year:
        return DiaryDateRange(
          start: DateTime(localDate.year),
          endExclusive: DateTime(localDate.year + 1),
        );
    }
  }

  static DateTime shiftFocus(
    DiaryPeriod period,
    DateTime focusDate,
    int amount,
  ) {
    switch (period) {
      case DiaryPeriod.day:
        return focusDate.add(Duration(days: amount));
      case DiaryPeriod.month:
        return DateTime(focusDate.year, focusDate.month + amount, 1);
      case DiaryPeriod.year:
        return DateTime(focusDate.year + amount, 1, 1);
    }
  }

  static Stream<List<DiaryEntry>> entriesStream({
    required String facilityId,
    required DiaryDateRange range,
  }) {
    return entriesRef(facilityId)
        .where(
          'entryDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where(
          'entryDate',
          isLessThan: Timestamp.fromDate(range.endExclusive),
        )
        .orderBy('entryDate', descending: true)
        .snapshots()
        .map(_activeEntries);
  }

  static Future<List<DiaryEntry>> fetchEntries({
    required String facilityId,
    required DiaryDateRange range,
  }) async {
    final snapshot = await entriesRef(facilityId)
        .where(
          'entryDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where(
          'entryDate',
          isLessThan: Timestamp.fromDate(range.endExclusive),
        )
        .orderBy('entryDate', descending: true)
        .get();
    return _activeEntries(snapshot);
  }

  static Future<void> createEntry({
    required String facilityId,
    required DiaryDraft draft,
  }) async {
    _validateDraft(draft);
    final role = await UserService.getCurrentUserRole();
    if (role != 'admin' && role != 'ansatt') {
      throw StateError('Brukeren har ikke tilgang til å opprette innlegg.');
    }

    final user = _requireUser();
    final now = DateTime.now();
    final timestamp = Timestamp.fromDate(now);
    await entriesRef(facilityId).add({
      'title': draft.title.trim(),
      'body': draft.body.trim(),
      'category': draft.category,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': user.uid,
      'createdByEmail': user.email ?? '',
      'createdByName': _userName(user),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': user.uid,
      'updatedByEmail': user.email ?? '',
      'entryDate': timestamp,
      'status': 'active',
    });
  }

  static Future<void> updateEntry({
    required String facilityId,
    required DiaryEntry entry,
    required DiaryDraft draft,
  }) async {
    _validateDraft(draft);
    final role = await UserService.getCurrentUserRole();
    final user = _requireUser();
    final canEdit =
        role == 'admin' || (role == 'ansatt' && entry.createdByUid == user.uid);
    if (!canEdit) {
      throw StateError('Brukeren har ikke tilgang til å redigere innlegget.');
    }

    await entriesRef(facilityId).doc(entry.id).update({
      'title': draft.title.trim(),
      'body': draft.body.trim(),
      'category': draft.category,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': user.uid,
      'updatedByEmail': user.email ?? '',
    });
  }

  static Future<void> archiveEntry({
    required String facilityId,
    required DiaryEntry entry,
  }) async {
    final role = await UserService.getCurrentUserRole();
    if (role != 'admin') {
      throw StateError('Bare admin kan arkivere innlegg.');
    }

    final user = _requireUser();
    await entriesRef(facilityId).doc(entry.id).update({
      'status': 'archived',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': user.uid,
      'updatedByEmail': user.email ?? '',
    });
  }

  static List<DiaryEntry> _activeEntries(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final entries = snapshot.docs.map(DiaryEntry.fromDoc).where((entry) {
      return !entry.isArchived;
    }).toList();
    entries.sort((a, b) {
      final aDate = a.displayDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.displayDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return entries;
  }

  static User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Ingen bruker er logget inn.');
    return user;
  }

  static String _userName(User user) {
    final displayName = user.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) return displayName;

    final email = user.email?.trim() ?? '';
    if (email.contains('@')) return email.split('@').first;
    return email;
  }

  static void _validateDraft(DiaryDraft draft) {
    if (draft.title.trim().isEmpty) {
      throw ArgumentError('Tittel må fylles ut.');
    }
    if (draft.title.trim().length > 160) {
      throw ArgumentError('Tittelen er for lang.');
    }
    if (draft.body.trim().isEmpty) {
      throw ArgumentError('Tekst må fylles ut.');
    }
    if (draft.body.trim().length > 10000) {
      throw ArgumentError('Teksten er for lang.');
    }
    if (!categories.contains(draft.category)) {
      throw ArgumentError('Velg en gyldig kategori.');
    }
  }
}
