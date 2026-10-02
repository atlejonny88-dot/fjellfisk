import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user_invite.dart';
import '../services/user_invite_service.dart';
import '../l10n/localizations.dart';

class InviteRegistrationScreen extends StatefulWidget {
  const InviteRegistrationScreen({
    super.key,
    required this.inviteToken,
    required this.onAccepted,
  });

  final String inviteToken;
  final VoidCallback onAccepted;

  @override
  State<InviteRegistrationScreen> createState() =>
      _InviteRegistrationScreenState();
}

class _InviteRegistrationScreenState extends State<InviteRegistrationScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late Future<UserInvite> _inviteFuture;
  bool _existingAccount = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  void _loadInvite() {
    _inviteFuture = UserInviteService.loadInvite(widget.inviteToken).then(
      (invite) {
        if (_nameController.text.isEmpty) {
          _nameController.text = invite.displayName;
        }
        return invite;
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit(UserInvite invite) async {
    final l10n = context.l10n;
    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() => _error = l10n.passwordMinimum);
      return;
    }
    if (!_existingAccount && password != _confirmPasswordController.text) {
      setState(() => _error = l10n.passwordsDoNotMatch);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user != null &&
          UserInviteService.normalizeEmail(user.email ?? '') !=
              UserInviteService.normalizeEmail(invite.email)) {
        throw UserInviteException(
          'wrong-email',
          l10n.wrongSignedInUser(user.email ?? ''),
        );
      }

      if (user == null) {
        if (_existingAccount) {
          await FirebaseAuth.instance
              .signInWithEmailAndPassword(
                email: invite.email,
                password: password,
              )
              .timeout(const Duration(seconds: 20));
        } else {
          final credential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
                email: invite.email,
                password: password,
              )
              .timeout(const Duration(seconds: 20));
          final name = _nameController.text.trim();
          if (name.isNotEmpty) await credential.user?.updateDisplayName(name);
        }
        user = FirebaseAuth.instance.currentUser;
      }

      if (user == null) {
        throw UserInviteException(
          'not-authenticated',
          l10n.couldNotCompleteInvitation,
        );
      }

      await UserInviteService.acceptInvite(
        token: widget.inviteToken,
        displayName: _nameController.text,
      ).timeout(const Duration(seconds: 20));
      widget.onAccepted();
    } on UserInviteException catch (error) {
      if (mounted) setState(() => _error = _inviteError(context, error));
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _authError(context, error));
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = context.l10n.serviceTimedOut);
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Invitasjonsregistrering feilet: $error\n$stackTrace');
      }
      if (mounted) {
        setState(() => _error = context.l10n.couldNotCompleteInvitation);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) setState(() => _error = null);
  }

  String _authError(BuildContext context, FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return context.l10n.alreadyHaveAccount;
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return context.l10n.invalidCredentials;
      case 'weak-password':
        return context.l10n.passwordMinimum;
      case 'network-request-failed':
        return context.l10n.loginNetworkFailed;
      default:
        return context.l10n.couldNotCompleteInvitation;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Fjellfisk 3.0',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<UserInvite>(
        future: _inviteFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            if (kDebugMode && snapshot.hasError) {
              debugPrint('Invitasjonen kunne ikke leses: ${snapshot.error}');
            }
            return _InvalidInvite(onRetry: () {
              setState(_loadInvite);
            });
          }
          return _registrationForm(snapshot.data!);
        },
      ),
    );
  }

  Widget _registrationForm(UserInvite invite) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final wrongSignedInUser = currentUser != null &&
        UserInviteService.normalizeEmail(currentUser.email ?? '') !=
            UserInviteService.normalizeEmail(invite.email);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDCE5EF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A082C51),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 42,
                  color: Color(0xFF0B63E5),
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n.invited,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF0A1733),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${invite.email}\n${context.l10n.roleLine(_roleLabel(context, invite.role))}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF5F7088)),
                ),
                const SizedBox(height: 22),
                if (wrongSignedInUser) ...[
                  Text(
                    context.l10n.wrongSignedInUser(currentUser.email ?? ''),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFD53C3C)),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: Text(context.l10n.logout),
                  ),
                ] else ...[
                  TextField(
                    controller: _nameController,
                    enabled: !_loading,
                    decoration:
                        InputDecoration(labelText: context.l10n.fullName),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    enabled: !_loading,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: context.l10n.password,
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? context.l10n.showPassword
                            : context.l10n.hidePassword,
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (!_existingAccount) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      enabled: !_loading,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: context.l10n.confirmPassword,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD53C3C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _loading ? null : () => _submit(invite),
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _existingAccount
                                ? Icons.login
                                : Icons.person_add_alt_1,
                          ),
                    label: Text(
                      _existingAccount
                          ? context.l10n.signInAndAccept
                          : context.l10n.createAccount,
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _existingAccount = !_existingAccount;
                              _error = null;
                            }),
                    child: Text(
                      _existingAccount
                          ? context.l10n.needNewAccount
                          : context.l10n.alreadyHaveAccount,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidInvite extends StatelessWidget {
  const _InvalidInvite({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 46, color: Color(0xFF7F8997)),
            const SizedBox(height: 12),
            Text(
              context.l10n.invalidInvitation,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.askAdminForInvitation,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

String _roleLabel(BuildContext context, String role) {
  if (role == 'admin') return context.l10n.roleAdmin;
  if (role == 'ansatt') return context.l10n.roleEmployee;
  return context.l10n.roleReader;
}

String _inviteError(BuildContext context, UserInviteException error) {
  return switch (error.code) {
    'invalid-invite' ||
    'expired' ||
    'revoked' =>
      context.l10n.invalidInvitation,
    'wrong-email' => context.l10n.signInWithInvitedEmail,
    'permission-denied' => context.l10n.contentUnavailable,
    'unavailable' => context.l10n.serviceTimedOut,
    _ => context.l10n.couldNotCompleteInvitation,
  };
}
