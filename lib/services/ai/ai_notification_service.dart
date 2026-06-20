enum NotificationTemplateType {
  vanDelay,
  feeReminder,
  holidayNotice,
  studentAbsent,
  emergencyAlert,
}

class NotificationDraft {
  final String title;
  final String body;

  NotificationDraft({required this.title, required this.body});
}

class AiNotificationService {
  static final AiNotificationService _instance = AiNotificationService._internal();
  factory AiNotificationService() => _instance;
  AiNotificationService._internal();

  /// Generates a professional notification message based on template parameters and desired tone.
  NotificationDraft generate({
    required NotificationTemplateType type,
    required Map<String, String> parameters,
    String tone = 'Professional',
  }) {
    final cleanTone = tone.toLowerCase();
    String title = '';
    String body = '';

    switch (type) {
      case NotificationTemplateType.vanDelay:
        final route = parameters['route'] ?? 'School Route';
        final delay = parameters['delay'] ?? '10';
        final reason = parameters['reason'] ?? 'heavy traffic';

        if (cleanTone == 'friendly') {
          title = 'Bus Update: Running late 🚌';
          body = 'Hey parents! Just a quick heads up. The Greenwood van on route "$route" is running about $delay minutes behind schedule today because of $reason. We apologize for the wait and appreciate your understanding!';
        } else if (cleanTone == 'urgent') {
          title = '⚠️ ALERT: Van Delay on Route $route';
          body = 'Urgent Notice: The transport van for Route "$route" is delayed by $delay minutes due to $reason. Please stay updated by tracking the vehicle location live on your SafeKid home screen.';
        } else {
          // Professional default
          title = 'Transport Schedule Adjustment: Delayed';
          body = 'Dear parents, please be informed that the transport van on Route "$route" is currently experiencing a delay of approximately $delay minutes due to $reason. We appreciate your patience as we transport your children safely.';
        }
        break;

      case NotificationTemplateType.feeReminder:
        final parentName = parameters['parentName'] ?? 'Parent';
        final amount = parameters['amount'] ?? '150.00';
        final dueDate = parameters['dueDate'] ?? 'the 15th';

        if (cleanTone == 'friendly') {
          title = 'Monthly fees reminder 💳';
          body = 'Hi $parentName! Hope you are having a great week. Just a quick reminder that the monthly transport fee of \$$amount is due by $dueDate. Let us know if you have any questions. Thanks!';
        } else if (cleanTone == 'urgent') {
          title = '🚨 URGENT: Outstanding Fees Notification';
          body = 'Important: The transport invoice of \$$amount due on $dueDate remains unpaid. Please settle the balance via your Billing dashboard today to avoid temporary suspension of transport services.';
        } else {
          // Professional default
          title = 'Notice of Upcoming Invoice Due Date';
          body = 'Dear $parentName, this is a friendly reminder that the monthly school transport fee of \$$amount is due on $dueDate. Please review the invoice and complete your payment on the SafeKid portal. Thank you.';
        }
        break;

      case NotificationTemplateType.holidayNotice:
        final occasion = parameters['occasion'] ?? 'Public Holiday';
        final date = parameters['date'] ?? 'tomorrow';
        final duration = parameters['duration'] ?? 'one day';

        if (cleanTone == 'friendly') {
          title = 'Holiday coming up! 🎉';
          body = 'Hi everyone! Friendly heads up that school and van transport will be closed for $occasion on $date ($duration). Have a wonderful, relaxing holiday break!';
        } else if (cleanTone == 'urgent') {
          title = '⚠️ SCHEDULE ALERT: Holiday Route Closure';
          body = 'Please Note: Transport services will be completely suspended on $date for $occasion ($duration). Regular route operations will resume the following working day. Please plan accordingly.';
        } else {
          // Professional default
          title = 'Notice of Temporary Route Suspension';
          body = 'Dear parents, please note that school and transport services will remain closed on $date in observance of $occasion ($duration). Standard pickup and drop services will resume on the next working day.';
        }
        break;

      case NotificationTemplateType.studentAbsent:
        final studentName = parameters['studentName'] ?? 'Student';
        final date = parameters['date'] ?? 'today';

        if (cleanTone == 'friendly') {
          title = 'Absence check-in 📝';
          body = 'Hi! We noticed that $studentName was not at the pickup stop for the ride on $date, and has been marked absent. Hope they are doing well! Let us know if they will return tomorrow.';
        } else if (cleanTone == 'urgent') {
          title = '⚠️ Attendance Alert: Absent today';
          body = 'Urgent Status Alert: $studentName was not boarded on the route today, $date, and is marked absent. Please verify their safety status with the coordinator immediately if this is unexpected.';
        } else {
          // Professional default
          title = 'Transport Attendance Record';
          body = 'Dear parents, this message is to confirm that $studentName has been marked as absent from the school transport route today, $date. If this record is in error, please contact support.';
        }
        break;

      case NotificationTemplateType.emergencyAlert:
        final event = parameters['event'] ?? 'Severe Weather';
        final instructions = parameters['instructions'] ?? 'Stay indoors';

        if (cleanTone == 'friendly') {
          title = 'Safety alert: Quick update';
          body = 'Hi parents, we have a safety announcement regarding: $event. Please follow these tips: $instructions. Your child\'s safety is our top goal, so please reach out if you need assistance.';
        } else if (cleanTone == 'urgent') {
          title = '🚨 EMERGENCY NOTIFICATION: $event';
          body = 'CRITICAL ALERT: Please be advised of an immediate emergency regarding $event. Required Action: $instructions. All van locations are being tracked, and support lines are open.';
        } else {
          // Professional default
          title = 'Official Safety Notice: Emergency Update';
          body = 'Dear parents, this is an official safety update regarding $event. We ask that you adhere to the following guidelines: $instructions. SafeKid transport is actively coordinating with staff to ensure all children are secure.';
        }
        break;
    }

    return NotificationDraft(title: title, body: body);
  }
}
