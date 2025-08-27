import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LockedScreen extends StatefulWidget {
  const LockedScreen({super.key});

  @override
  State<LockedScreen> createState() => _LockedScreenState();
}

class _LockedScreenState extends State<LockedScreen> {
  final _pin = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final pin = (doc.data()?['parentPin'] as String?) ?? '0000';
      if (_pin.text.trim() == pin) {
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/dashboard', (route) => false);
      } else {
        setState(() => _err = 'Incorrect PIN');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Locked')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Mission Complete!',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Image.asset('assets/images/milo_fox.png', height: 96),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Enter Parent PIN to unlock',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  if (_err != null)
                    Text(_err!, style: TextStyle(color: cs.error)),
                  TextField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                      hintText: '4-digit PIN',
                    ),
                    onSubmitted: (_) => _unlock(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _unlock,
                      child: _busy
                          ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Unlock'),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
