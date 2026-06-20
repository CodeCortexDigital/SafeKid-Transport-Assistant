import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

abstract class MessagingService {
  Future<void> initialize();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
}

class FirebaseMessagingService implements MessagingService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final StreamController<String> _tokenRefreshController = StreamController<String>.broadcast();

  @override
  Future<void> initialize() async {
    try {
      // Request permission for iOS/macOS/Web
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        print('User notification permission status: ${settings.authorizationStatus}');
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Received foreground notification: ${message.notification?.title}');
        }
      });

      // Handle notification clicks while app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Notification opened app: ${message.data}');
        }
      });

      _fcm.onTokenRefresh.listen((token) {
        _tokenRefreshController.add(token);
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Firebase Messaging: $e');
      }
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;
}

class MockMessagingService implements MessagingService {
  final StreamController<String> _tokenRefreshController = StreamController<String>.broadcast();

  @override
  Future<void> initialize() async {
    if (kDebugMode) {
      print('Mock Messaging Service initialized.');
    }
  }

  @override
  Future<String?> getToken() async {
    return 'mock-fcm-token-123-456-789';
  }

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;
}
