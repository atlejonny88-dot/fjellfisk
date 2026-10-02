import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'l10n/language_controller.dart';
import 'l10n/localizations.dart';
import 'screens/dashboard_screen.dart';
import 'screens/invite_registration_screen.dart';
import 'screens/login_screen.dart';
import 'services/user_service.dart';
import 'services/registration_round.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FjellfiskApp());
}

class FjellfiskApp extends StatefulWidget {
  const FjellfiskApp({super.key});

  @override
  State<FjellfiskApp> createState() => _FjellfiskAppState();
}

class _FjellfiskAppState extends State<FjellfiskApp> {
  late Future<void> _firebaseInitFuture;
  late final String? _inviteToken;
  late final LanguageController _languageController;
  bool _inviteCompleted = false;

  @override
  void initState() {
    super.initState();
    _inviteToken = _inviteTokenFromUri(Uri.base);
    _languageController = LanguageController();
    _firebaseInitFuture = _initializeFirebase();
  }

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }

  String? _inviteTokenFromUri(Uri uri) {
    final match = RegExp(r'^/?invite/([^/?#]+)').firstMatch(uri.fragment);
    return match?.group(1);
  }

  void _completeInvite() {
    SystemNavigator.routeInformationUpdated(
      uri: Uri(path: '/'),
      replace: true,
    );
    setState(() => _inviteCompleted = true);
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 20));

    if (kIsWeb) {
      await _configureWebAuthPersistence();
    }
  }

  Future<void> _configureWebAuthPersistence() async {
    for (final persistence in [
      Persistence.LOCAL,
      Persistence.SESSION,
      Persistence.NONE,
    ]) {
      try {
        await FirebaseAuth.instance
            .setPersistence(persistence)
            .timeout(const Duration(seconds: 4));
        debugPrint('Fjellfisk web auth persistence: $persistence');
        return;
      } catch (error) {
        debugPrint(
          'Fjellfisk web auth persistence warning for $persistence: $error',
        );
      }
    }
  }

  void _retryStartup() {
    setState(() {
      _firebaseInitFuture = _initializeFirebase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _languageController,
      builder: (context, child) => LanguageScope(
        controller: _languageController,
        child: MaterialApp(
          title: 'Fjellfisk',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: _languageController.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('nb'), Locale('en'), Locale('pl')],
          initialRoute: '/',
          home: FutureBuilder<void>(
            future: _firebaseInitFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _LoadingScaffold(message: context.l10n.startingApp);
              }

              if (snapshot.hasError) {
                debugPrint(
                    'Fjellfisk Firebase startup error: ${snapshot.error}');
                return _ErrorScaffold(
                  title: context.l10n.startupFailedTitle,
                  message: context.l10n.startupFailedMessage,
                  actionLabel: context.l10n.retry,
                  icon: Icons.cloud_off,
                  onAction: _retryStartup,
                );
              }

              if (_inviteToken != null && !_inviteCompleted) {
                return InviteRegistrationScreen(
                  inviteToken: _inviteToken!,
                  onAccepted: _completeInvite,
                );
              }

              return _AuthGate(
                onUserLanguageLoaded: _languageController.loadForCurrentUser,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.onUserLanguageLoaded});

  final Future<void> Function() onUserLanguageLoaded;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  int _authRetry = 0;

  Stream<User?> _authStateStream() async* {
    final auth = FirebaseAuth.instance;
    User? lastUser = await auth.authStateChanges().first.timeout(
          const Duration(seconds: 15),
          onTimeout: () => auth.currentUser,
        );

    RegistrationRound.session.setUser(lastUser?.uid);
    yield lastUser;

    await for (final user in auth.authStateChanges()) {
      if (user?.uid == lastUser?.uid) continue;
      lastUser = user;
      RegistrationRound.session.setUser(user?.uid);
      yield user;
    }
  }

  void _retryAuth() {
    setState(() {
      _authRetry++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      key: ValueKey(_authRetry),
      stream: _authStateStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _LoadingScaffold(message: context.l10n.checkingLogin);
        }

        if (snapshot.hasError) {
          debugPrint('Fjellfisk auth state error: ${snapshot.error}');
          return _ErrorScaffold(
            title: context.l10n.loginCheckFailedTitle,
            message: context.l10n.loginCheckFailedMessage,
            actionLabel: context.l10n.retry,
            icon: Icons.lock_clock,
            onAction: _retryAuth,
          );
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        return UserAccessGate(
          userId: snapshot.data!.uid,
          onUserLanguageLoaded: widget.onUserLanguageLoaded,
        );
      },
    );
  }
}

class UserAccessGate extends StatefulWidget {
  const UserAccessGate({
    super.key,
    required this.userId,
    required this.onUserLanguageLoaded,
  });

  final String userId;
  final Future<void> Function() onUserLanguageLoaded;

  @override
  State<UserAccessGate> createState() => _UserAccessGateState();
}

class _UserAccessGateState extends State<UserAccessGate> {
  late Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _loadRole();
  }

  @override
  void didUpdateWidget(covariant UserAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _roleFuture = _loadRole();
    }
  }

  Future<String> _loadRole() async {
    await UserService.createUserDocumentIfMissing()
        .timeout(const Duration(seconds: 15));
    final role = await UserService.getCurrentUserRole().timeout(
      const Duration(seconds: 15),
    );
    await widget.onUserLanguageLoaded();
    return role;
  }

  void _retryRoleLoad() {
    setState(() {
      _roleFuture = _loadRole();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _LoadingScaffold(message: context.l10n.checkingAccess);
        }

        if (snapshot.hasError) {
          debugPrint('Fjellfisk user access error: ${snapshot.error}');
          return _AccessErrorScaffold(
            onRetry: _retryRoleLoad,
            accessDenied: snapshot.error is UserAccessDeniedException,
          );
        }

        if (snapshot.data == 'deaktivert') {
          return const _DisabledUserScaffold();
        }

        return const DashboardScreen(
          facilityId: 'default_facility',
          facilityName: 'Fjellfisk',
        );
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.icon,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final IconData icon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel),
                onPressed: onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessErrorScaffold extends StatelessWidget {
  const _AccessErrorScaffold({
    required this.onRetry,
    required this.accessDenied,
  });

  final VoidCallback onRetry;
  final bool accessDenied;

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                accessDenied
                    ? context.l10n.accessDeniedTitle
                    : context.l10n.roleCheckFailedTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                accessDenied
                    ? context.l10n.accessDeniedMessage
                    : context.l10n.roleCheckFailedMessage,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.retry),
                    onPressed: onRetry,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: Text(context.l10n.logout),
                    onPressed: _signOut,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisabledUserScaffold extends StatelessWidget {
  const _DisabledUserScaffold();

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off, size: 48),
              const SizedBox(height: 12),
              Text(
                context.l10n.userDisabledTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.userDisabledDetail,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.logout),
                label: Text(context.l10n.logout),
                onPressed: _signOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
