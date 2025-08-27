import 'package:cloud_firestore/cloud_firestore.dart';

class ChildrenService {
  static CollectionReference<Map<String, dynamic>> childrenCol(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('children');

  static DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamChildren(String uid) {
    return childrenCol(uid)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs);
  }

  static Future<String> addChild({
    required String uid,
    required String name,
    required int age,
    String? avatar,
    bool setActive = true,
  }) async {
    final ref = await childrenCol(uid).add({
      'name': name,
      'age': age,
      'avatar': avatar,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (setActive) {
      await setActiveChild(uid: uid, childId: ref.id, childName: name);
    }
    return ref.id;
  }

  static Future<void> updateChild({
    required String uid,
    required String childId,
    required String name,
    required int age,
    String? avatar,
  }) async {
    await childrenCol(uid).doc(childId).update({
      'name': name,
      'age': age,
      'avatar': avatar,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteChild({
    required String uid,
    required String childId,
  }) async {
    // if deleting active one, we won’t unset here (keep last active in user doc until changed)
    await childrenCol(uid).doc(childId).delete();
  }

  static Future<void> setActiveChild({
    required String uid,
    required String childId,
    required String childName,
  }) async {
    await userDoc(uid).set({
      'activeChildId': childId,
      'activeChildName': childName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
