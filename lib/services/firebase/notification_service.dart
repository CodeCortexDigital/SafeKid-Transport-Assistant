import 'dart:async';
import '../../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final StreamController<NotificationModel> _controller = StreamController<NotificationModel>.broadcast();

  /// Broadcast stream exposing incoming notifications
  Stream<NotificationModel> get notificationsStream => _controller.stream;

  /// Programmatically triggers a new notification event (works in both Demo and Production modes)
  void triggerNotification({
    required String title,
    required String body,
    required String studentId,
  }) {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      studentId: studentId,
    );
    _controller.add(notification);
  }

  void dispose() {
    // Avoid closing broadcast controller if it is shared globally
  }
}
