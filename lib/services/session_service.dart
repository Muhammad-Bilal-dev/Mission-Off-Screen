// lib/services/session_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notifications.dart';
import '../utils/app_logger.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      AppLogger.log(
          '[SessionService_LOG] _col: User not logged in (uid is null).');
      return null;
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sessions');
  }

  Stream<Map<String, dynamic>?> watchRaw() {
    // AppLogger.log('[SessionService_LOG] watchRaw() called.');
    final c = _col;
    if (c == null) {
      return const Stream.empty();
    }
    return c.orderBy('startAt', descending: true).limit(1).snapshots().map(
          (snap) => snap.docs.isEmpty ? null : snap.docs.first.data(),
        );
  }

  Future<void> start({
    required String childId,
    required int minutes,
    bool scheduleNotification = true,
  }) async {
    AppLogger.log(
        '[SessionService_LOG] start() called. childId: $childId, minutes: $minutes, scheduleNotification: $scheduleNotification');
    final c = _col;
    if (c == null) {
      AppLogger.log(
          '[SessionService_LOG] start() aborted: Firestore collection is null (user not logged in?).');
      return;
    }

    final now = DateTime.now().toUtc();
    final end = now.add(Duration(minutes: minutes));

    AppLogger.log(
        '[SessionService_LOG] Adding session to Firestore. Start: $now, End: $end');
    try {
      await c.add({
        'childId': childId,
        'minutes': minutes,
        'status': 'running',
        'startAt': Timestamp.fromDate(now),
        'endAt': Timestamp.fromDate(end),
        'pausedAt': null,
      });
      AppLogger.log(
          '[SessionService_LOG] Session added to Firestore successfully.');
    } catch (e, s) {
      AppLogger.log(
          '[SessionService_LOG] ERROR adding session to Firestore: $e');
      AppLogger.log(
          '[SessionService_LOG] Stack trace for Firestore add error: $s');
      return;
    }

    if (scheduleNotification) {
      AppLogger.log(
          '[SessionService_LOG] scheduleNotification is true. Calling NotificationService.instance.scheduleIn(). Delay: ${Duration(minutes: minutes)}');
      try {
        await NotificationService.instance.scheduleIn(
          delay: Duration(minutes: minutes),
          title: "Time's up for $childId!", // Example: More dynamic title
          body: "Your $minutes minute session has ended. Tap to continue.",
          payloadRoute: '/missionFlow',
        );
        AppLogger.log(
            '[SessionService_LOG] NotificationService.instance.scheduleIn() call completed.');
      } catch (e, s) {
        AppLogger.log(
            '[SessionService_LOG] ERROR calling NotificationService.instance.scheduleIn(): $e');
        AppLogger.log(
            '[SessionService_LOG] Stack trace for scheduleIn error: $s');
      }
    } else {
      AppLogger.log(
          '[SessionService_LOG] scheduleNotification is false. Skipping notification scheduling.');
    }
    AppLogger.log('[SessionService_LOG] start() finished.');
  }

  Future<void> pause() async {
    AppLogger.log('[SessionService_LOG] pause() called.');
    final last = await _latestDoc();
    if (last == null) {
      AppLogger.log(
          '[SessionService_LOG] pause() aborted: No latest document found.');
      return;
    }
    await NotificationService.instance.cancelAll();
    try {
      await last.reference.update({
        'status': 'paused',
        'pausedAt': Timestamp.fromDate(DateTime.now().toUtc()),
      });
      AppLogger.log(
          '[SessionService_LOG] Session paused successfully in Firestore.');
    } catch (e, s) {
      AppLogger.log(
          '[SessionService_LOG] ERROR pausing session in Firestore: $e');
      AppLogger.log(
          '[SessionService_LOG] Stack trace for Firestore pause error: $s');
    }
    AppLogger.log('[SessionService_LOG] pause() finished.');
  }

  Future<void> resume() async {
    AppLogger.log('[SessionService_LOG] resume() called.');
    final last = await _latestDoc();
    if (last == null) {
      AppLogger.log(
          '[SessionService_LOG] resume() aborted: No latest document found.');
      return;
    }

    final data = last.data();

    final endAtStamp = data['endAt'] as Timestamp?;
    final pausedAtStamp = data['pausedAt'] as Timestamp?;

    if (endAtStamp == null || pausedAtStamp == null) {
      AppLogger.log(
          '[SessionService_LOG] resume() aborted: endAt or pausedAt is null. Cannot calculate remaining time.');
      try {
        await last.reference.update({'status': 'running', 'pausedAt': null});
        AppLogger.log(
            '[SessionService_LOG] resume(): Set status to running, cleared pausedAt, but could not reschedule notification due to missing time data.');
      } catch (e) {
        AppLogger.log(
            '[SessionService_LOG] resume(): Error updating status to running when time data was missing: $e');
      }
      return;
    }

    final DateTime originalEndAt = endAtStamp.toDate().toUtc();
    final DateTime timeWhenPaused = pausedAtStamp.toDate().toUtc();
    final DateTime now = DateTime.now().toUtc();

    Duration timeSpentPaused = now.difference(timeWhenPaused);
    if (timeSpentPaused.isNegative) timeSpentPaused = Duration.zero;
    AppLogger.log('[SessionService_LOG] Time spent paused: $timeSpentPaused');

    DateTime newTargetEndAt = originalEndAt.add(timeSpentPaused);
    Duration timeRemainingForNotification = newTargetEndAt.difference(now);

    AppLogger.log(
        '[SessionService_LOG] Original endAt: $originalEndAt, PausedAt: $timeWhenPaused, Now: $now, New Target EndAt: $newTargetEndAt, Time Remaining For Notification: $timeRemainingForNotification');

    if (timeRemainingForNotification.isNegative) {
      timeRemainingForNotification = Duration.zero;
    }

    if (timeRemainingForNotification > Duration.zero) {
      AppLogger.log(
          '[SessionService_LOG] resume(): Scheduling notification. Remaining: $timeRemainingForNotification');
      await NotificationService.instance.scheduleIn(
        delay: timeRemainingForNotification,
        payloadRoute: '/missionFlow',
      );
    } else {
      AppLogger.log(
          '[SessionService_LOG] resume(): No remaining time or negative. Notification not rescheduled.');
    }

    try {
      await last.reference.update({
        'status': 'running',
        'pausedAt': null,
        'endAt': Timestamp.fromDate(newTargetEndAt)
      });
      AppLogger.log(
          '[SessionService_LOG] Session resumed successfully in Firestore. New endAt: $newTargetEndAt');
    } catch (e, s) {
      AppLogger.log(
          '[SessionService_LOG] ERROR resuming session in Firestore: $e');
      AppLogger.log(
          '[SessionService_LOG] Stack trace for Firestore resume error: $s');
    }
    AppLogger.log('[SessionService_LOG] resume() finished.');
  }

  Future<void> markEnded() async {
    AppLogger.log('[SessionService_LOG] markEnded() called.');
    final last = await _latestDoc();
    if (last == null) {
      AppLogger.log(
          '[SessionService_LOG] markEnded() aborted: No latest document found.');
      return;
    }
    try {
      await last.reference.update({'status': 'ended'});
      AppLogger.log(
          '[SessionService_LOG] Session marked as ended in Firestore.');
    } catch (e, s) {
      AppLogger.log(
          '[SessionService_LOG] ERROR marking session ended in Firestore: $e');
      AppLogger.log(
          '[SessionService_LOG] Stack trace for Firestore markEnded error: $s');
    }
    AppLogger.log('[SessionService_LOG] markEnded() finished.');
  }

  Future<void> complete() async {
    AppLogger.log('[SessionService_LOG] complete() called.');
    final last = await _latestDoc();
    if (last == null) {
      AppLogger.log(
          '[SessionService_LOG] complete() aborted: No latest document found.');
      return;
    }
    try {
      await last.reference.update({'status': 'complete'});
      AppLogger.log(
          '[SessionService_LOG] Session marked as complete in Firestore.');
    } catch (e, s) {
      AppLogger.log(
          '[SessionService_LOG] ERROR marking session complete in Firestore: $e');
      AppLogger.log(
          '[SessionService_LOG] Stack trace for Firestore complete error: $s');
    }
    AppLogger.log('[SessionService_LOG] complete() finished.');
  }

  Future<void> cancel() async {
    AppLogger.log('[SessionService_LOG] cancel() called.');
    final last = await _latestDoc();
    if (last == null) {
      AppLogger.log(
          '[SessionService_LOG] cancel() aborted: No latest document found.');
      return;
    }
    await NotificationService.instance.cancelAll();
    try {
      await last.reference.delete();
      AppLogger.log('[SessionService_LOG] Session deleted from Firestore.');
    } catch (e, s) {
      AppLogger.log(
          '[SessionService_LOG] ERROR deleting session from Firestore: $e');
      AppLogger.log(
          '[SessionService_LOG] Stack trace for Firestore delete error: $s');
    }
    AppLogger.log('[SessionService_LOG] cancel() finished.');
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _latestDoc() async {
    final c = _col;
    if (c == null) return null;
    try {
      final q = await c.orderBy('startAt', descending: true).limit(1).get();
      if (q.docs.isEmpty) {
        return null;
      }
      return q.docs.first;
    } catch (e, s) {
      AppLogger.log('[SessionService_LOG] ERROR fetching latest document: $e');
      AppLogger.log(
          '[SessionService_LOG] Stack trace for _latestDoc error: $s');
      return null;
    }
  }
}
