import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static const String projectId = 'maya-rummy-vk';
  static const String targetDomain = 'https://mayarummy.cwards.com';
  static const String storageBucket = 'maya-rummy-vk.firebasestorage.app';

  /// Firebase Web Options for mayarummy.cwards.com
  static const FirebaseOptions webOptions = FirebaseOptions(
    apiKey: 'AIzaSyCZPnOUntPGcJPQ2tOrAs_p6NZtSnIWTNo',
    appId: '1:1017354829104:web:60e7b7d88caac5a0479cf5',
    messagingSenderId: '1017354829104',
    projectId: projectId,
    authDomain: 'maya-rummy-vk.firebaseapp.com',
    storageBucket: storageBucket,
    measurementId: 'G-NNLXFG6CL0',
  );

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Safe initialization: Catches initialization errors so the app never crashes
  /// if offline or if running with custom local configurations.
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      if (kIsWeb) {
        await Firebase.initializeApp(options: webOptions);
      } else {
        await Firebase.initializeApp();
      }
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('[FirebaseConfig] Firebase initialization notice: $e');
      _isInitialized = false;
      return false;
    }
  }
}
