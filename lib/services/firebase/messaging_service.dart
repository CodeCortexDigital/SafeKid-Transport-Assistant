import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

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
        
        final title = message.notification?.title ?? message.data['title'] ?? 'SafeKid Transit Alert';
        final body = message.notification?.body ?? message.data['body'] ?? 'Transit updates are available.';
        final studentId = message.data['studentId'] ?? '';

        NotificationService().triggerNotification(
          title: title,
          body: body,
          studentId: studentId,
        );
      });

      // Handle notification clicks while app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Notification opened app: ${message.data}');
        }
        
        final title = message.notification?.title ?? message.data['title'] ?? 'SafeKid Background Event';
        final body = message.notification?.body ?? message.data['body'] ?? 'Transit updates are available.';
        final studentId = message.data['studentId'] ?? '';

        NotificationService().triggerNotification(
          title: title,
          body: body,
          studentId: studentId,
        );
      });

      // Handle terminated app launch from notification click
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          print('App launched from terminated state via notification: ${initialMessage.data}');
        }
        
        final title = initialMessage.notification?.title ?? initialMessage.data['title'] ?? 'SafeKid App Launch';
        final body = initialMessage.notification?.body ?? initialMessage.data['body'] ?? 'Transit updates are available.';
        final studentId = initialMessage.data['studentId'] ?? '';

        // Dispatch notification after a short delay for routes to load
        Future.delayed(const Duration(milliseconds: 1000), () {
          NotificationService().triggerNotification(
            title: title,
            body: body,
            studentId: studentId,
          );
        });
      }

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
