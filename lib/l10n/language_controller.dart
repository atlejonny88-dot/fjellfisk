import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/user_service.dart';

enum AppLanguage {
  norwegian('nb', '🇳🇴'),
  english('en', '🇬🇧'),
  polish('pl', '🇵🇱');

  const AppLanguage(this.code, this.flag);

  final String code;
  final String flag;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'en':
        return AppLanguage.english;
      case 'pl':
        return AppLanguage.polish;
      case 'nb':
      case 'no':
      default:
        return AppLanguage.norwegian;
    }
  }
}

class LanguageController extends ChangeNotifier {
  LanguageController({
    Future<String> Function()? loadLanguage,
    Future<void> Function(String languageCode)? saveLanguage,
  })  : _loadLanguage = loadLanguage,
        _saveLanguage = saveLanguage;

  final Future<String> Function()? _loadLanguage;
  final Future<void> Function(String languageCode)? _saveLanguage;
  AppLanguage _language = AppLanguage.norwegian;

  AppLanguage get language => _language;
  Locale get locale => _language.locale;

  /// Loads the selected language for the signed-in user. Missing, old and
  /// invalid values intentionally resolve to Norwegian.
  Future<void> loadForCurrentUser() async {
    try {
      final next = AppLanguage.fromCode(
        await (_loadLanguage?.call() ??
            UserService.getCurrentUserPreferredLanguage()),
      );
      if (next != _language) {
        _language = next;
        notifyListeners();
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
            'Fjellfisk språkvalg kunne ikke lastes: $error\n$stackTrace');
      }
    }
  }

  /// Applies the language immediately, then persists it to the user's
  /// profile. A failed profile write never blocks the current UI language.
  Future<void> select(AppLanguage next) async {
    if (next != _language) {
      _language = next;
      notifyListeners();
    }
    if (_saveLanguage != null) {
      await _saveLanguage!(next.code);
      return;
    }
    if (UserService.currentUser != null) {
      await UserService.setCurrentUserPreferredLanguage(next.code);
    }
  }
}

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static LanguageController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    assert(scope != null, 'LanguageScope mangler over dette widget-treet.');
    return scope!.notifier!;
  }
}
