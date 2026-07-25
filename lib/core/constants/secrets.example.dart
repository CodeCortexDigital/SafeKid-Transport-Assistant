import 'package:firebase_core/firebase_core.dart';

class Secrets {
  Secrets._();

  static const FirebaseOptions firebaseOptions = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
    measurementId: 'YOUR_MEASUREMENT_ID',
  );

  static const String googleMapsAndroidApiKey = 'YOUR_ANDROID_MAPS_KEY';
  static const String googleMapsWebApiKey = 'YOUR_WEB_MAPS_KEY';
}
