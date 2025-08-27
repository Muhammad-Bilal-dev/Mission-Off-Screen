// lib/services/notifications.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  // Visible fallback only in debug so you can see something during testing
  static const bool _devForegroundFallback = kDebugMode;

  // Bump the channel ID if you change settings so Android recreates it
  static const String _channelId = 'mission_timer_v2';
  static const String _channelName = 'Mission Timer';
  static const String _channelDesc = 'Notifications for screentime missions';

  int _nonce = 0;

  Future<void> init({required GlobalKey<NavigatorState> navigatorKey}) async {
    if (_inited) return;

    // Needed for zonedSchedule()
    tzdata.initializeTimeZones();
    // We use UTC for delay-based scheduling (works across time zones reliably)
    tz.setLocalLocation(tz.getLocation('UTC'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        final route = resp.payload ?? '';
        if (route.isNotEmpty) {
          navigatorKey.currentState?.pushNamed(route);
        }
      },
    );

    // ANDROID: create channel + request runtime permission (13+)
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
      ));
      await android.requestNotificationsPermission();
    }

    // iOS: request permissions
    await _plugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _inited = true;
  }

  Future<void> showNow({
    required String title,
    required String body,
    String payloadRoute = '/missionFlow',
  }) async {
    if (kIsWeb || !_inited) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    final id = Random().nextInt(0x7fffffff);
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payloadRoute,
    );
  }

  Future<void> scheduleIn({
    required Duration delay,
    String title = "Time's up!",
    String body = "Tap to start your mission",
    String payloadRoute = '/missionFlow',
  }) async {
    if (kIsWeb || !_inited) return;

    final safeDelay =
    delay < const Duration(seconds: 2) ? const Duration(seconds: 2) : delay;

    _nonce++;
    final myNonce = _nonce;

    final id = Random().nextInt(0x7fffffff);
    final when = tz.TZDateTime.now(tz.local).add(safeDelay);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: payloadRoute,
    );

    // Debug-only fallback so you see something even if OEM kills alarms
    if (_devForegroundFallback) {
      Future.delayed(safeDelay).then((_) async {
        if (myNonce == _nonce) {
          await showNow(title: title, body: body, payloadRoute: payloadRoute);
        }
      });
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb || !_inited) return;
    _nonce++; // invalidate pending debug fallback
    await _plugin.cancelAll();
  }
}
