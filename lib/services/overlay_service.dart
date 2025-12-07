import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../screens/overlay_mission_screen.dart';

class OverlayService {
  OverlayService._();
  static final OverlayService instance = OverlayService._();

  Future<void> requestPermission() async {
    final bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      await FlutterOverlayWindow.requestPermission();
    }
  }

  Future<bool> checkPermission() async {
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  /// Show the overlay.
  Future<void> showOverlay({String? title, String? missionId}) async {
    if (await checkPermission()) {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        alignment: OverlayAlignment.center,
        visibility: NotificationVisibility.visibilityPublic,
        flag: OverlayFlag.defaultFlag,
        overlayTitle: title ?? "Time's up! Mission Time!",
        overlayContent: missionId ?? 'random',
        height: WindowSize.fullCover,
        width: WindowSize.fullCover,
      );
    } else {
      debugPrint("Overlay permission not granted.");
    }
  }

  Future<void> closeOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }
}

// Global entry point for the overlay
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayMissionScreen(),
    ),
  );
}

// Background callback for AndroidAlarmManager
@pragma('vm:entry-point')
void overlayAlarmCallback() {
  debugPrint("[OverlayService] Alarm fired! Attempting to show overlay...");
  OverlayService.instance.showOverlay();
}
