import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/notifications.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  // Default to 30s for quick testing
  Duration _selectedDuration = const Duration(seconds: 30);

  Timer? _ticker;
  DateTime? _endAt;
  Duration _remaining = Duration.zero;

  String _childName = '';
  String _childId = '';

  @override
  void initState() {
    super.initState();
    _watchUser();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _watchUser() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen(
          (doc) {
        final data = doc.data();
        setState(() {
          _childName = (data?['activeChildName'] as String?) ?? '';
          _childId = (data?['activeChildId'] as String?) ?? '';
        });
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _startTimer() async {
    setState(() {
      _endAt = DateTime.now().add(_selectedDuration);
    });

    // Write session; do NOT auto-schedule here to avoid duplicate alarms.
    final minutesForBackend = _selectedDuration.inMinutes.clamp(1, 10080);
    await SessionService.instance.start(
      childId: _childId,
      minutes: minutesForBackend,
      scheduleNotification: false,
    );

    // Schedule EXACT one notification at the selected duration.
    await NotificationService.instance.scheduleIn(
      delay: _selectedDuration,
      payloadRoute: '/missionFlow',
    );

    // Local countdown only
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) async {
      final left = _endAt!.difference(DateTime.now());
      final safeLeft = left.isNegative ? Duration.zero : left;
      setState(() => _remaining = safeLeft);

      if (safeLeft == Duration.zero) {
        t.cancel();
        await SessionService.instance.markEnded();
      }
    });
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    _endAt = null;
    _remaining = Duration.zero;
    await NotificationService.instance.cancelAll();
    await SessionService.instance.cancel();
    setState(() {});
  }

  ChoiceChip _durChip({required Duration duration, required String label}) {
    final selected = _selectedDuration == duration;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (s) {
        if (s) setState(() => _selectedDuration = duration);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool running = _endAt != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (r) => false);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Header
            Card(
              color: cs.secondaryContainer.withOpacity(.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: cs.secondaryContainer,
                          child: Text(
                            (_childName.isEmpty ? 'T' : _childName[0]).toUpperCase(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Active child: ${_childName.isEmpty ? '—' : _childName}',
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/children'),
                          icon: const Icon(Icons.family_restroom),
                          label: const Text('My Family'),
                        ),
                        TextButton.icon(
                          onPressed: _changePinDialog,
                          icon: const Icon(Icons.pin),
                          label: const Text('Change PIN'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Timer card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Screen-time session',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'Set a duration and start. A local notification will bring your child back when time ends.',
                    ),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _durChip(duration: const Duration(seconds: 30), label: '30 sec'),
                        _durChip(duration: const Duration(minutes: 5), label: '5 min'),
                        _durChip(duration: const Duration(minutes: 10), label: '10 min'),
                        _durChip(duration: const Duration(minutes: 15), label: '15 min'),
                        _durChip(duration: const Duration(minutes: 20), label: '20 min'),
                        _durChip(duration: const Duration(minutes: 30), label: '30 min'),
                        _durChip(duration: const Duration(minutes: 45), label: '45 min'),
                        _durChip(duration: const Duration(hours: 1), label: '60 min'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (!running) ...[
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.timer),
                              label: const Text('Start timer'),
                              onPressed: _startTimer,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _fmt(_remaining),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _cancel,
                              child: const Text('Cancel'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePinDialog() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ctrl = TextEditingController();
    String? err;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Parent PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New 4-digit PIN',
                errorText: err,
              ),
              onChanged: (_) {
                if (err != null) {
                  err = null;
                  (context as Element).markNeedsBuild();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final v = ctrl.text.trim();
              if (v.length != 4 || int.tryParse(v) == null) {
                err = 'Enter 4 digits';
                (context as Element).markNeedsBuild();
                return;
              }
              await FirebaseFirestore.instance.collection('users').doc(uid).set(
                {'parentPin': v},
                SetOptions(merge: true),
              );
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('PIN updated')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
