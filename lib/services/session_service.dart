import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notifications.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sessions');
  }

  Stream<Map<String, dynamic>?> watchRaw() {
    final c = _col;
    if (c == null) return const Stream.empty();
    return c.orderBy('startAt', descending: true).limit(1).snapshots().map(
          (snap) => snap.docs.isEmpty ? null : snap.docs.first.data(),
    );
  }

  Future<void> start({
    required String childId,
    required int minutes,
    bool scheduleNotification = true, // Dashboard passes false for exact 30s tests
  }) async {
    final c = _col;
    if (c == null) return;

    final now = DateTime.now().toUtc();
    final end = now.add(Duration(minutes: minutes));

    await c.add({
      'childId': childId,
      'minutes': minutes,
      'status': 'running',
      'startAt': Timestamp.fromDate(now),
      'endAt': Timestamp.fromDate(end),
      'pausedAt': null,
    });

    if (scheduleNotification) {
      await NotificationService.instance.scheduleIn(
        delay: Duration(minutes: minutes),
        payloadRoute: '/missionFlow',
      );
    }
  }

  Future<void> pause() async {
    final last = await _latestDoc();
    if (last == null) return;
    await NotificationService.instance.cancelAll();
    await last.reference.update({
      'status': 'paused',
      'pausedAt': Timestamp.fromDate(DateTime.now().toUtc()),
    });
  }

  Future<void> resume() async {
    final last = await _latestDoc();
    if (last == null) return;

    final data = last.data();
    final endAt = (data['endAt'] as Timestamp?)?.toDate().toUtc();
    if (endAt == null) return;

    final now = DateTime.now().toUtc();
    var remaining = endAt.difference(now);
    if (remaining.isNegative) remaining = Duration.zero;

    if (remaining > Duration.zero) {
      await NotificationService.instance.scheduleIn(
        delay: remaining,
        payloadRoute: '/missionFlow',
      );
    }

    await last.reference.update({
      'status': 'running',
      'pausedAt': null,
    });
  }

  Future<void> markEnded() async {
    final last = await _latestDoc();
    if (last == null) return;
    await last.reference.update({'status': 'ended'});
  }

  Future<void> complete() async {
    final last = await _latestDoc();
    if (last == null) return;
    await last.reference.update({'status': 'complete'});
  }

  Future<void> cancel() async {
    final last = await _latestDoc();
    if (last == null) return;
    await NotificationService.instance.cancelAll();
    await last.reference.delete();
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _latestDoc() async {
    final c = _col;
    if (c == null) return null;
    final q = await c.orderBy('startAt', descending: true).limit(1).get();
    if (q.docs.isEmpty) return null;
    return q.docs.first;
  }
}
