import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user_invite.dart';
import '../services/user_invite_service.dart';

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
    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() => _error = 'Passordet må ha minst 6 tegn');
      return;
    }
    if (!_existingAccount && password != _confirmPasswordController.text) {
      setState(() => _error = 'Passordene er ikke like');
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
        throw const UserInviteException(
          'wrong-email',
          'Du er logget inn med en annen e-post. Logg ut og prøv igjen.',
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
        throw const UserInviteException(
          'not-authenticated',
          'Kunne ikke fullføre innloggingen',
        );
      }

      await UserInviteService.acceptInvite(
        token: widget.inviteToken,
        displayName: _nameController.text,
      ).timeout(const Duration(seconds: 20));
      widget.onAccepted();
    } on UserInviteException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _authError(error));
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = 'Tjenesten brukte for lang tid. Prøv igjen.');
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Invitasjonsregistrering feilet: $error\n$stackTrace');
      }
      if (mounted) {
        setState(() => _error = 'Kunne ikke fullføre invitasjonen');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) setState(() => _error = null);
  }

  String _authError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'E-posten har allerede en konto. Velg «Jeg har konto».';
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'Feil e-post eller passord';
      case 'weak-password':
        return 'Passordet er for svakt';
      case 'network-request-failed':
        return 'Fikk ikke kontakt med innloggingstjenesten';
      default:
        return 'Kunne ikke opprette eller logge inn på kontoen';
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
                const Text(
                  'Du er invitert',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0A1733),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${invite.email}\nRolle: ${_roleLabel(invite.role)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF5F7088)),
                ),
                const SizedBox(height: 22),
                if (wrongSignedInUser) ...[
                  Text(
                    'Du er logget inn som ${currentUser.email}. Logg ut for å bruke invitasjonen.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFD53C3C)),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logg ut'),
                  ),
                ] else ...[
                  TextField(
                    controller: _nameController,
                    enabled: !_loading,
                    decoration: const InputDecoration(labelText: 'Navn'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    enabled: !_loading,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Passord',
                      suffixIcon: IconButton(
                        tooltip:
                            _obscurePassword ? 'Vis passord' : 'Skjul passord',
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
                      decoration: const InputDecoration(
                        labelText: 'Gjenta passord',
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
                      _existingAccount ? 'Logg inn og godta' : 'Opprett konto',
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
                          ? 'Jeg trenger en ny konto'
                          : 'Jeg har allerede konto',
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
            const Text(
              'Invitasjonen er ugyldig eller utløpt',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be administrator opprette en ny invitasjon.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Prøv igjen'),
            ),
          ],
        ),
      ),
    );
  }
}

String _roleLabel(String role) {
  if (role == 'admin') return 'Admin';
  if (role == 'ansatt') return 'Ansatt';
  return 'Leser';
}
