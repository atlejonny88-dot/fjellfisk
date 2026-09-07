import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserAccessDeniedException implements Exception {
  const UserAccessDeniedException([
    this.message = 'Du har ikke tilgang til Fjellfisk. Kontakt administrator.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const roles = ['admin', 'ansatt', 'leser'];

  static User? get currentUser => _auth.currentUser;

  static String? get currentUserId => _auth.currentUser?.uid;

  static Future<void> createUserDocumentIfMissing() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _db.collection('users').doc(user.uid);

    try {
      final snap = await userRef.get();

      if (!snap.exists) {
        throw const UserAccessDeniedException();
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const UserAccessDeniedException();
      }
      rethrow;
    }
  }

  static Future<String> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return 'leser';

    try {
      final snap = await _db.collection('users').doc(user.uid).get();

      if (!snap.exists) throw const UserAccessDeniedException();

      final data = snap.data();
      if (data?['disabled'] == true) return 'deaktivert';

      final role = (data?['role'] ?? 'leser').toString();
      return roles.contains(role) ? role : 'leser';
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw FirebaseException(
          plugin: e.plugin,
          code: e.code,
          message: 'Mangler tilgang til brukerrollen. Be admin kontrollere at '
              'brukeren finnes i users og ikke er deaktivert.',
        );
      }
      rethrow;
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> usersStream() {
    return _db.collection('users').orderBy('email').snapshots();
  }

  static Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    if (!roles.contains(role)) {
      throw ArgumentError('Ugyldig rolle: $role');
    }

    await _db.collection('users').doc(userId).set({
      'role': role,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  static Future<void> setUserDisabled({
    required String userId,
    required bool disabled,
  }) async {
    await _db.collection('users').doc(userId).set({
      'disabled': disabled,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> currentUserStream() {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Ingen bruker er logget inn');
    }

    return _db.collection('users').doc(user.uid).snapshots();
  }
}
