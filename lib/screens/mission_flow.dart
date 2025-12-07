// lib/screens/mission_flow.dart
import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/notifications.dart';
import '../services/session_service.dart';

/// MissionFlow:
/// - random mission from /missions
/// - personalizes with active child's name
/// - optional voice-over
/// - countdown
/// - on end: writes mission log, shows 6s celebration, then navigates to /locked
class MissionFlow extends StatefulWidget {
  const MissionFlow({super.key});

  @override
  State<MissionFlow> createState() => _MissionFlowState();
}

class _MissionFlowState extends State<MissionFlow> {
  bool _loading = true;
  String? _error;

  String _childName = 'buddy';
  String _missionId = '';
  String _title = 'Mission';
  String _prompt = 'Get ready!';
  int _durationSec = 60;
  String _audioUrl = '';

  Duration _left = Duration.zero;
  Timer? _ticker;

  final _ap = AudioPlayer(); // web-safe

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ap.stop(); // Ensure audio is stopped
    _ap.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      // Clear any stray notifications now that we're in the app.
      NotificationService.instance.cancelAll().then((_) {}).catchError((e) {});

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Not signed in';
          _loading = false;
        });
        return;
      }

      // 1) Active child name
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      final name = (userDoc.data()?['activeChildName'] as String?)?.trim();
      _childName = (name == null || name.isEmpty) ? 'buddy' : name;

      // 2) Fetch missions (root "missions")
      final ms = await FirebaseFirestore.instance.collection('missions').get();
      if (!mounted) return;
      if (ms.docs.isEmpty) {
        setState(() {
          _error = 'No missions found. Add docs to the "missions" collection.';
          _loading = false;
        });
        return;
      }

      // Choose a random mission
      final doc = ms.docs[Random().nextInt(ms.docs.length)];
      final m = doc.data();

      _missionId = doc.id;
      _title = (m['title'] as String?) ?? 'Mission';
      final template =
          (m['promptTemplate'] as String?) ?? 'Hi {name}! Ready for a mission?';
      _prompt = template.replaceAll('{name}', _childName);
      _durationSec = (m['durationSec'] as num?)?.toInt() ?? 60;
      _audioUrl = (m['audioUrl'] as String?) ?? '';

      // 3) Set initial state and START THE TICKER IMMEDIATELY
      if (!mounted) return;
      setState(() {
        _left = Duration(seconds: _durationSec);
        _loading = false;
      });

      _startTicker(); // Start ticker as soon as UI is ready to display the time

      // 4) Play audio (optionally) without awaiting it before ticker starts
      if (_audioUrl.isNotEmpty) {
        _ap.play(UrlSource(_audioUrl)).then((_) {}).catchError((e) {});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load mission: $e';
        _loading = false;
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel(); // Cancel any existing ticker

    // Ensure _left has a valid duration before starting
    if (_left <= Duration.zero && _durationSec > 0) {
      _left = Duration(seconds: _durationSec);
    }

    // If duration is zero or less, complete immediately
    if (_left <= Duration.zero) {
      if (mounted) {
        setState(() {
          _left = Duration.zero;
        });
      }
      _completeAndLock(); // No need for a ticker
      return;
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final Duration nextDuration = _left - const Duration(seconds: 1);

      if (nextDuration.isNegative || nextDuration == Duration.zero) {
        timer.cancel();
        if (mounted) {
          setState(() => _left = Duration.zero);
        }
        await _completeAndLock();
      } else {
        if (mounted) {
          setState(() => _left = nextDuration);
        }
      }
    });
  }

  Future<void> _completeAndLock() async {
    _ticker?.cancel();
    _ap.stop(); // Stop audio if it was playing

    // Write mission log
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('missionLogs')
            .add({
          'missionId': _missionId,
          'title': _title,
          'childName': _childName,
          'completedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // non-fatal
    }

    if (!mounted) return;

    // Show celebration for ~6 seconds, then go to Locked
    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _Celebration(seconds: 6),
      );
    }

    // Mark complete (session lifecycle) and go to lock
    try {
      await SessionService.instance.complete();
    } catch (e) {}

    if (!mounted) return;
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/locked');
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
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
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: cs.primary,
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: cs.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: cs.error, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Go Back'),
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false, // Prevent back navigation during mission
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: cs.primary,
          automaticallyImplyLeading: false,
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Beautiful mascot image with decorative elements
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Decorative background circles
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                cs.primary.withValues(alpha: 0.2),
                                cs.primary.withValues(alpha: 0.05),
                              ],
                              stops: const [0.1, 1.0],
                            ),
                          ),
                        ),
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                cs.primary.withValues(alpha: 0.15),
                                cs.primary.withValues(alpha: 0.05),
                              ],
                              stops: const [0.1, 1.0],
                            ),
                          ),
                        ),
                        // Mascot image container with shadow and border
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.3),
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/milo_fox.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stackTrace) {
                                return Icon(
                                  Icons.face,
                                  size: 80,
                                  color: cs.primary,
                                );
                              },
                            ),
                          ),
                        ),
                        // Decorative elements
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.amber.withValues(alpha: 0.7),
                            ),
                            child: Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.withValues(alpha: 0.7),
                            ),
                            child: Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            _prompt,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _fmt(_left),
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                    fontSize: 48,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Complete your mission!',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Celebration extends StatefulWidget {
  const _Celebration({this.seconds = 6});
  final int seconds;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> {
  Timer? _dialogTimer;

  @override
  void initState() {
    super.initState();
    _dialogTimer = Timer(Duration(seconds: widget.seconds), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _dialogTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration image with decorative elements
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.amber.withValues(alpha: 0.2),
                          Colors.amber.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Lottie.asset(
                        'assets/lottie/celebrate.json',
                        repeat: true,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.celebration,
                            size: 60,
                            color: cs.primary,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Amazing job!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "We'll go on another mission tomorrow.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
