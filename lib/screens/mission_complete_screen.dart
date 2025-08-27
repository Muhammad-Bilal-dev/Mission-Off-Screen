import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class MissionCompleteScreen extends StatefulWidget {
  final String childName;
  const MissionCompleteScreen({super.key, required this.childName});

  @override
  State<MissionCompleteScreen> createState() => _MissionCompleteScreenState();
}

class _MissionCompleteScreenState extends State<MissionCompleteScreen> {
  @override
  void initState() {
    super.initState();
    // Brief celebration, then go to Locked screen automatically
    Future.delayed(const Duration(seconds: 7), () {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/locked', (r) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // background uses app theme's scaffoldBackgroundColor
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/celebrate.json',
              width: 220,
              height: 220,
              repeat: false,
            ),
            const SizedBox(height: 16),
            Text(
              "Amazing job, ${widget.childName}!",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "We'll go on another mission tomorrow.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
