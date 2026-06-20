import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/billing_model.dart';
import '../../models/student_model.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/billing_provider.dart';
import '../../providers/location_provider.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  
  StreamSubscription<List<BillingModel>>? _billingSubscription;
  List<BillingModel> _currentBills = [];
  bool _isTyping = false;

  final List<String> _suggestions = [
    'Where is my van?',
    'Has my child been picked up?',
    'Has my child reached school?',
    'What is my fee status?',
    'What are school timings?',
  ];

  @override
  void initState() {
    super.initState();

    // 1. Initialize chatbot with welcome message
    _messages.add({
      'text': "Hello! I am your SafeKid Assistant. 🤖 How can I help you today? Feel free to ask me questions about your van's location, your children's boarding logs, your fee balance, or general school schedules.",
      'isMe': false,
      'timestamp': DateTime.now(),
    });

    // 2. Stream real-time billing list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final locationProv = Provider.of<LocationProvider>(context, listen: false);
      final user = auth.user;
      
      if (user != null) {
        // Stream billing
        _billingSubscription = Provider.of<BillingProvider>(context, listen: false)
            .streamParentBills(user.id)
            .listen((bills) {
          if (mounted) {
            setState(() {
              _currentBills = bills;
            });
          }
        });

        // Ensure we load students
        Provider.of<AttendanceProvider>(context, listen: false).fetchMyStudents(user.id);

        // Auto-connect tracking to simulation trip if a child is in transit
        final attendance = Provider.of<AttendanceProvider>(context, listen: false);
        final inTransit = attendance.myStudents.any((s) => s.status == StudentStatus.inTransit);
        if (inTransit && locationProv.currentTrip == null) {
          locationProv.startTrackingTrip('mock-ride-1');
        }
      }
    });
  }

  @override
  void dispose() {
    _billingSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage(String text) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    setState(() {
      _messages.add({
        'text': cleanText,
        'isMe': true,
        'timestamp': DateTime.now(),
      });
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    final locationProv = Provider.of<LocationProvider>(context, listen: false);

    // Simulate typing delay (e.g. 800ms)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      final botResponseText = _generateBotResponse(
        students: attendance.myStudents,
        bills: _currentBills,
        currentTrip: locationProv.currentTrip,
        query: cleanText,
      );

      setState(() {
        _messages.add({
          'text': botResponseText,
          'isMe': false,
          'timestamp': DateTime.now(),
        });
        _isTyping = false;
      });
      _scrollToBottom();
    });
  }

  String _generateBotResponse({
    required List<StudentModel> students,
    required List<BillingModel> bills,
    required TripModel? currentTrip,
    required String query,
  }) {
    final cleanQuery = query.toLowerCase();

    // 1. Where is my van?
    if (cleanQuery.contains('where is my van') || 
        cleanQuery.contains('where is the van') || 
        cleanQuery.contains('van location') || 
        cleanQuery.contains('track van') ||
        cleanQuery.contains('track bus')) {
      
      final inTransitStudents = students.where((s) => s.status == StudentStatus.inTransit).toList();
      
      if (inTransitStudents.isEmpty) {
        if (students.isEmpty) {
          return "You don't have any children registered. Please contact the administrator to setup your profile.";
        }
        final statuses = students.map((s) => "${s.name} is ${s.status.name}").join(', ');
        return "Currently, none of your children are in transit ($statuses). Live van tracking is only available when a route is in progress. Morning pickups start around 07:30 AM.";
      }

      if (currentTrip != null && currentTrip.status == TripStatus.active) {
        final eta = currentTrip.etaMinutes;
        final lat = currentTrip.currentLatitude.toStringAsFixed(5);
        final lng = currentTrip.currentLongitude.toStringAsFixed(5);
        return "📍 *Van Tracker Details:*\n\n"
            "• *Route:* ${currentTrip.routeName}\n"
            "• *Status:* Active & In Transit\n"
            "• *Coordinates:* ($lat, $lng)\n"
            "• *ETA:* $eta mins\n\n"
            "You can monitor the live moving location on the home screen map.";
      } else {
        return "Your child is currently in transit, but the van's live GPS connection is not reporting coordinates yet. The system will start tracking shortly.";
      }
    }

    // 2. Has my child been picked up?
    if (cleanQuery.contains('picked up') || 
        cleanQuery.contains('pick up') || 
        cleanQuery.contains('pickup') ||
        cleanQuery.contains('boarded')) {
      
      if (students.isEmpty) {
        return "No children registered under your profile.";
      }

      List<String> reports = [];
      for (var s in students) {
        if (s.status == StudentStatus.inTransit) {
          final timeStr = s.lastCheckIn != null ? _formatTimeOnly(s.lastCheckIn!) : '07:45 AM';
          reports.add("✅ *${s.name}* was picked up and is in transit. Boarded Greenwood Route 4B at $timeStr.");
        } else if (s.status == StudentStatus.atSchool) {
          final timeStr = s.lastCheckIn != null ? _formatTimeOnly(s.lastCheckIn!) : '08:00 AM';
          reports.add("✅ *${s.name}* has already arrived at school. Boarded at $timeStr.");
        } else if (s.status == StudentStatus.absent) {
          reports.add("❌ *${s.name}* is marked as absent today.");
        } else {
          reports.add("🏠 *${s.name}* is at home. The van has not picked them up yet.");
        }
      }
      return "Here is the morning pickup status:\n\n" + reports.join('\n\n');
    }

    // 3. Has my child reached school?
    if (cleanQuery.contains('reached school') || 
        cleanQuery.contains('arrived school') || 
        cleanQuery.contains('at school') || 
        cleanQuery.contains('arrived at school')) {
      
      if (students.isEmpty) {
        return "No children registered under your profile.";
      }

      List<String> reports = [];
      for (var s in students) {
        if (s.status == StudentStatus.atSchool) {
          final timeStr = s.lastCheckIn != null ? _formatTimeOnly(s.lastCheckIn!) : '08:00 AM';
          reports.add("🏫 *${s.name}* has safely reached school. Gate arrival logged at $timeStr.");
        } else if (s.status == StudentStatus.inTransit) {
          reports.add("🚌 *${s.name}* is still in transit on the bus. ETA is about 10-15 minutes.");
        } else if (s.status == StudentStatus.absent) {
          reports.add("❌ *${s.name}* is marked as absent today.");
        } else {
          reports.add("🏠 *${s.name}* is still at home.");
        }
      }
      return "Here is the school arrival status:\n\n" + reports.join('\n\n');
    }

    // 4. What is my fee status?
    if (cleanQuery.contains('fee') || 
        cleanQuery.contains('billing') || 
        cleanQuery.contains('invoice') || 
        cleanQuery.contains('paid') ||
        cleanQuery.contains('payment')) {
      
      if (bills.isEmpty) {
        return "No billing records found for your account. Please contact school administration.";
      }

      final unpaid = bills.where((b) => b.status.toLowerCase() != 'paid').toList();
      if (unpaid.isEmpty) {
        return "✅ *Fee Status:* Your account is fully paid! You have no outstanding invoices. Thank you.";
      }

      List<String> reports = [];
      for (var b in unpaid) {
        final dueDateStr = "${b.dueDate.day}/${b.dueDate.month}/${b.dueDate.year}";
        reports.add("• Invoice #${b.id.substring(0, min(5, b.id.length))}: \$${b.amount.toStringAsFixed(2)} (${b.status.toUpperCase()}) due by $dueDateStr.");
      }
      return "💳 *Outstanding Fees:*\n\n" + reports.join('\n') + "\n\nYou can pay outstanding fees instantly on the dashboard under Billing.";
    }

    // 5. What are school timings?
    if (cleanQuery.contains('timing') || 
        cleanQuery.contains('timings') || 
        cleanQuery.contains('hour') || 
        cleanQuery.contains('hours') || 
        cleanQuery.contains('schedule')) {
      
      return "🏫 *School Timings & Schedule:*\n\n"
          "• *School Hours:* Mon - Fri, 08:00 AM - 02:30 PM\n"
          "• *Morning Bus Pickups:* Start at 07:30 AM\n"
          "• *Afternoon Drop-offs:* Start at 02:45 PM\n\n"
          "Please verify your child's specific route schedule for exact ETA adjustments.";
    }

    // Default Fallback Response
    return "I didn't quite catch that. I am your SafeKid Assistant. Try asking one of these questions:\n\n"
        "• \"Where is my van?\"\n"
        "• \"Has my child been picked up?\"\n"
        "• \"Has my child reached school?\"\n"
        "• \"What is my fee status?\"\n"
        "• \"What are school timings?\"";
  }

  String _formatTimeOnly(DateTime time) {
    final hr = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final min = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hr:$min $ampm';
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour > 12 ? timestamp.hour - 12 : (timestamp.hour == 0 ? 12 : timestamp.hour);
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final reversedMessages = _messages.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SafeKid Assistant',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Chatbot • Online Support',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat History
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: reversedMessages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isTyping && index == 0) {
                    return _buildTypingIndicator();
                  }

                  final messageIndex = _isTyping ? index - 1 : index;
                  final message = reversedMessages[messageIndex];
                  final isMe = message['isMe'] as bool;
                  final text = message['text'] as String;
                  final timestamp = message['timestamp'] as DateTime;

                  return _buildMessageBubble(text, isMe, timestamp);
                },
              ),
            ),

            // Horizontal suggestion chips
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(
                        suggestion,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: AppTheme.surfaceColor.withOpacity(0.6),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.08),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onPressed: () => _handleSendMessage(suggestion),
                    ),
                  );
                },
              ),
            ),

            // Composer Text Box
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Ask a question...',
                          hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 15),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        maxLines: 4,
                        minLines: 1,
                        onSubmitted: _handleSendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: () => _handleSendMessage(_messageController.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(3),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Assistant is thinking',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              SizedBox(width: 8),
              TypingIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, DateTime timestamp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                gradient: isMe ? AppTheme.primaryGradient : null,
                color: isMe ? null : AppTheme.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 3),
                  bottomRight: Radius.circular(isMe ? 3 : 18),
                ),
                border: isMe
                    ? null
                    : Border.all(
                        color: Colors.white.withOpacity(0.05),
                        width: 1,
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white.withOpacity(0.6) : AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final value = (1.0 - ((_controller.value - delay) % 1.0)).clamp(0.0, 1.0);
            final scale = 0.6 + 0.4 * value;
            final opacity = 0.4 + 0.6 * value;
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryLight,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
