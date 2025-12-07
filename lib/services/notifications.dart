// lib/services/notifications.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'overlay_service.dart';
import '../utils/app_logger.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  // CRITICAL FOR TESTING RELEASE: Ensure this is false to test actual scheduling
  static const bool _devForegroundFallback = false;

  static const String _channelId = 'mission_timer_v2';
  static const String _channelName = 'Mission Timer';
  static const String _channelDesc = 'Notifications for screentime missions';

  static const int _alarmId = 999; // Constant ID for the mission timer alarm

  int _nonce = 0;

  Future<void> init({required GlobalKey<NavigatorState> navigatorKey}) async {
    AppLogger.log('[NotificationService_LOG] init() called. _inited: $_inited');
    if (_inited) {
      AppLogger.log(
          '[NotificationService_LOG] Already initialized, returning.');
      return;
    }

    tzdata.initializeTimeZones();
    AppLogger.log('[NotificationService_LOG] Timezones initialized.');

    const androidInit = AndroidInitializationSettings(
        '@mipmap/ic_launcher'); // Ensure this icon exists in android/app/src/main/res/mipmap
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    AppLogger.log('[NotificationService_LOG] Initializing plugin...');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        AppLogger.log(
            '[NotificationService_LOG] onDidReceiveNotificationResponse: Payload: ${resp.payload}');
        final payloadString = resp.payload;
        if (payloadString != null && payloadString.isNotEmpty) {
          try {
            final Map<String, dynamic> payloadData = jsonDecode(payloadString);
            final String? routeName = payloadData['route'] as String?;
            if (routeName != null) {
              AppLogger.log(
                  '[NotificationService_LOG] Navigating to route from JSON: $routeName');
              navigatorKey.currentState
                  ?.pushNamed(routeName, arguments: payloadData);
            } else if (!payloadData.containsKey("route") &&
                payloadString.startsWith('/')) {
              AppLogger.log(
                  '[NotificationService_LOG] Navigating to route from string (fallback): $payloadString');
              navigatorKey.currentState?.pushNamed(payloadString);
            }
          } catch (e) {
            AppLogger.log(
                '[NotificationService_LOG] Notification payload JSON parsing failed: $e. Payload: $payloadString');
            if (payloadString.startsWith('/')) {
              AppLogger.log(
                  '[NotificationService_LOG] Navigating to route from string (catch block): $payloadString');
              navigatorKey.currentState?.pushNamed(payloadString);
            }
          }
        }
      },
    );

    // FORCE CLEANUP on Init to remove any "ghost" notifications from previous testing
    await _plugin.cancelAll();
    AppLogger.log(
        '[NotificationService_LOG] Plugin initialized. Forced cancelAll() to clear legacy notifications.');

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      AppLogger.log(
          '[NotificationService_LOG] Creating notification channel $_channelId...');
      try {
        await androidImplementation
            .createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max, // Set importance here
          // priority: Priority.high, // <<< THIS LINE WAS REMOVED
        ));
        AppLogger.log(
            '[NotificationService_LOG] Notification channel created successfully.');
      } catch (e) {
        AppLogger.log(
            '[NotificationService_LOG] ERROR creating notification channel: $e');
      }

      AppLogger.log(
          '[NotificationService_LOG] Requesting Android notifications permission (POST_NOTIFICATIONS) via plugin...');
      final bool? permissionGrantedByPlugin =
          await androidImplementation.requestNotificationsPermission();
      AppLogger.log(
          '[NotificationService_LOG] Android POST_NOTIFICATIONS permission granted status from plugin: $permissionGrantedByPlugin');

      var statusPost = await Permission.notification.status;
      AppLogger.log(
          '[NotificationService_LOG] Android POST_NOTIFICATIONS permission status from permission_handler (before explicit request): $statusPost');
      if (!statusPost.isGranted) {
        AppLogger.log(
            '[NotificationService_LOG] POST_NOTIFICATIONS not granted, requesting via permission_handler...');
        statusPost = await Permission.notification.request();
        AppLogger.log(
            '[NotificationService_LOG] POST_NOTIFICATIONS status after permission_handler request: $statusPost');
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      AppLogger.log('[NotificationService_LOG] Requesting iOS permissions...');
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      AppLogger.log('[NotificationService_LOG] iOS permissions requested.');
    }

    _inited = true;
    AppLogger.log('[NotificationService_LOG] init() finished successfully.');
  }

  Future<void> showNow({
    required String title,
    required String body,
    String payloadRoute = '/missionFlow',
  }) async {
    AppLogger.log(
        '[NotificationService_LOG] showNow() called. Title: $title, _inited: $_inited');
    if (kIsWeb || !_inited) {
      AppLogger.log(
          '[NotificationService_LOG] showNow() aborted (web or not inited).');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance
          .max, // Importance from channel will be used, but priority gives hint
      priority: Priority.high, // Priority for this specific notification
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final id = Random().nextInt(0x7fffffff);
    AppLogger.log(
        '[NotificationService_LOG] showNow() - Showing notification ID: $id');
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: payloadRoute,
      );
      AppLogger.log(
          '[NotificationService_LOG] showNow() - _plugin.show() called successfully.');
    } catch (e, s) {
      AppLogger.log(
          '[NotificationService_LOG] showNow() - ERROR calling _plugin.show(): $e');
      AppLogger.log('[NotificationService_LOG] showNow() - StackTrace: $s');
    }
  }

  Future<void> scheduleIn({
    required Duration delay,
    String title = "Time's up!",
    String body = "Tap to start your mission",
    String payloadRoute = '/missionFlow',
  }) async {
    AppLogger.log(
        '[NotificationService_LOG] scheduleIn() called. Delay: $delay, Title: $title, _inited: $_inited');
    AppLogger.log(
        '[NotificationService_LOG] Platform: $defaultTargetPlatform, kIsWeb: $kIsWeb');

    if (kIsWeb || !_inited) {
      AppLogger.log(
          '[NotificationService_LOG] scheduleIn() aborted (web or not inited).');
      return;
    }

    final safeDelay =
        delay < const Duration(seconds: 2) ? const Duration(seconds: 2) : delay;
    AppLogger.log('[NotificationService_LOG] Using safeDelay: $safeDelay');

    _nonce++;
    // final myNonce = _nonce; // Unused if we use static ID for alarm

    final tz.TZDateTime when = tz.TZDateTime.now(tz.local).add(safeDelay);
    AppLogger.log(
        '[NotificationService_LOG] Scheduling notification for (local time): $when');

    // On Android, use AlarmManager for Overlay
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      AppLogger.log(
          '[NotificationService_LOG] Android detected. Scheduling System Alert Window via AlarmManager (ID: $_alarmId).');

      try {
        final success = await AndroidAlarmManager.oneShot(
          safeDelay,
          _alarmId, // CONSTANT ID
          overlayAlarmCallback,
          exact: true,
          wakeup: true,
          alarmClock: true,
          allowWhileIdle: true,
        );
        AppLogger.log(
            '[NotificationService_LOG] AndroidAlarmManager.oneShot() scheduled? $success');
      } catch (e) {
        AppLogger.log(
            '[NotificationService_LOG] ERROR calling AndroidAlarmManager.oneShot: $e');
      }
      return;
    }

    // Standard Notification Logic (iOS / Web)
    // This code is now ONLY reachable for non-Android platforms.
    AppLogger.log(
        '[NotificationService_LOG] Scheduling standard notification for iOS/Web.');

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final id = Random().nextInt(0x7fffffff);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(iOS: iosDetails), // iOS only details
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle, // Required argument
        payload: payloadRoute,
      );
      AppLogger.log(
          '[NotificationService_LOG] _plugin.zonedSchedule() CALLED SUCCESSFULLY for ID: $id.');
    } catch (e, s) {
      AppLogger.log(
          '[NotificationService_LOG] ERROR calling _plugin.zonedSchedule() for ID: $id: $e');
      AppLogger.log(
          '[NotificationService_LOG] Stack trace for zonedSchedule error: $s');
    }

    if (_devForegroundFallback) {
      // ...
    }
  }

  Future<void> cancelAll() async {
    AppLogger.log(
        '[NotificationService_LOG] cancelAll() called. _inited: $_inited');
    if (kIsWeb || !_inited) {
      AppLogger.log(
          '[NotificationService_LOG] cancelAll() aborted (web or not inited).');
      return;
    }
    _nonce++;
    AppLogger.log(
        '[NotificationService_LOG] _nonce incremented to: $_nonce for cancelAll.');
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await AndroidAlarmManager.cancel(_alarmId);
        AppLogger.log(
            '[NotificationService_LOG] AndroidAlarmManager.cancel($_alarmId) called.');
      }
      await _plugin.cancelAll();
      AppLogger.log(
          '[NotificationService_LOG] _plugin.cancelAll() called successfully.');
    } catch (e, s) {
      AppLogger.log(
          '[NotificationService_LOG] ERROR calling _plugin.cancelAll(): $e');
      AppLogger.log(
          '[NotificationService_LOG] Stack trace for cancelAll error: $s');
    }
  }
}
