import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/localizations.dart';

String loadErrorMessage(BuildContext context, Object? error) {
  debugPrint('Kunne ikke hente data: $error');
  if (error is FirebaseException && error.code == 'permission-denied') {
    return context.l10n.dataPermissionDenied;
  }
  return context.l10n.dataLoadFailed;
}
