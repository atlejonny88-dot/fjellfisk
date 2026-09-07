import 'package:cloud_firestore/cloud_firestore.dart';

class UserInvite {
  const UserInvite({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.displayName = '',
    this.createdByEmail = '',
    this.updatedAt,
    this.acceptedAt,
    this.acceptedByUid,
    this.disabled = false,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String createdByEmail;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final String? acceptedByUid;
  final bool disabled;

  bool get isExpired =>
      status == 'pending' && DateTime.now().isAfter(expiresAt);

  bool get canBeUsed => status == 'pending' && !disabled && !isExpired;

  String get effectiveStatus => isExpired ? 'expired' : status;

  String get statusLabel {
    switch (effectiveStatus) {
      case 'accepted':
        return 'Godtatt';
      case 'revoked':
        return 'Trukket tilbake';
      case 'expired':
        return 'Utløpt';
      default:
        return 'Invitert';
    }
  }

  factory UserInvite.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return UserInvite(
      id: document.id,
      email: (data['email'] ?? '').toString(),
      displayName: (data['displayName'] ?? '').toString(),
      role: (data['role'] ?? 'leser').toString(),
      status: (data['status'] ?? 'pending').toString(),
      createdAt:
          _date(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt:
          _date(data['expiresAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      createdByEmail: (data['createdByEmail'] ?? '').toString(),
      updatedAt: _date(data['updatedAt']),
      acceptedAt: _date(data['acceptedAt']),
      acceptedByUid: data['acceptedByUid']?.toString(),
      disabled: data['disabled'] == true,
    );
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
