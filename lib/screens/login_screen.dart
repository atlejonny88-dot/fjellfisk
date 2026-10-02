import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/language_controller.dart';
import '../l10n/localizations.dart';
import '../utils/ui_motion.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _buildName =
      String.fromEnvironment('FLUTTER_BUILD_NAME', defaultValue: '3.0.0');

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _cardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _cardVisible = true);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = context.l10n.enterEmailAndPassword;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 20));
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = _authErrorText(context, e);
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error = context.l10n.loginTimeout;
        });
      }
    } catch (e) {
      debugPrint('Innlogging feilet: $e');
      if (mounted) {
        setState(() {
          _error = context.l10n.loginFailed;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _authErrorText(BuildContext context, FirebaseAuthException e) {
    final l10n = context.l10n;
    switch (e.code) {
      case 'invalid-email':
        return l10n.invalidEmail;
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return l10n.invalidCredentials;
      case 'user-disabled':
        return l10n.userDisabledMessage;
      case 'too-many-requests':
        return l10n.tooManyLoginAttempts;
      case 'network-request-failed':
        return l10n.loginNetworkFailed;
      default:
        debugPrint('Innlogging feilet: $e');
        return l10n.loginFailed;
    }
  }

  Future<void> _changeLanguage(AppLanguage language) async {
    try {
      await LanguageScope.of(context).select(language);
    } catch (error, stackTrace) {
      debugPrint('Fjellfisk språkvalg på login: $error\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final duration = uiMotionDuration(
      context,
      duration: const Duration(milliseconds: 240),
    );
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _LoginWaterLinesPainter()),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 480;
                final horizontalPadding = narrow ? 20.0 : 32.0;
                final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
                return Stack(
                  children: [
                    Positioned(
                      top: 4,
                      right: 8,
                      child: _LoginLanguageButton(
                        language: LanguageScope.of(context).language,
                        onSelected: _changeLanguage,
                      ),
                    ),
                    SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        66,
                        horizontalPadding,
                        bottomInset + 28,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 94,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 432),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _LoginBrand(tagline: l10n.loginTagline),
                                const SizedBox(height: 30),
                                AnimatedOpacity(
                                  duration: duration,
                                  curve: Curves.easeOut,
                                  opacity:
                                      uiMotionDisabled(context) || _cardVisible
                                          ? 1
                                          : 0,
                                  child: AnimatedSlide(
                                    duration: duration,
                                    curve: Curves.easeOutCubic,
                                    offset: uiMotionDisabled(context) ||
                                            _cardVisible
                                        ? Offset.zero
                                        : const Offset(0, 0.025),
                                    child: _LoginPanel(
                                      emailController: _emailCtrl,
                                      passwordController: _passwordCtrl,
                                      loading: _loading,
                                      error: _error,
                                      onSubmit: _login,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  l10n.appVersion(_buildName),
                                  style: const TextStyle(
                                    color: Color(0xFF7A8BA2),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBrand extends StatelessWidget {
  const _LoginBrand({required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFF082C51),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A082C51),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.terrain_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          context.l10n.appTitle,
          style: const TextStyle(
            color: Color(0xFF0A1733),
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF5F7088),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final duration = uiMotionDuration(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE5EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12082C51),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.login,
            style: const TextStyle(
              color: Color(0xFF0A1733),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.loginContinue,
            style: const TextStyle(
              color: Color(0xFF61718A),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username],
            autocorrect: false,
            textInputAction: TextInputAction.next,
            enabled: !loading,
            decoration: InputDecoration(
              labelText: l10n.email,
              hintText: l10n.emailHint,
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            autocorrect: false,
            textInputAction: TextInputAction.done,
            enabled: !loading,
            onSubmitted: (_) {
              if (!loading) onSubmit();
            },
            decoration: InputDecoration(
              labelText: l10n.password,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
            ),
          ),
          AnimatedSize(
            duration: duration,
            curve: Curves.easeOut,
            child: AnimatedSwitcher(
              duration: duration,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: error == null
                  ? const SizedBox(key: ValueKey('no-login-error'))
                  : Container(
                      key: ValueKey(error),
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEEE),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFFF3C4C4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFFB42318),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error!,
                              style: const TextStyle(
                                color: Color(0xFF9B2017),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              child: AnimatedSwitcher(
                duration: duration,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: loading
                    ? Row(
                        key: const ValueKey('login-loading'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(l10n.signingIn),
                        ],
                      )
                    : Text(
                        l10n.signIn,
                        key: const ValueKey('login-idle'),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginLanguageButton extends StatelessWidget {
  const _LoginLanguageButton({
    required this.language,
    required this.onSelected,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<AppLanguage>(
      tooltip: l10n.changeLanguage,
      onSelected: onSelected,
      color: Colors.white,
      itemBuilder: (context) => [
        _item(AppLanguage.norwegian, l10n.norwegian),
        _item(AppLanguage.english, 'English'),
        _item(AppLanguage.polish, 'Polski'),
      ],
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDCE5EF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D082C51),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: uiMotionDuration(context),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: Text(
            language.flag,
            key: ValueKey(language.code),
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  PopupMenuEntry<AppLanguage> _item(AppLanguage value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Text(value.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

class _LoginWaterLinesPainter extends CustomPainter {
  const _LoginWaterLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF0B63E5).withValues(alpha: 0.07);
    final lighterPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF315477).withValues(alpha: 0.045);

    for (var index = 0; index < 5; index++) {
      final y = size.height * (0.16 + index * 0.19);
      final path = Path()
        ..moveTo(-24, y)
        ..cubicTo(
          size.width * 0.2,
          y - 24,
          size.width * 0.42,
          y + 24,
          size.width * 0.62,
          y,
        )
        ..cubicTo(
          size.width * 0.8,
          y - 22,
          size.width * 0.95,
          y + 16,
          size.width + 24,
          y - 4,
        );
      canvas.drawPath(path, index.isEven ? paint : lighterPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LoginWaterLinesPainter oldDelegate) => false;
}
