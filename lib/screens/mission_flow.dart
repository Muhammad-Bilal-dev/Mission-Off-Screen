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
    _ap.stop();
    _ap.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      // Clear any stray notifications now that we're in the app.
      await NotificationService.instance.cancelAll();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _error = 'Not signed in';
          _loading = false;
        });
        return;
      }

      // 1) Active child name
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final name = (userDoc.data()?['activeChildName'] as String?)?.trim();
      _childName = (name == null || name.isEmpty) ? 'buddy' : name;

      // 2) Fetch missions (root "missions")
      final ms = await FirebaseFirestore.instance.collection('missions').get();
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

      // 3) start the timer and (optionally) voice-over
      setState(() {
        _left = Duration(seconds: _durationSec);
        _loading = false;
      });

      if (_audioUrl.isNotEmpty) {
        try {
          await _ap.play(UrlSource(_audioUrl));
        } catch (_) {}
      }

      _startTicker();
    } catch (e) {
      setState(() {
        _error = 'Failed to load mission: $e';
        _loading = false;
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      final next = _left - const Duration(seconds: 1);
      if (next.isNegative || next == Duration.zero) {
        t.cancel();
        setState(() => _left = Duration.zero);
        await _completeAndLock();
      } else {
        setState(() => _left = next);
      }
    });
  }

  Future<void> _completeAndLock() async {
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
    } catch (_) {
      // non-fatal
    }

    if (!mounted) return;

    // Show celebration for ~6 seconds, then go to Locked
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _Celebration(seconds: 6),
    );

    // Mark complete (session lifecycle) and go to lock
    await SessionService.instance.complete();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/locked');
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mission'),
          automaticallyImplyLeading: false, // no back
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              style: TextStyle(color: cs.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async => false, // disable system back
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title),
          automaticallyImplyLeading: false, // hide back chevron
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _Mascot(),
                  const SizedBox(height: 16),
                  Text(
                    _prompt,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _fmt(_left),
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete your mission!',
                    style: Theme.of(context).textTheme.bodyLarge,
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

class _Mascot extends StatelessWidget {
  const _Mascot();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/milo_fox.png',
      height: 120,
      errorBuilder: (_, __, ___) => const Icon(Icons.celebration, size: 96),
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
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: widget.seconds), () {
      if (mounted) Navigator.of(context).pop(); // close dialog → continue flow
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lottie celebration (falls back to icon if asset missing at build time)
            SizedBox(
              height: 180,
              child: Lottie.asset(
                'assets/lottie/celebrate.json',
                repeat: true,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Amazing job!',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "We'll go on another mission tomorrow.",
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
