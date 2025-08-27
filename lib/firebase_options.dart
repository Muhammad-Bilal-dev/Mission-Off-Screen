import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return web; // fallback
    }
  }

  // WEB (your exact config)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyCK4pgjGHEVwy_Iaju5oCs2xVzIffCmqKY",
    authDomain: "screentime-buddy123.firebaseapp.com",
    projectId: "screentime-buddy123",
    storageBucket: "screentime-buddy123.firebasestorage.app",
    messagingSenderId: "667202481904",
    appId: "1:667202481904:web:b8d350816bc002e4aa1c35",
  );

  // Android – okay to reuse essentials; google-services.json will also be used.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyCK4pgjGHEVwy_Iaju5oCs2xVzIffCmqKY",
    projectId: "screentime-buddy123",
    storageBucket: "screentime-buddy123.firebasestorage.app",
    messagingSenderId: "667202481904",
    appId: "1:667202481904:web:b8d350816bc002e4aa1c35",
  );

  // iOS/macos placeholders (ignored unless you build iOS/macos later).
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyCK4pgjGHEVwy_Iaju5oCs2xVzIffCmqKY",
    appId: "1:667202481904:web:b8d350816bc002e4aa1c35",
    messagingSenderId: "667202481904",
    projectId: "screentime-buddy123",
    storageBucket: "screentime-buddy123.firebasestorage.app",
    iosBundleId: "com.example.screentimeBuddy",
  );

  static const FirebaseOptions macos = ios;
}
