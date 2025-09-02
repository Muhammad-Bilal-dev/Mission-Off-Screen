// lib/services/notifications.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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

  int _nonce = 0;

  Future<void> init({required GlobalKey<NavigatorState> navigatorKey}) async {
    print('[NotificationService_LOG] init() called. _inited: $_inited');
    if (_inited) {
      print('[NotificationService_LOG] Already initialized, returning.');
      return;
    }

    tzdata.initializeTimeZones();
    print('[NotificationService_LOG] Timezones initialized.');

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher'); // Ensure this icon exists in android/app/src/main/res/mipmap
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    print('[NotificationService_LOG] Initializing plugin...');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        print('[NotificationService_LOG] onDidReceiveNotificationResponse: Payload: ${resp.payload}');
        final payloadString = resp.payload;
        if (payloadString != null && payloadString.isNotEmpty) {
          try {
            final Map<String, dynamic> payloadData = jsonDecode(payloadString);
            final String? routeName = payloadData['route'] as String?;
            if (routeName != null) {
              print('[NotificationService_LOG] Navigating to route from JSON: $routeName');
              navigatorKey.currentState?.pushNamed(routeName, arguments: payloadData);
            } else if (!payloadData.containsKey("route") && payloadString.startsWith('/')) {
              print('[NotificationService_LOG] Navigating to route from string (fallback): $payloadString');
              navigatorKey.currentState?.pushNamed(payloadString);
            }
          } catch (e) {
            print('[NotificationService_LOG] Notification payload JSON parsing failed: $e. Payload: $payloadString');
            if (payloadString.startsWith('/')) {
              print('[NotificationService_LOG] Navigating to route from string (catch block): $payloadString');
              navigatorKey.currentState?.pushNamed(payloadString);
            }
          }
        }
      },
      // onDidReceiveBackgroundNotificationResponse: notificationTapBackground, // Optional for background
    );
    print('[NotificationService_LOG] Plugin initialized.');

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      print('[NotificationService_LOG] Creating notification channel $_channelId...');
      try {
        await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max, // Set importance here
          // priority: Priority.high, // <<< THIS LINE WAS REMOVED
        ));
        print('[NotificationService_LOG] Notification channel created successfully.');
      } catch (e) {
        print('[NotificationService_LOG] ERROR creating notification channel: $e');
      }

      print('[NotificationService_LOG] Requesting Android notifications permission (POST_NOTIFICATIONS) via plugin...');
      final bool? permissionGrantedByPlugin = await androidImplementation.requestNotificationsPermission();
      print('[NotificationService_LOG] Android POST_NOTIFICATIONS permission granted status from plugin: $permissionGrantedByPlugin');

      var statusPost = await Permission.notification.status;
      print('[NotificationService_LOG] Android POST_NOTIFICATIONS permission status from permission_handler (before explicit request): $statusPost');
      if (!statusPost.isGranted) {
        print('[NotificationService_LOG] POST_NOTIFICATIONS not granted, requesting via permission_handler...');
        statusPost = await Permission.notification.request();
        print('[NotificationService_LOG] POST_NOTIFICATIONS status after permission_handler request: $statusPost');
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      print('[NotificationService_LOG] Requesting iOS permissions...');
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      print('[NotificationService_LOG] iOS permissions requested.');
    }

    _inited = true;
    print('[NotificationService_LOG] init() finished successfully.');
  }

  Future<void> showNow({
    required String title,
    required String body,
    String payloadRoute = '/missionFlow',
  }) async {
    print('[NotificationService_LOG] showNow() called. Title: $title, _inited: $_inited');
    if (kIsWeb || !_inited) {
      print('[NotificationService_LOG] showNow() aborted (web or not inited).');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max, // Importance from channel will be used, but priority gives hint
      priority: Priority.high,   // Priority for this specific notification
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final id = Random().nextInt(0x7fffffff);
    print('[NotificationService_LOG] showNow() - Showing notification ID: $id');
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: payloadRoute,
      );
      print('[NotificationService_LOG] showNow() - _plugin.show() called successfully.');
    } catch (e,s) {
      print('[NotificationService_LOG] showNow() - ERROR calling _plugin.show(): $e');
      print('[NotificationService_LOG] showNow() - StackTrace: $s');
    }
  }

  Future<void> scheduleIn({
    required Duration delay,
    String title = "Time's up!",
    String body = "Tap to start your mission",
    String payloadRoute = '/missionFlow',
  }) async {
    print('[NotificationService_LOG] scheduleIn() called. Delay: $delay, Title: $title, _inited: $_inited');
    if (kIsWeb || !_inited) {
      print('[NotificationService_LOG] scheduleIn() aborted (web or not inited).');
      return;
    }

    final safeDelay = delay < const Duration(seconds: 2) ? const Duration(seconds: 2) : delay;
    print('[NotificationService_LOG] Using safeDelay: $safeDelay');

    _nonce++;
    final myNonce = _nonce;
    print('[NotificationService_LOG] Current nonce: $myNonce');

    final tz.TZDateTime when = tz.TZDateTime.now(tz.local).add(safeDelay);
    print('[NotificationService_LOG] Scheduling notification for (local time): $when');
    print('[NotificationService_LOG] Scheduling notification for (UTC time): ${when.toUtc()}');

    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    print('[NotificationService_LOG] Default AndroidScheduleMode: $scheduleMode');

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      print('[NotificationService_LOG] Checking SCHEDULE_EXACT_ALARM permission using permission_handler...');
      var statusExact = await Permission.scheduleExactAlarm.status;
      print('[NotificationService_LOG] SCHEDULE_EXACT_ALARM status from permission_handler: $statusExact');

      if (!statusExact.isGranted) {
        print('[NotificationService_LOG] SCHEDULE_EXACT_ALARM permission not granted. Requesting it...');
        statusExact = await Permission.scheduleExactAlarm.request();
        print('[NotificationService_LOG] SCHEDULE_EXACT_ALARM status after request: $statusExact');
        if (!statusExact.isGranted) {
          print('[NotificationService_LOG] SCHEDULE_EXACT_ALARM still not granted. Falling back to inexactAllowWhileIdle.');
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        } else {
          print('[NotificationService_LOG] SCHEDULE_EXACT_ALARM granted after request!');
        }
      } else {
        print('[NotificationService_LOG] SCHEDULE_EXACT_ALARM permission was already granted.');
      }
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max, // Importance from channel will be used
      priority: Priority.high,   // Priority for this specific scheduled notification
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final id = Random().nextInt(0x7fffffff);
    print('[NotificationService_LOG] Scheduling with _plugin.zonedSchedule. ID: $id, Mode: $scheduleMode, Time: $when');
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: scheduleMode,
        // uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime, // Keep commented for now unless specifically needed for iOS and confirmed API
        payload: payloadRoute,
      );
      print('[NotificationService_LOG] _plugin.zonedSchedule() CALLED SUCCESSFULLY for ID: $id.');
    } catch (e, s) {
      print('[NotificationService_LOG] ERROR calling _plugin.zonedSchedule() for ID: $id: $e');
      print('[NotificationService_LOG] Stack trace for zonedSchedule error: $s');
    }

    if (_devForegroundFallback) { // This block will not run if _devForegroundFallback is false
      print('[NotificationService_LOG] DEV FALLBACK: (Currently effectively disabled) Will attempt showNow after delay.');
      Future.delayed(safeDelay).then((_) async {
        print('[NotificationService_LOG] DEV FALLBACK: (Currently effectively disabled) Timer fired. myNonce: $myNonce, _nonce: $_nonce');
        if (myNonce == _nonce) {
          print('[NotificationService_LOG] DEV FALLBACK: (Currently effectively disabled) Nonce matches, calling showNow.');
          await showNow(title: title, body: body, payloadRoute: payloadRoute);
        } else {
          print('[NotificationService_LOG] DEV FALLBACK: (Currently effectively disabled) Nonce mismatch, showNow cancelled.');
        }
      });
    }
  }

  Future<void> cancelAll() async {
    print('[NotificationService_LOG] cancelAll() called. _inited: $_inited');
    if (kIsWeb || !_inited) {
      print('[NotificationService_LOG] cancelAll() aborted (web or not inited).');
      return;
    }
    _nonce++;
    print('[NotificationService_LOG] _nonce incremented to: $_nonce for cancelAll.');
    try {
      await _plugin.cancelAll();
      print('[NotificationService_LOG] _plugin.cancelAll() called successfully.');
    } catch (e, s) {
      print('[NotificationService_LOG] ERROR calling _plugin.cancelAll(): $e');
      print('[NotificationService_LOG] Stack trace for cancelAll error: $s');
    }
  }
}
