import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../core/theme/app_theme.dart';
import 'glass_card.dart';

class InAppNotificationToast extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onDismiss;

  const InAppNotificationToast({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<InAppNotificationToast> createState() => _InAppNotificationToastState();

  /// Static helper to trigger and display the toast notification in the application Overlay
  static void show(BuildContext context, NotificationModel notification) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
            child: Material(
              color: Colors.transparent,
              child: InAppNotificationToast(
                notification: notification,
                onDismiss: () {
                  overlayEntry.remove();
                },
              ),
            ),
          ),
        ),
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

class _InAppNotificationToastState extends State<InAppNotificationToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    // Automatically slide back up and dismiss after 4.5 seconds
    _dismissTimer = Timer(const Duration(milliseconds: 4500), () {
      _dismiss();
    });
  }

  void _dismiss() async {
    if (mounted) {
      await _controller.reverse();
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Resolve notification status icon
    IconData iconData = Icons.notifications_rounded;
    Color iconColor = AppTheme.primaryLight;
    
    final title = widget.notification.title.toLowerCase();
    if (title.contains('picked up')) {
      iconData = Icons.directions_bus_rounded;
      iconColor = AppTheme.warning;
    } else if (title.contains('school')) {
      iconData = Icons.school_rounded;
      iconColor = AppTheme.primaryLight;
    } else if (title.contains('home')) {
      iconData = Icons.home_rounded;
      iconColor = AppTheme.success;
    } else if (title.contains('return')) {
      iconData = Icons.swap_calls_rounded;
      iconColor = AppTheme.accentLight;
    }

    return SlideTransition(
      position: _offsetAnimation,
      child: Dismissible(
        key: Key(widget.notification.id),
        direction: DismissDirection.up,
        onDismissed: (_) => widget.onDismiss(),
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 480),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconData,
                      color: iconColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.notification.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.notification.body,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.drag_handle_rounded,
                    color: Colors.white24,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
