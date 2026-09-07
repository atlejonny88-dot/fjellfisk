import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_invite.dart';

class UserInviteException implements Exception {
  const UserInviteException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class UserInviteService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const roles = ['admin', 'ansatt', 'leser'];
  static const inviteDuration = Duration(days: 7);
  static const hostingBaseUrl = 'https://trolltungaarctictrout.web.app';

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static bool isValidEmail(String email) {
    final normalized = normalizeEmail(email);
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized);
  }

  static String inviteLink(String token) {
    return '$hostingBaseUrl/#/invite/$token';
  }

  static String invitationText(UserInvite invite) {
    final name = invite.displayName.trim();
    final greeting = name.isEmpty ? 'Hei!' : 'Hei $name!';
    return '$greeting\n\n'
        'Du er invitert til Fjellfisk for Arctic Hardanger.\n\n'
        'Åpne lenken og registrer eller logg inn med denne e-posten:\n'
        '${invite.email}\n\n'
        'Lenke:\n${inviteLink(invite.id)}\n\n'
        'Mvh\nArctic Hardanger';
  }

  static Stream<List<UserInvite>> invitesStream() {
    return _db
        .collection('userInvites')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(UserInvite.fromDocument)
              .toList(growable: false),
        );
  }

  static Future<UserInvite> createInvite({
    required String email,
    required String role,
    String displayName = '',
  }) async {
    final creator = _auth.currentUser;
    if (creator == null) {
      throw const UserInviteException(
        'not-authenticated',
        'Du må være logget inn for å invitere brukere',
      );
    }

    final emailLower = normalizeEmail(email);
    if (!isValidEmail(emailLower)) {
      throw const UserInviteException('invalid-email', 'Ugyldig e-post');
    }
    if (!roles.contains(role)) {
      throw const UserInviteException('invalid-role', 'Ugyldig rolle');
    }

    try {
      final users = await _db.collection('users').get();
      final alreadyRegistered = users.docs.any((document) {
        final data = document.data();
        return normalizeEmail((data['email'] ?? '').toString()) == emailLower;
      });
      if (alreadyRegistered) {
        throw const UserInviteException(
          'user-exists',
          'Denne e-posten er allerede registrert',
        );
      }

      final existingInvites = await _db
          .collection('userInvites')
          .where('emailLower', isEqualTo: emailLower)
          .get();
      final hasActiveInvite = existingInvites.docs
          .map(UserInvite.fromDocument)
          .any((invite) => invite.canBeUsed);
      if (hasActiveInvite) {
        throw const UserInviteException(
          'invite-exists',
          'Det finnes allerede en aktiv invitasjon for denne e-posten',
        );
      }

      final token = _generateToken();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(inviteDuration),
      );
      final data = <String, dynamic>{
        'email': emailLower,
        'emailLower': emailLower,
        'displayName': displayName.trim(),
        'role': role,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': creator.uid,
        'createdByEmail': creator.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'acceptedAt': null,
        'acceptedByUid': null,
        'disabled': false,
        'inviteToken': token,
        'expiresAt': expiresAt,
      };

      final reference = _db.collection('userInvites').doc(token);
      await reference.set(data);
      return UserInvite.fromDocument(await reference.get());
    } on UserInviteException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _firebaseError(error);
    }
  }

  static Future<UserInvite> loadInvite(String token) async {
    if (token.trim().isEmpty) {
      throw const UserInviteException(
        'invalid-invite',
        'Invitasjonslenken er ugyldig',
      );
    }

    try {
      final document = await _db.collection('userInvites').doc(token).get();
      if (!document.exists) {
        throw const UserInviteException(
          'invalid-invite',
          'Invitasjonen finnes ikke',
        );
      }
      final invite = UserInvite.fromDocument(document);
      if (!invite.canBeUsed) {
        throw UserInviteException(
          invite.effectiveStatus,
          invite.effectiveStatus == 'revoked'
              ? 'Invitasjonen er trukket tilbake'
              : 'Invitasjonen er utløpt eller allerede brukt',
        );
      }
      return invite;
    } on UserInviteException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _firebaseError(error);
    }
  }

  static Future<void> acceptInvite({
    required String token,
    String displayName = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const UserInviteException(
        'not-authenticated',
        'Logg inn med e-posten i invitasjonen',
      );
    }

    try {
      final inviteReference = _db.collection('userInvites').doc(token);
      final invite = UserInvite.fromDocument(await inviteReference.get());
      if (!invite.canBeUsed) {
        throw const UserInviteException(
          'invalid-invite',
          'Invitasjonen er utløpt eller allerede brukt',
        );
      }

      final authEmail = normalizeEmail(user.email!);
      if (authEmail != normalizeEmail(invite.email)) {
        throw const UserInviteException(
          'wrong-email',
          'Logg inn med e-posten som invitasjonen ble sendt til',
        );
      }

      final userReference = _db.collection('users').doc(user.uid);
      final batch = _db.batch();
      batch.set(userReference, {
        'email': authEmail,
        'emailLower': authEmail,
        'name': displayName.trim().isEmpty
            ? invite.displayName.trim()
            : displayName.trim(),
        'role': invite.role,
        'disabled': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'inviteId': invite.id,
      });
      batch.update(inviteReference, {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedByUid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on UserInviteException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _firebaseError(error);
    }
  }

  static Future<void> revokeInvite(String token) async {
    try {
      await _db.collection('userInvites').doc(token).update({
        'status': 'revoked',
        'disabled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw _firebaseError(error);
    }
  }

  static String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static UserInviteException _firebaseError(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return const UserInviteException(
        'permission-denied',
        'Du har ikke tilgang til å administrere brukere',
      );
    }
    if (error.code == 'unavailable') {
      return const UserInviteException(
        'unavailable',
        'Tjenesten er ikke tilgjengelig. Prøv igjen.',
      );
    }
    return const UserInviteException(
      'firebase-error',
      'Kunne ikke behandle invitasjonen. Prøv igjen.',
    );
  }
}
