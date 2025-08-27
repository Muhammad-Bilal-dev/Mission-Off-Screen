import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  UserService._();
  static final instance = UserService._();

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  /// Real-time stream of the parent doc
  Stream<Map<String, dynamic>?> watchUser() {
    final d = _doc;
    if (d == null) return const Stream.empty();
    return d.snapshots().map((s) => s.data());
  }

  Future<void> setActiveChild({required String id, required String name}) async {
    final d = _doc;
    if (d == null) return;
    await d.update({'activeChildId': id, 'activeChildName': name});
  }

  Future<String?> getPin() async {
    final d = _doc;
    if (d == null) return null;
    final snap = await d.get();
    return snap.data()?['parentPin']?.toString();
  }

  Future<void> ensureEarlyAdopter() async {
    final d = _doc;
    if (d == null) return;
    await d.set({
      'earlyAdopter': true,
      'subscriptionStatus': 'free',
      'createdAt': FieldValue.serverTimestamp(),
      'role': 'parent',
    }, SetOptions(merge: true));
  }
}
