import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai/ai_notification_service.dart';
import '../../services/firebase/notification_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_button.dart';

class AiNotificationScreen extends StatefulWidget {
  const AiNotificationScreen({super.key});

  @override
  State<AiNotificationScreen> createState() => _AiNotificationScreenState();
}

class _AiNotificationScreenState extends State<AiNotificationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Template selection
  NotificationTemplateType _selectedType = NotificationTemplateType.vanDelay;
  String _selectedTone = 'Professional';
  String _selectedRecipient = 'all'; // 'all' or specific studentId

  // Parameters controllers
  // 1. Van Delay
  final _vanRouteController = TextEditingController(text: 'Greenwood Route 4B');
  final _vanDelayController = TextEditingController(text: '15');
  final _vanReasonController = TextEditingController(text: 'heavy morning traffic');

  // 2. Fee Reminder
  final _feeParentNameController = TextEditingController(text: 'John Doe');
  final _feeAmountController = TextEditingController(text: '150.00');
  final _feeDueDateController = TextEditingController(text: '25/06/2026');

  // 3. Holiday Notice
  final _holidayOccasionController = TextEditingController(text: 'Summer Break');
  final _holidayDateController = TextEditingController(text: '26/06/2026');
  final _holidayDurationController = TextEditingController(text: 'two days');

  // 4. Student Absent
  final _studentNameController = TextEditingController(text: 'Emma Doe');
  final _studentAbsentDateController = TextEditingController(text: 'today');

  // 5. Emergency Alert
  final _emergencyEventController = TextEditingController(text: 'Heavy Rainstorm & Waterlogging');
  final _emergencyInstructionsController = TextEditingController(text: 'Parents are requested to stand by at pickup points. Expect major delays but routes remain active.');

  // Generated draft controllers
  final _titleDraftController = TextEditingController();
  final _bodyDraftController = TextEditingController();

  bool _isGenerating = false;
  bool _hasDraft = false;

  @override
  void initState() {
    super.initState();
    // Load student records on load for drivers/staff
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        if (user.role == UserRole.parent) {
          Provider.of<AttendanceProvider>(context, listen: false).fetchMyStudents(user.id);
        } else {
          Provider.of<AttendanceProvider>(context, listen: false).fetchMyStudents('mock-parent-uid-123');
        }
      }
    });
  }

  @override
  void dispose() {
    _vanRouteController.dispose();
    _vanDelayController.dispose();
    _vanReasonController.dispose();
    _feeParentNameController.dispose();
    _feeAmountController.dispose();
    _feeDueDateController.dispose();
    _holidayOccasionController.dispose();
    _holidayDateController.dispose();
    _holidayDurationController.dispose();
    _studentNameController.dispose();
    _studentAbsentDateController.dispose();
    _emergencyEventController.dispose();
    _emergencyInstructionsController.dispose();
    _titleDraftController.dispose();
    _bodyDraftController.dispose();
    super.dispose();
  }

  void _generateDraft() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
    });

    // Simulate AI generation delay
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;

      final Map<String, String> params = {};
      switch (_selectedType) {
        case NotificationTemplateType.vanDelay:
          params['route'] = _vanRouteController.text.trim();
          params['delay'] = _vanDelayController.text.trim();
          params['reason'] = _vanReasonController.text.trim();
          break;
        case NotificationTemplateType.feeReminder:
          params['parentName'] = _feeParentNameController.text.trim();
          params['amount'] = _feeAmountController.text.trim();
          params['dueDate'] = _feeDueDateController.text.trim();
          break;
        case NotificationTemplateType.holidayNotice:
          params['occasion'] = _holidayOccasionController.text.trim();
          params['date'] = _holidayDateController.text.trim();
          params['duration'] = _holidayDurationController.text.trim();
          break;
        case NotificationTemplateType.studentAbsent:
          params['studentName'] = _studentNameController.text.trim();
          params['date'] = _studentAbsentDateController.text.trim();
          break;
        case NotificationTemplateType.emergencyAlert:
          params['event'] = _emergencyEventController.text.trim();
          params['instructions'] = _emergencyInstructionsController.text.trim();
          break;
      }

      final draft = AiNotificationService().generate(
        type: _selectedType,
        parameters: params,
        tone: _selectedTone,
      );

      setState(() {
        _titleDraftController.text = draft.title;
        _bodyDraftController.text = draft.body;
        _isGenerating = false;
        _hasDraft = true;
      });
    });
  }

  void _sendBroadcast(List<StudentModel> students) {
    final title = _titleDraftController.text.trim();
    final body = _bodyDraftController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please generate and verify the notification draft first.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final notifier = NotificationService();
    if (_selectedRecipient == 'all') {
      if (students.isEmpty) {
        // Fallback send
        notifier.triggerNotification(title: title, body: body, studentId: 'mock-student-1');
      } else {
        for (var s in students) {
          notifier.triggerNotification(title: title, body: body, studentId: s.id);
        }
      }
    } else {
      notifier.triggerNotification(title: title, body: body, studentId: _selectedRecipient);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI Announcement broadcasted successfully!'),
        backgroundColor: AppTheme.success,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final students = attendance.myStudents;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AI Alert Composer',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Template & Tone Selectors
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Alert Settings',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<NotificationTemplateType>(
                              value: _selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Template Type',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: NotificationTemplateType.vanDelay, child: Text('Van Delay')),
                                DropdownMenuItem(value: NotificationTemplateType.feeReminder, child: Text('Fee Reminder')),
                                DropdownMenuItem(value: NotificationTemplateType.holidayNotice, child: Text('Holiday Notice')),
                                DropdownMenuItem(value: NotificationTemplateType.studentAbsent, child: Text('Student Absent')),
                                DropdownMenuItem(value: NotificationTemplateType.emergencyAlert, child: Text('Emergency Alert')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedType = val;
                                    _hasDraft = false;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedTone,
                              decoration: const InputDecoration(
                                labelText: 'Alert Tone',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Professional', child: Text('Professional')),
                                DropdownMenuItem(value: 'Friendly', child: Text('Friendly')),
                                DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedTone = val;
                                    _hasDraft = false;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Dynamic Parameters Input
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Configure Parameters',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      _buildTemplateFormFields(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. AI Generate Button
                _isGenerating
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(color: AppTheme.primaryColor),
                        ),
                      )
                    : CustomButton(
                        text: _hasDraft ? 'Regenerate Draft' : 'AI Generate Alert Draft',
                        icon: Icons.auto_awesome,
                        onPressed: _generateDraft,
                      ),
                const SizedBox(height: 16),

                // 4. Draft Preview & Editor
                if (_hasDraft) ...[
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_note_rounded, color: AppTheme.accentLight, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Generated Draft (Edit if needed)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _titleDraftController,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            labelText: 'Notification Title',
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _bodyDraftController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Notification Body Message',
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Recipient Selector & Send Action
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Recipient Audience',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedRecipient,
                          decoration: const InputDecoration(
                            labelText: 'Audience Group',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(value: 'all', child: Text('All Route Parents (Broadcast)')),
                            ...students.map((s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text('Parent of ${s.name} (${s.className})'),
                                )),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedRecipient = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _sendBroadcast(students),
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('Send Alert Broadcast'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateFormFields() {
    switch (_selectedType) {
      case NotificationTemplateType.vanDelay:
        return Column(
          children: [
            TextFormField(
              controller: _vanRouteController,
              decoration: const InputDecoration(labelText: 'Route Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vanDelayController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Delay Duration (minutes)'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vanReasonController,
              decoration: const InputDecoration(labelText: 'Reason for Delay'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
          ],
        );

      case NotificationTemplateType.feeReminder:
        return Column(
          children: [
            TextFormField(
              controller: _feeParentNameController,
              decoration: const InputDecoration(labelText: 'Parent Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _feeAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Fee Amount (\$)'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _feeDueDateController,
              decoration: const InputDecoration(labelText: 'Due Date'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
          ],
        );

      case NotificationTemplateType.holidayNotice:
        return Column(
          children: [
            TextFormField(
              controller: _holidayOccasionController,
              decoration: const InputDecoration(labelText: 'Holiday/Occasion Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _holidayDateController,
              decoration: const InputDecoration(labelText: 'Holiday Date'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _holidayDurationController,
              decoration: const InputDecoration(labelText: 'Closure Duration'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
          ],
        );

      case NotificationTemplateType.studentAbsent:
        return Column(
          children: [
            TextFormField(
              controller: _studentNameController,
              decoration: const InputDecoration(labelText: 'Student Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _studentAbsentDateController,
              decoration: const InputDecoration(labelText: 'Date of Absence'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
          ],
        );

      case NotificationTemplateType.emergencyAlert:
        return Column(
          children: [
            TextFormField(
              controller: _emergencyEventController,
              decoration: const InputDecoration(labelText: 'Emergency Event / Incident Details'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emergencyInstructionsController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Actionable Instructions'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
          ],
        );
    }
  }
}
