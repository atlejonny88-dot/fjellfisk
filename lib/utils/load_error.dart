import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

String loadErrorMessage(Object? error) {
  debugPrint('Kunne ikke hente data: $error');
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Du har ikke tilgang til disse dataene. Kontakt administrator.';
  }
  return 'Kunne ikke hente data. Kontroller nettverket og prøv igjen.';
}
