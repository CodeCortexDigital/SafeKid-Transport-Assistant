import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/attendance_provider.dart';
import '../../../models/student_model.dart';
import '../../../models/billing_model.dart';
import '../../../models/message_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';

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
                  onTap: () => _showMessagesDialog(context),
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
    final firestoreService = Provider.of<AppStateProvider>(context, listen: false).firestoreService;

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
            height: 350,
            child: Column(
              children: [
                // Quick Summary Row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text('Collected', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          SizedBox(height: 4),
                          Text('\$150.00', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.success)),
                        ],
                      ),
                      VerticalDivider(color: Colors.white24, width: 20),
                      Column(
                        children: [
                          Text('Pending', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          SizedBox(height: 4),
                          Text('\$150.00', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.warning)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<BillingModel>>(
                    stream: firestoreService.streamBillingRecords('mock-parent-uid-123'),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final records = snapshot.data ?? [];
                      if (records.isEmpty) {
                        return const Center(child: Text('No billing history found', style: TextStyle(color: AppTheme.textSecondary)));
                      }
                      return ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 12),
                        itemBuilder: (context, index) {
                          final bill = records[index];
                          final isPaid = bill.status.toLowerCase() == 'paid';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: (isPaid ? AppTheme.success : AppTheme.warning).withOpacity(0.1),
                              child: Icon(
                                isPaid ? Icons.check_circle_outline_rounded : Icons.hourglass_empty_rounded,
                                color: isPaid ? AppTheme.success : AppTheme.warning,
                              ),
                            ),
                            title: Text(
                              'John Doe (Parent Invoice)',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            subtitle: Text(
                              'Due: ${bill.dueDate.day}/${bill.dueDate.month}/${bill.dueDate.year}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            trailing: Text(
                              '\$${bill.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isPaid ? AppTheme.success : AppTheme.warning,
                              ),
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

  // --- ACTIONS: REPORTS ---
  void _showReportsDialog(BuildContext context) {
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
                'Route Analysis Report',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReportItem('Attendance Rate', '96.4%', Icons.check_circle_outline_rounded, AppTheme.success),
              const SizedBox(height: 12),
              _buildReportItem('Total Mileage (Month)', '154 km', Icons.directions_bus_filled_outlined, AppTheme.info),
              const SizedBox(height: 12),
              _buildReportItem('On-Time Schedule Performance', '98.1%', Icons.schedule_rounded, AppTheme.accentLight),
              const SizedBox(height: 12),
              _buildReportItem('Boarding QR Verification Failures', '0 incidents', Icons.warning_amber_rounded, AppTheme.warning),
              const SizedBox(height: 16),
              const Text(
                'All tracking metrics remain highly stable. Report auto-generated weekly.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Route report exported to local storage.')),
                );
              },
              child: const Text('Export PDF'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }


}
