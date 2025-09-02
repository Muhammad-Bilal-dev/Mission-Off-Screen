// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<bool> _getPaywallEnabledSafe() async {
    try {
      final doc = await _db.collection('App_Config').doc('global').get();
      final data = doc.data() ?? {};
      return data['paywallEnabled'] == true;
    } catch (_) {
      // If we can't read (shouldn't happen after auth), assume OFF to avoid blocking signups.
      return false;
    }
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedPassword = password.trim();
    final trimmedDisplayName = displayName.trim();

    if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-argument',
        message: 'Email and password cannot be empty.',
      );
    }
    if (trimmedPassword.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Password should be at least 6 characters.',
      );
    }

    // 1) Create the auth user first (this authenticates subsequent Firestore reads/writes)
    final cred = await _auth.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: trimmedPassword,
    );
    final user = cred.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User creation failed unexpectedly.',
      );
    }

    if (trimmedDisplayName.isNotEmpty) {
      await user.updateDisplayName(trimmedDisplayName);
    }

    // 2) Now we are authenticated → safe to read config
    final paywallOn = await _getPaywallEnabledSafe();

    // 3) Write user profile according to paywall state
    final userDoc = {
      'uid': user.uid,
      'email': trimmedEmail,
      'name': trimmedDisplayName.isEmpty ? 'User' : trimmedDisplayName,
      'role': 'parent',
      // If paywall was OFF at signup time → early adopter
      'earlyAdopter': !paywallOn,
      // Support both shapes:
      'isSubscriber': false,
      'subscriptionStatus': 'none',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('users').doc(user.uid).set(userDoc, SetOptions(merge: true));
    return cred;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password.trim(),
    );
  }

  Future<void> signOut() => _auth.signOut();
}
