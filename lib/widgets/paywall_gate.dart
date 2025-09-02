// lib/widgets/paywall_gate.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/paywall_screen.dart';

/// Wrap any screen you want to gate:
///   PaywallGate(child: ParentDashboard())
///
/// Final logic:
/// 1) If there is a global free window (App_Config/global.freeUntil in the future) → allow all.
/// 2) Else, allow only if user.earlyAdopter == true OR user.isSubscriber == true
///    OR user.subscriptionStatus == 'premium'.
/// 3) Otherwise show PaywallScreen.
///
/// NOTE:
/// - paywallEnabled is only used at signup time to set earlyAdopter.
/// - Toggling paywallEnabled does not unlock existing users; that's by design.
class PaywallGate extends StatelessWidget {
  const PaywallGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Not signed in — upstream AuthGate handles routing.
      return child;
    }

    final cfgRef = FirebaseFirestore.instance.collection('App_Config').doc('global');
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: cfgRef.snapshots(),
      builder: (context, cfgSnap) {
        if (!cfgSnap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final cfg = cfgSnap.data!.data() ?? {};

        // Optional promo window
        var globalFree = false;
        final ts = cfg['freeUntil'];
        if (ts is Timestamp) {
          globalFree = DateTime.now().isBefore(ts.toDate());
        }
        if (globalFree) return child;

        // Otherwise, per-user gate
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userRef.snapshots(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final u = userSnap.data!.data() ?? {};
            final earlyAdopter = (u['earlyAdopter'] as bool?) ?? false;

            // Support both shapes
            final isSubscriberBool = (u['isSubscriber'] as bool?) ?? false;
            final subscriptionStatus = (u['subscriptionStatus'] as String?) ?? 'none';
            final isSubscriber = isSubscriberBool || subscriptionStatus == 'premium';

            if (earlyAdopter || isSubscriber) {
              return child;
            }
            return const PaywallScreen();
          },
        );
      },
    );
  }
}
