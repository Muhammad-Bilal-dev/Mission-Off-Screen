import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/paywall_screen.dart';

/// Wrap any screen you want to gate:
///   PaywallGate(child: ParentDashboard())
///
/// Final logic:
/// 1) If there is a global free window (App_Config/global.freeUntil in the future) → allow all.
/// 2) Else, allow only if user.earlyAdopter == true OR user.subscriptionStatus == 'premium'.
/// 3) Otherwise show PaywallScreen.
///
/// NOTE:
/// - We intentionally do NOT use paywallEnabled at runtime to bypass,
///   so toggling paywallEnabled will NOT unlock the app for everyone.
/// - SignupScreen should still use paywallEnabled to set earlyAdopter for new accounts.
class PaywallGate extends StatelessWidget {
  const PaywallGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Not signed in — upstream AuthGate should handle routing.
      // We just show the child to avoid loops.
      return child;
    }

    final cfgRef = FirebaseFirestore.instance.collection('App_Config').doc('global');
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: cfgRef.snapshots(),
      builder: (context, cfgSnap) {
        if (!cfgSnap.hasData) {
          // Light skeleton while config loads
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final cfg = cfgSnap.data!.data() ?? {};

        // Optional: global free window for promos
        bool globalFree = false;
        final ts = cfg['freeUntil'];
        if (ts is Timestamp) {
          globalFree = DateTime.now().isBefore(ts.toDate());
        }

        if (globalFree) {
          // During a promo window, everyone can access.
          return child;
        }

        // Otherwise, gate per user
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userRef.snapshots(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final u = userSnap.data!.data() ?? {};
            final earlyAdopter = (u['earlyAdopter'] as bool?) ?? false;
            final subscriptionStatus = (u['subscriptionStatus'] as String?) ?? 'none';
            final isPremium = subscriptionStatus == 'premium';

            if (earlyAdopter || isPremium) {
              return child;
            }

            // Not early & not premium → paywall
            return const PaywallScreen();
          },
        );
      },
    );
  }
}
