import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../utils/app_logger.dart';

class OverlayMissionScreen extends StatefulWidget {
  const OverlayMissionScreen({super.key});

  @override
  State<OverlayMissionScreen> createState() => _OverlayMissionScreenState();
}

class _OverlayMissionScreenState extends State<OverlayMissionScreen> {
  @override
  void initState() {
    super.initState();
    AppLogger.log(
        "[OverlayMissionScreen] initState() called - View is being created");
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.log("[OverlayMissionScreen] build() called");
    return Scaffold(
      backgroundColor:
          const Color(0xFFD5CBBD), // Solid color to ensure visibility
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_off_outlined,
                  size: 80, color: Color(0xFF8C4D1E)),
              const SizedBox(height: 24),
              const Text(
                "Time's Up!",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8C4D1E),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Your screen time mission is waiting. Complete it to unlock your screen!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8C4D1E),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      // Attempt to open the main app
                      // This might fail if the app is killed, but we catch it
                      await FlutterOverlayWindow.shareData("open_app");
                    } catch (e) {
                      debugPrint("Error sharing data: $e");
                    } finally {
                      // ALWAYS close the overlay to unfreeze the user
                      await FlutterOverlayWindow.closeOverlay();
                    }
                  },
                  child: const Text("Go to Mission"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
