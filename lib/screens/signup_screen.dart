import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pwd = TextEditingController();
  final _pwd2 = TextEditingController();
  bool _busy = false;
  String? _err;
  bool _hide1 = true, _hide2 = true;

  @override
  void dispose() {
    _email.dispose();
    _pwd.dispose();
    _pwd2.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    if (_pwd.text != _pwd2.text) {
      setState(() => _err = 'Passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final email = _email.text.trim();

      // 1) Create auth user
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _pwd.text,
      );
      final uid = cred.user!.uid;

      // 2) Read global paywall flag (once)
      bool paywallEnabled = false;
      try {
        final cfg = await FirebaseFirestore.instance
            .collection('App_Config')
            .doc('global')
            .get();
        paywallEnabled = (cfg.data()?['paywallEnabled'] as bool?) ?? false;
      } catch (_) {
        // If config fetch fails, default is "free mode off" (paywall disabled = false)
      }

      // 3) Decide flags
      final bool earlyAdopter = !paywallEnabled;                 // true only while app is free
      final String subscriptionStatus = paywallEnabled ? 'none'  // new users when paywall ON
          : 'free'; // early adopters while free

      // 4) Create user profile
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'name': '',
        'role': 'parent',
        'earlyAdopter': earlyAdopter,
        'subscriptionStatus': subscriptionStatus, // 'none' | 'free' | 'premium'
        'createdAt': FieldValue.serverTimestamp(),
        'parentPin': '0000',
        'activeChildId': '',
        'activeChildName': '',
      }, SetOptions(merge: true));

      if (!mounted) return;
      // AuthGate + PaywallGate will route correctly after this.
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } on FirebaseAuthException catch (e) {
      setState(() => _err = e.message ?? 'Sign-up failed.');
    } catch (e) {
      setState(() => _err = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              24,
              16,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Form(
                        key: _form,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset('assets/images/logo.png', height: 84),
                            const SizedBox(height: 12),
                            Text('Create account',
                                style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 16),
                            if (_err != null)
                              Text(
                                _err!,
                                style: TextStyle(color: cs.error),
                                textAlign: TextAlign.center,
                              ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Enter a valid email'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pwd,
                              obscureText: _hide1,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _hide1 = !_hide1),
                                  icon: Icon(
                                    _hide1
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                ),
                              ),
                              validator: (v) =>
                              (v == null || v.length < 6)
                                  ? 'Min 6 characters'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pwd2,
                              obscureText: _hide2,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _hide2 = !_hide2),
                                  icon: Icon(
                                    _hide2
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                ),
                              ),
                              validator: (v) =>
                              (v == null || v.length < 6)
                                  ? 'Min 6 characters'
                                  : null,
                              onFieldSubmitted: (_) => _create(),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _busy ? null : _create,
                                child: _busy
                                    ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text('Sign Up'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () => Navigator.of(context)
                                  .pushReplacementNamed('/login'),
                              child: const Text(
                                  'Already have an account? Sign in'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
