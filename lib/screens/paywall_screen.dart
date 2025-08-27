import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  Future<bool> _goToLogin(BuildContext context) async {
    // Sign out first so AuthGate shows the login screen.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    }
    // We handled navigation; tell the system not to pop the route itself.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () => _goToLogin(context), // hardware/system back
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo.png', height: 84),
                  const SizedBox(height: 16),
                  Text(
                    'Premium Feature',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Thanks for your interest! This feature is part of our premium plan.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Early adopters keep access for free.\n'
                          'If you signed up while the app was free, you won’t see this screen.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // This button behaves like “back”, but ensures we sign out
                  // and land on the login screen every time.
                  FilledButton(
                    onPressed: () => _goToLogin(context),
                    child: const Text('Back to Sign In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
