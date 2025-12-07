// lib/screens/parent_dashboard.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/notifications.dart';
import '../services/overlay_service.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  Duration _selectedDuration = const Duration(seconds: 30);
  Timer? _ticker;
  DateTime? _endAt;
  Duration _remaining = Duration.zero;
  String _childName = '';
  String _childId = '';
  String _currentPin = '';
  bool _overlayPermission = false;

  @override
  void initState() {
    super.initState();
    _watchUser();
    _fetchCurrentPin();
    _checkOverlayPermission();
  }

  Future<void> _checkOverlayPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await OverlayService.instance.checkPermission();
      if (mounted) setState(() => _overlayPermission = status);
    } else {
      if (mounted)
        setState(() => _overlayPermission = true); // Not needed on iOS
    }
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
        if (!mounted) return;
        final data = doc.data();
        setState(() {
          _childName = (data?['activeChildName'] as String?) ?? '';
          _childId = (data?['activeChildId'] as String?) ?? '';
        });
      },
    );
  }

  Future<void> _fetchCurrentPin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() {
          _currentPin = (doc.data()?['parentPin'] as String?) ?? '0000';
        });
      }
    } catch (e) {
      print('Error fetching current PIN: $e');
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // UPDATED _startTimer method
  Future<void> _startTimer() async {
    setState(() {
      _endAt = DateTime.now().add(_selectedDuration);
      _remaining = _selectedDuration;
    });

    try {
      final minutesForBackend = _selectedDuration.inMinutes.clamp(1, 10080);
      await SessionService.instance.start(
        childId: _childId,
        minutes: minutesForBackend,
        scheduleNotification: false,
      );

      await NotificationService.instance.scheduleIn(
        delay: _selectedDuration,
        payloadRoute: '/missionFlow',
      );

      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (!mounted) {
          t.cancel();
          return;
        }
        final left = _endAt?.difference(DateTime.now()) ?? Duration.zero;
        final safeLeft = left.isNegative ? Duration.zero : left;
        setState(() => _remaining = safeLeft);

        if (safeLeft == Duration.zero) {
          t.cancel();
          try {
            await SessionService.instance.markEnded();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error marking session ended: $e')),
              );
            }
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting timer: $e')),
        );
        _ticker?.cancel();
        _endAt = null;
        _remaining = Duration.zero;
        setState(() {});
      }
    }
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    _endAt = null;
    _remaining = Duration.zero;
    await NotificationService.instance.cancelAll();
    await SessionService.instance.cancel();
    if (mounted) {
      setState(() {});
    }
  }

  ChoiceChip _durChip({required Duration duration, required String label}) {
    final selected = _selectedDuration == duration;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color:
              selected ? Colors.white : Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      backgroundColor: Colors.transparent,
      selectedColor: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      onSelected: (s) {
        if (s) {
          if (mounted) {
            setState(() => _selectedDuration = duration);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool running = _endAt != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Parent Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: cs.primary,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: Icon(Icons.logout, color: cs.primary),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                navigator.pushNamedAndRemoveUntil('/login', (r) => false);
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              // Permission Warning
              if (!_overlayPermission &&
                  defaultTargetPlatform == TargetPlatform.android)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade800),
                      title: const Text('Permission Required'),
                      subtitle: const Text(
                          'Grant "Display over other apps" to lock screen.'),
                      trailing: FilledButton(
                        onPressed: () async {
                          await OverlayService.instance.requestPermission();
                          // Wait a bit or listen to lifecycle to recheck
                          // specific to app lifecycle usually, but here we can just recheck after return
                          await Future.delayed(const Duration(seconds: 1));
                          await _checkOverlayPermission();
                        },
                        child: const Text('Grant'),
                      ),
                    ),
                  ),
                ),

              // Child Profile Card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primaryContainer.withValues(alpha: 0.7),
                      cs.secondaryContainer.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primary,
                            ),
                            child: Center(
                              child: Text(
                                (_childName.isEmpty ? 'T' : _childName[0])
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Active Child',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  _childName.isEmpty ? '—' : _childName,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/children');
                            },
                            icon: Icon(Icons.family_restroom, size: 20),
                            label: Text('My Family'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _changePinDialog,
                            icon: Icon(Icons.pin, size: 20),
                            label: Text('Change PIN'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: cs.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: cs.primary, width: 1.5),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Timer Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Screen Time Session',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Choose a time and tell your child: 'When Milo's message arrives, it's mission time!' This is their cue to switch from their game to a fun, real-world adventure. After the mission, the phone takes a rest.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Select Duration:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _durChip(
                              duration: const Duration(seconds: 30),
                              label: '30 sec'),
                          _durChip(
                              duration: const Duration(minutes: 5),
                              label: '5 min'),
                          _durChip(
                              duration: const Duration(minutes: 10),
                              label: '10 min'),
                          _durChip(
                              duration: const Duration(minutes: 15),
                              label: '15 min'),
                          _durChip(
                              duration: const Duration(minutes: 20),
                              label: '20 min'),
                          _durChip(
                              duration: const Duration(minutes: 30),
                              label: '30 min'),
                          _durChip(
                              duration: const Duration(minutes: 45),
                              label: '45 min'),
                          _durChip(
                              duration: const Duration(hours: 1),
                              label: '60 min'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (!running) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _startTimer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 3,
                              shadowColor: cs.primary.withValues(alpha: 0.4),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Start Timer',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 180,
                                    height: 180,
                                    child: CircularProgressIndicator(
                                      value: 1 -
                                          (_remaining.inSeconds /
                                              _selectedDuration.inSeconds),
                                      strokeWidth: 8,
                                      backgroundColor: Colors.grey.shade300,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          cs.primary),
                                    ),
                                  ),
                                  Text(
                                    _fmt(_remaining),
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _cancel,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: Colors.red.shade400, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Text(
                                    'Cancel Timer',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
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
      ),
    );
  }

  Future<void> _changePinDialog() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ctrl = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Fetch current PIN if not already loaded
    if (_currentPin.isEmpty) {
      await _fetchCurrentPin();
    }

    final bool? pinWasSet = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        String? err;
        return StatefulBuilder(
            builder: (BuildContext sbfContext, StateSetter setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Change Parent PIN',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue.shade700, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Current PIN: $_currentPin',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'New 4-digit PIN',
                      errorText: err,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (_) {
                      if (err != null) {
                        setDialogState(() {
                          err = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext, false);
                        },
                        child: Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                          final v = ctrl.text.trim();
                          if (v.length != 4 || int.tryParse(v) == null) {
                            setDialogState(() {
                              err = 'Enter 4 digits';
                            });
                            return;
                          }
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .set(
                            {'parentPin': v},
                            SetOptions(merge: true),
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    if (pinWasSet == true) {
      // Refresh the current PIN after changing it
      await _fetchCurrentPin();

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('PIN updated successfully'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
