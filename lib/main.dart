import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'utils/app_logger.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/parent_dashboard.dart';
import 'screens/mission_flow.dart';
import 'screens/locked_screen.dart';
import 'screens/children_list_screen.dart';
import 'screens/mission_complete_screen.dart';
import 'services/notifications.dart';

// Paywall gate
import 'widgets/paywall_gate.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();

  // Initialize background alarm manager
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await AndroidAlarmManager.initialize();
  }

  if (!kIsWeb) {
    await NotificationService.instance.init(navigatorKey: navigatorKey);
  }

  runApp(const MyApp());
}

Future<void> _initFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      Firebase.app();
    }
  } catch (e) {
    AppLogger.log("Firebase init failed: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'ScreenTime Buddy',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF8C4D1E),
        scaffoldBackgroundColor: const Color(0xFFD5CBBD),
      ),
      home: const _AuthGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        // gate the dashboard whether navigated directly or via AuthGate
        '/dashboard': (_) => const PaywallGate(child: ParentDashboard()),
        '/missionFlow': (_) => const MissionFlow(),
        '/locked': (_) => const LockedScreen(),
        '/children': (_) => const ChildrenListScreen(),
        '/missionComplete': (ctx) {
          final args = (ModalRoute.of(ctx)?.settings.arguments
                  as Map<String, dynamic>?) ??
              {};
          final childName = (args['childName'] as String?) ?? 'buddy';
          return MissionCompleteScreen(childName: childName);
        },
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) return const LoginScreen();

        // First screen after auth is gated
        return const PaywallGate(child: ParentDashboard());
      },
    );
  }
}
