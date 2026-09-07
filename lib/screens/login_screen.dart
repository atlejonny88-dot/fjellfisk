import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Skriv inn e-post og passord.';
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
          _error = _authErrorText(e);
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error =
              'Innlogging tok for lang tid. Lukk Safari helt og prøv igjen.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Kunne ikke logge inn: $e';
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

  String _authErrorText(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Ugyldig e-postadresse.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Feil e-post eller passord.';
      case 'user-disabled':
        return 'Brukeren er deaktivert. Kontakt admin.';
      case 'too-many-requests':
        return 'For mange forsøk. Vent litt og prøv igjen.';
      case 'network-request-failed':
        return 'Fikk ikke kontakt med innloggingstjenesten. Sjekk internett.';
      default:
        return e.message ?? 'Kunne ikke logge inn. Prøv igjen.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Fjellfisk',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'E-post'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_loading) {
                      _login();
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Passord'),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Logg inn'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
