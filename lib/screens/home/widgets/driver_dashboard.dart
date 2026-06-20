import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/attendance_provider.dart';
import '../../../models/student_model.dart';
import '../../../models/billing_model.dart';
import '../../../models/message_model.dart';
import '../../../providers/billing_provider.dart';
import '../../../providers/feedback_provider.dart';
import '../../../models/feedback_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/driver_performance_card.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final locationProv = Provider.of<LocationProvider>(context);

    // Calculate dynamic stats
    final totalStudents = attendance.myStudents.length;
    final todayPickups = attendance.myStudents.where((s) => s.status != StudentStatus.absent).length;
    final pendingPickups = attendance.myStudents.where((s) => s.status == StudentStatus.home).length;
    final totalParents = attendance.myStudents.map((s) => s.parentUid).toSet().length;

    final isSharing = locationProv.isSharingLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live GPS / Route Console Card
        _buildLiveStatusCard(context, isSharing),
        const SizedBox(height: 24),

        // Statistics Title
        const Text(
          'Route Statistics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // 2x2 Grid of Stat Cards
        LayoutBuilder(
          builder: (context, constraints) {
            double cardWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatCard(
                  title: 'Total Students',
                  value: '$totalStudents',
                  icon: Icons.people_alt_rounded,
                  color: AppTheme.primaryLight,
                  width: cardWidth,
                ),
                _buildStatCard(
                  title: "Today's Pickups",
                  value: '$todayPickups',
                  icon: Icons.airport_shuttle_rounded,
                  color: AppTheme.accentLight,
                  width: cardWidth,
                ),
                _buildStatCard(
                  title: 'Pending Board',
                  value: '$pendingPickups',
                  icon: Icons.pending_actions_rounded,
                  color: AppTheme.warning,
                  width: cardWidth,
                ),
                _buildStatCard(
                  title: 'Route Parents',
                  value: '$totalParents',
                  icon: Icons.family_restroom_rounded,
                  color: AppTheme.info,
                  width: cardWidth,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const DriverPerformanceCard(),
        const SizedBox(height: 24),

        // Quick Actions Section Title
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // 3x2 Grid of Quick Action Cards
        LayoutBuilder(
          builder: (context, constraints) {
            double actionWidth = (constraints.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionCard(
                  title: 'Students',
                  icon: Icons.people_alt_rounded,
                  color: AppTheme.primaryColor,
                  width: actionWidth,
                  onTap: () => Navigator.pushNamed(context, '/student-management'),
                ),
                _buildActionCard(
                  title: isSharing ? 'Stop Trip' : 'Start Trip',
                  icon: isSharing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: isSharing ? AppTheme.error : AppTheme.success,
                  width: actionWidth,
                  onTap: () {
                    if (isSharing) {
                      locationProv.stopSharing();
                    } else {
                      locationProv.startSharing('mock-ride-1');
                    }
                  },
                ),
                _buildActionCard(
                  title: 'QR Scanner',
                  icon: Icons.qr_code_scanner_rounded,
                  color: AppTheme.accentColor,
                  width: actionWidth,
                  onTap: () => Navigator.pushNamed(context, '/qr-scanner'),
                ),
                _buildActionCard(
                  title: 'Messages',
                  icon: Icons.chat_bubble_rounded,
                  color: AppTheme.info,
                  width: actionWidth,
                  onTap: () => Navigator.pushNamed(context, AppConstants.routeChatList),
                ),
                _buildActionCard(
                  title: 'Billing',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppTheme.warning,
                  width: actionWidth,
                  onTap: () => _showBillingDialog(context),
                ),
                _buildActionCard(
                  title: 'Reports',
                  icon: Icons.analytics_rounded,
                  color: Colors.purple,
                  width: actionWidth,
                  onTap: () => _showReportsDialog(context),
                ),
                _buildActionCard(
                  title: 'AI Alerts',
                  icon: Icons.notification_add_rounded,
                  color: Colors.deepOrangeAccent,
                  width: actionWidth,
                  onTap: () => Navigator.pushNamed(context, AppConstants.routeAiNotification),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // --- STAT CARD ---
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // --- ACTION CARD ---
  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required double width,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: width,
          height: 100,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- LIVE STATUS CARD ---
  Widget _buildLiveStatusCard(BuildContext context, bool isSharing) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Active Route Console',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSharing ? 'Sharing GPS location live' : 'Offline • GPS inactive',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSharing ? AppTheme.success : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSharing)
                _buildGlowingPulseDot()
              else
                const Icon(Icons.location_off_rounded, color: AppTheme.textMuted),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.route_outlined, color: AppTheme.primaryLight, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Greenwood Route 4B',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Standard Morning Route',
                              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Glowing dot animation mockup
  Widget _buildGlowingPulseDot() {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: AppTheme.success,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.success,
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
    );
  }

  // --- ACTIONS: MESSAGES ---
  void _showMessagesDialog(BuildContext context) {
    final firestoreService = Provider.of<AppStateProvider>(context, listen: false).firestoreService;
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              contentPadding: EdgeInsets.zero,
              title: const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.info),
                    SizedBox(width: 8),
                    Text(
                      'Parent Live Chats',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    const Divider(color: Colors.white12, height: 1),
                    Expanded(
                      child: StreamBuilder<List<MessageModel>>(
                        stream: firestoreService.streamMessages('mock-driver-uid-456', 'mock-parent-uid-123'),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final list = snapshot.data ?? [];
                          if (list.isEmpty) {
                            return const Center(child: Text('No messages yet', style: TextStyle(color: AppTheme.textSecondary)));
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              final msg = list[index];
                              final isMe = msg.senderId == 'mock-driver-uid-456';
                              return Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isMe ? AppTheme.primaryColor : Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(12),
                                      topRight: const Radius.circular(12),
                                      bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(0),
                                      bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.messageText,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isMe ? 'Driver' : 'John (Parent)',
                                        style: TextStyle(
                                          color: isMe ? Colors.white60 : AppTheme.textSecondary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: messageController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Type your message...',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                fillColor: Colors.white.withOpacity(0.04),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: AppTheme.primaryLight),
                            onPressed: () async {
                              final text = messageController.text.trim();
                              if (text.isEmpty) return;

                              final message = MessageModel(
                                id: 'mock-msg-${DateTime.now().millisecondsSinceEpoch}',
                                senderId: 'mock-driver-uid-456',
                                receiverId: 'mock-parent-uid-123',
                                messageText: text,
                                timestamp: DateTime.now(),
                                isRead: false,
                                tripId: 'mock-ride-1',
                              );

                              await firestoreService.sendMessage(message);
                              messageController.clear();
                              setState(() {}); // trigger chat list rebuild
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary)),
                )
              ],
            );
          },
        );
      },
    );
  }

  // --- ACTIONS: BILLING ---
  void _showBillingDialog(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    final billingProvider = Provider.of<BillingProvider>(context, listen: false);

    // Extract unique parent UIDs from students assigned to this driver
    final parentIds = attendance.myStudents
        .map((s) => s.parentUid)
        .where((uid) => uid.isNotEmpty)
        .toSet()
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Row(
            children: [
              Icon(Icons.payment_rounded, color: AppTheme.warning),
              SizedBox(width: 8),
              Text(
                'Route Billing Invoices',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                // Quick Summary Row
                StreamBuilder<List<BillingModel>>(
                  stream: billingProvider.streamDriverRouteBills(parentIds),
                  builder: (context, snapshot) {
                    final bills = snapshot.data ?? [];
                    final double collected = bills
                        .where((b) => b.status.toLowerCase() == 'paid')
                        .fold(0.0, (sum, b) => sum + b.amount);
                    final double pending = bills
                        .where((b) => b.status.toLowerCase() != 'paid')
                        .fold(0.0, (sum, b) => sum + b.amount);
                    final double total = collected + pending;

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSummaryCol('Collected', '\$${collected.toStringAsFixed(2)}', AppTheme.success),
                          Container(width: 1, height: 36, color: Colors.white12),
                          _buildSummaryCol('Pending', '\$${pending.toStringAsFixed(2)}', AppTheme.warning),
                          Container(width: 1, height: 36, color: Colors.white12),
                          _buildSummaryCol('Total Fees', '\$${total.toStringAsFixed(2)}', AppTheme.primaryLight),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<BillingModel>>(
                    stream: billingProvider.streamDriverRouteBills(parentIds),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                      }
                      final records = snapshot.data ?? [];
                      if (records.isEmpty) {
                        return const Center(
                          child: Text(
                            'No billing history found',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        );
                      }
                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 16),
                        itemBuilder: (context, index) {
                          final bill = records[index];
                          final isPaid = bill.status.toLowerCase() == 'paid';

                          // Resolve parent's name from route students
                          final student = attendance.myStudents.firstWhere(
                            (s) => s.parentUid == bill.parentId,
                            orElse: () => StudentModel(
                              id: '',
                              name: '',
                              className: '',
                              section: '',
                              schoolName: '',
                              parentUid: bill.parentId,
                              parentName: 'Parent (ID: ${bill.parentId.length > 5 ? bill.parentId.substring(0, 5) : bill.parentId})',
                              qrCodeData: '',
                            ),
                          );
                          final parentName = student.parentName.isNotEmpty
                              ? student.parentName
                              : 'Parent (ID: ${bill.parentId.length > 5 ? bill.parentId.substring(0, 5) : bill.parentId})';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: (isPaid ? AppTheme.success : AppTheme.warning).withOpacity(0.12),
                              child: Icon(
                                isPaid ? Icons.check_circle_outline_rounded : Icons.hourglass_empty_rounded,
                                color: isPaid ? AppTheme.success : AppTheme.warning,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              parentName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Due Date: ${bill.dueDate.day}/${bill.dueDate.month}/${bill.dueDate.year}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${bill.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isPaid ? AppTheme.success : AppTheme.warning,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      bill.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isPaid ? AppTheme.success : AppTheme.warning,
                                      ),
                                    ),
                                  ],
                                ),
                                if (!isPaid) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 22),
                                    onPressed: () {
                                      billingProvider.markAsPaid(bill.id);
                                    },
                                    tooltip: 'Mark as Paid',
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary)),
            )
          ],
        );
      },
    );
  }

  Widget _buildSummaryCol(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  // --- ACTIONS: REPORTS ---
  void _showReportsDialog(BuildContext context) {
    final feedbackProvider = Provider.of<FeedbackProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Row(
            children: [
              Icon(Icons.insights_rounded, color: Colors.purple),
              SizedBox(width: 8),
              Text(
                'Feedback & Ratings Console',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: StreamBuilder<List<FeedbackModel>>(
              stream: feedbackProvider.watchAllFeedback(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                }

                final feedbacks = snapshot.data ?? [];

                // Calculate category averages
                double avgDriver = 0.0;
                double avgSafety = 0.0;
                double avgPunctuality = 0.0;

                if (feedbacks.isNotEmpty) {
                  final totalDriver = feedbacks.fold<int>(0, (sum, f) => sum + f.driverRating);
                  final totalSafety = feedbacks.fold<int>(0, (sum, f) => sum + f.safetyRating);
                  final totalPunctuality = feedbacks.fold<int>(0, (sum, f) => sum + f.punctualityRating);

                  avgDriver = totalDriver / feedbacks.length;
                  avgSafety = totalSafety / feedbacks.length;
                  avgPunctuality = totalPunctuality / feedbacks.length;
                }

                return Column(
                  children: [
                    // Summary Ratings Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildRatingCol('Driver', avgDriver, Colors.amber),
                          Container(width: 1, height: 36, color: Colors.white12),
                          _buildRatingCol('Safety', avgSafety, AppTheme.success),
                          Container(width: 1, height: 36, color: Colors.white12),
                          _buildRatingCol('Punctuality', avgPunctuality, AppTheme.accentLight),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Recent Parent Comments',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: feedbacks.isEmpty
                          ? const Center(
                              child: Text(
                                'No feedback submitted yet.',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: feedbacks.length,
                              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 16),
                              itemBuilder: (context, index) {
                                final item = feedbacks[index];
                                final hasComments = item.comments.trim().isNotEmpty;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          item.userName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _buildMiniStars(item.rating),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Avg: ${item.rating}.0',
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                    if (hasComments) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        item.comments,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRatingCol(String title, double avg, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              avg == 0.0 ? '--' : avg.toStringAsFixed(1),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 2),
            Icon(Icons.star_rounded, color: color, size: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: Colors.amber,
          size: 14,
        );
      }),
    );
  }


}
