import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/attendance_provider.dart';
import '../../../models/student_model.dart';
import '../../../models/billing_model.dart';
import '../../../providers/billing_provider.dart';
import '../../../providers/feedback_provider.dart';
import '../../../models/feedback_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/driver_performance_card.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../providers/app_state_provider.dart';
import '../../../services/firebase/notification_service.dart';
import '../../../models/scan_log_model.dart';
import '../../../core/utils/location_utils.dart';
import '../../../models/trip_model.dart';

class DriverDashboard extends StatefulWidget {
  final Widget? mapWidget;
  const DriverDashboard({super.key, this.mapWidget});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final Set<String> _selectedStudentIds = {};
  final Set<String> _triggeredPickups = {};
  final Set<String> _triggeredDrops = {};
  LocationProvider? _locationProvider;
  bool _isSharingActionLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProv = Provider.of<LocationProvider>(context, listen: false);
      locationProv.startTrackingTrip('mock-ride-1');
      _locationProvider = locationProv;
      _locationProvider!.addListener(_onLocationUpdate);
      // Fetch route students immediately when dashboard loads
      Provider.of<AttendanceProvider>(context, listen: false).fetchAllStudents();
    });
  }

  @override
  void dispose() {
    _locationProvider?.removeListener(_onLocationUpdate);
    super.dispose();
  }

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
        // 1. Quick Actions Section Title & Grid
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
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
                  onTap: () async {
                    if (_isSharingActionLoading) return;

                    if (isSharing) {
                      setState(() {
                        _isSharingActionLoading = true;
                      });
                      try {
                        await locationProv.stopSharing();
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isSharingActionLoading = false;
                          });
                        }
                      }
                    } else {
                      final hasTransitStudents = attendance.myStudents.any(
                        (s) => s.status == StudentStatus.inTransit,
                      );

                      if (hasTransitStudents) {
                        if (!mounted) return;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: AppTheme.surfaceColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                            title: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
                                SizedBox(width: 8),
                                Text(
                                  'Trip In Progress',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            content: const Text(
                              'There are students currently in transit. Starting a new trip will reset all student statuses. Would you like to resume the current trip instead?',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: AppTheme.textSecondary),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  setState(() {
                                    _isSharingActionLoading = true;
                                  });
                                  try {
                                    await locationProv.startSharing('mock-ride-1');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Resumed active trip. Attendance was not reset.'),
                                          backgroundColor: AppTheme.success,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isSharingActionLoading = false;
                                      });
                                    }
                                  }
                                },
                                child: const Text('Resume Trip'),
                              ),
                            ],
                          ),
                        );
                      } else {
                        setState(() {
                          _isSharingActionLoading = true;
                        });
                        try {
                          await locationProv.startSharing('mock-ride-1');
                          await attendance.resetStudentsForTrip();
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isSharingActionLoading = false;
                            });
                          }
                        }
                      }
                    }
                  },
                ),
                _buildActionCard(
                  title: 'Pick/Drop',
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
                _buildActionCard(
                  title: 'Settings',
                  icon: Icons.settings_rounded,
                  color: AppTheme.primaryLight,
                  width: actionWidth,
                  onTap: () => Navigator.pushNamed(context, '/driver-settings'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // 2. Statistics Title & 2x2 Grid of Stat Cards
        const Text(
          'Route Statistics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
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

        // 3. Student Class Timings List
        const Text(
          'Student Class Timings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedStudentIds.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1),
            ),
            child: Row(
              children: [
                Text(
                  'Selected: ${_selectedStudentIds.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _handleBulkAction(context, StudentStatus.inTransit),
                  icon: const Icon(Icons.directions_bus_rounded, size: 16, color: AppTheme.success),
                  label: const Text('Board', style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: () => _handleBulkAction(context, StudentStatus.atSchool),
                  icon: const Icon(Icons.school_rounded, size: 16, color: AppTheme.primaryLight),
                  label: const Text('School', style: TextStyle(color: AppTheme.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: () => _handleBulkAction(context, StudentStatus.home),
                  icon: const Icon(Icons.home_rounded, size: 16, color: AppTheme.warning),
                  label: const Text('Drop', style: TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (attendance.myStudents.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: Text(
                'No students registered on your route.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: attendance.myStudents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final student = attendance.myStudents[index];
              final hasCustom = student.hasCustomTimings;
              final isAbsent = student.status == StudentStatus.absent;
              
              final pickupTime = hasCustom && student.customPickupTime != null
                  ? student.customPickupTime!
                  : '08:30 AM';
              final dropTime = hasCustom && student.customDropTime != null
                  ? student.customDropTime!
                  : '01:30 PM';
                  
              return GestureDetector(
                onTap: () => _showManualStatusDialog(context, student),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasCustom 
                          ? AppTheme.accentColor.withOpacity(0.2) 
                          : Colors.white.withOpacity(0.06), 
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (!isAbsent) ...[
                        GestureDetector(
                          onTap: () {}, // swallows tap event to prevent opening status dialog
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _selectedStudentIds.contains(student.id),
                              activeColor: AppTheme.primaryColor,
                              side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.5),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedStudentIds.add(student.id);
                                  } else {
                                    _selectedStudentIds.remove(student.id);
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      CircleAvatar(
                      backgroundColor: (isAbsent 
                          ? AppTheme.error 
                          : (hasCustom ? AppTheme.accentColor : AppTheme.primaryColor)).withOpacity(0.12),
                      child: Icon(
                        isAbsent 
                            ? Icons.cancel_outlined 
                            : (hasCustom ? Icons.alarm_rounded : Icons.face_rounded),
                        color: isAbsent 
                            ? AppTheme.error 
                            : (hasCustom ? AppTheme.accentLight : AppTheme.primaryLight),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                student.name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              if (isAbsent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'LEAVE',
                                    style: TextStyle(color: AppTheme.error, fontSize: 7, fontWeight: FontWeight.bold),
                                  ),
                                )
                              else ...[
                                if (hasCustom) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'CUSTOM',
                                      style: TextStyle(color: AppTheme.accentLight, fontSize: 7, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: (student.isStudentReady ? AppTheme.success : AppTheme.warning).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    student.isStudentReady ? 'READY' : 'WAITING',
                                    style: TextStyle(
                                      color: student.isStudentReady ? AppTheme.success : AppTheme.warning,
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${student.schoolName} • Class ${student.className}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Timings Display Column
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Starts: ',
                              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            ),
                            Text(
                              isAbsent ? 'N/A' : pickupTime,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isAbsent ? AppTheme.textMuted : (hasCustom ? AppTheme.accentLight : Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'Packup: ',
                              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            ),
                            Text(
                              isAbsent ? 'N/A' : dropTime,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isAbsent ? AppTheme.textMuted : (hasCustom ? AppTheme.accentLight : Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          ),
        const SizedBox(height: 24),

        // 4. Active Route Console Card
        _buildLiveStatusCard(context, isSharing),
        const SizedBox(height: 24),

        // 5. Active Route Map (if widget.mapWidget is not null)
        if (widget.mapWidget != null) ...[
          const Text(
            'Active Route GPS',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: widget.mapWidget!,
            ),
          ),
          const SizedBox(height: 24),
        ],

        // 6. Driver Performance Card
        const DriverPerformanceCard(),
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
    final locationProv = Provider.of<LocationProvider>(context);
    final currentRoute = locationProv.currentTrip?.routeName ?? 'Greenwood Route 4B (Standard)';
    final isStandard = !currentRoute.contains('(Alternative)');

    final dropdownItems = [
      'Greenwood Route 4B (Standard)',
      'Greenwood Route 4B (Alternative)',
    ];
    if (!dropdownItems.contains(currentRoute)) {
      dropdownItems.add(currentRoute);
    }

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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.route_outlined, color: AppTheme.primaryLight, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'ACTIVE TRANSIT ROUTE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isStandard 
                                            ? AppTheme.primaryColor.withOpacity(0.2) 
                                            : AppTheme.accentColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isStandard 
                                              ? AppTheme.primaryColor.withOpacity(0.4) 
                                              : AppTheme.accentColor.withOpacity(0.4),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        isStandard ? 'STANDARD' : 'ALTERNATIVE',
                                        style: TextStyle(
                                          color: isStandard ? AppTheme.primaryLight : AppTheme.accentLight,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _showCustomRouteDialog(context, locationProv, currentRoute),
                                      child: const Icon(
                                        Icons.edit_rounded,
                                        size: 14,
                                        color: AppTheme.primaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: currentRoute,
                                dropdownColor: AppTheme.surfaceColor,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryLight, size: 18),
                                isExpanded: true,
                                isDense: true,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                  fontFamily: 'Outfit',
                                ),
                                items: dropdownItems.map((route) {
                                  return DropdownMenuItem<String>(
                                    value: route,
                                    child: Text(route),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    locationProv.updateRouteName('mock-ride-1', value);
                                  }
                                },
                              ),
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



  // --- ACTIONS: BILLING ---
  void _showBillingDialog(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    final billingProvider = Provider.of<BillingProvider>(context, listen: false);

    // Auto-generate missing bills on dialog open
    billingProvider.autoGenerateMonthlyBills(attendance.myStudents);

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

                          // Resolve kid's details from route students
                          final student = attendance.myStudents.firstWhere(
                            (s) => s.id == bill.studentId,
                            orElse: () => StudentModel(
                              id: bill.studentId,
                              name: 'Student (${bill.studentId})',
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
                              student.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Parent: $parentName • Due: ${bill.dueDate.day}/${bill.dueDate.month}/${bill.dueDate.year}',
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
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isPaid ? AppTheme.success : AppTheme.warning,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      bill.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: isPaid ? AppTheme.success : AppTheme.warning,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: AppTheme.accentLight, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showEditBillDialog(context, bill, billingProvider),
                                  tooltip: 'Edit Invoice',
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: AppTheme.error, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showDeleteBillConfirm(context, bill, billingProvider),
                                  tooltip: 'Delete Invoice',
                                ),
                                if (!isPaid) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
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

  void _showEditBillDialog(BuildContext context, BillingModel bill, BillingProvider billingProvider) {
    final amountController = TextEditingController(text: bill.amount.toStringAsFixed(2));
    DateTime selectedDueDate = bill.dueDate;
    String selectedStatus = bill.status;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              title: const Text(
                'Edit Invoice Details',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomTextField(
                        controller: amountController,
                        labelText: 'Billing Amount (\$)',
                        hintText: 'e.g. 150.00',
                        prefixIcon: Icons.attach_money_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          final amount = double.tryParse(val.trim());
                          if (amount == null) return 'Invalid amount';
                          if (amount < 0) return 'Cannot be negative';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_rounded, color: AppTheme.accentLight),
                        title: const Text('Due Date', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        subtitle: Text(
                          '${selectedDueDate.day}/${selectedDueDate.month}/${selectedDueDate.year}',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_calendar_rounded, color: AppTheme.accentLight),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDueDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedDueDate = picked;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        dropdownColor: AppTheme.surfaceColor,
                        value: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Payment Status',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: Icon(Icons.info_outline_rounded, color: AppTheme.accentLight),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(color: Colors.white),
                        items: ['paid', 'pending', 'unpaid'].map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedStatus = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final updatedBill = bill.copyWith(
                        amount: double.tryParse(amountController.text.trim()) ?? bill.amount,
                        dueDate: selectedDueDate,
                        status: selectedStatus,
                      );
                      await billingProvider.updateBill(updatedBill);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invoice updated successfully'), backgroundColor: AppTheme.success),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteBillConfirm(BuildContext context, BillingModel bill, BillingProvider billingProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text('Delete Invoice?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to delete this invoice of \$${bill.amount.toStringAsFixed(2)}? This action cannot be undone.',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () async {
                await billingProvider.deleteBill(bill.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invoice deleted successfully'), backgroundColor: AppTheme.success),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
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

  void _onLocationUpdate() {
    if (!mounted) return;
    final locationProv = Provider.of<LocationProvider>(context, listen: false);
    final trip = locationProv.currentTrip;
    
    // Clear trigger sets if trip is not active or is completed/cancelled
    if (trip == null || trip.status != TripStatus.active) {
      _triggeredPickups.clear();
      _triggeredDrops.clear();
      return;
    }

    if (trip.currentLatitude == 0.0 || trip.currentLongitude == 0.0) return;

    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    final students = attendance.myStudents;

    // 1. Check Pickups (students who are at home and need to board)
    final pickupStops = <String, List<StudentModel>>{};
    for (var s in students) {
      if (s.status == StudentStatus.home) {
        pickupStops.putIfAbsent(s.pickupPoint, () => []).add(s);
      }
    }

    pickupStops.forEach((stopName, stopStudents) {
      if (stopName.isEmpty || stopStudents.isEmpty || _triggeredPickups.contains(stopName)) return;

      final student = stopStudents.first;
      final stopLat = student.pickupLatitude ?? AppConstants.defaultHomeLatitude;
      final stopLng = student.pickupLongitude ?? AppConstants.defaultHomeLongitude;

      final distance = LocationUtils.calculateDistance(
        trip.currentLatitude,
        trip.currentLongitude,
        stopLat,
        stopLng,
      );

      // Using 1.5 km threshold to capture discrete ticks in simulation
      if (distance < 1500.0) {
        _triggeredPickups.add(stopName);
        _showStopReachedDialog(stopName, stopStudents, true);
      }
    });

    // 2. Check Drops (students who are in transit and need to be dropped)
    final dropStops = <String, List<StudentModel>>{};
    for (var s in students) {
      if (s.status == StudentStatus.inTransit) {
        dropStops.putIfAbsent(s.dropPoint, () => []).add(s);
      }
    }

    dropStops.forEach((stopName, stopStudents) {
      if (stopName.isEmpty || stopStudents.isEmpty || _triggeredDrops.contains(stopName)) return;

      final student = stopStudents.first;
      final stopLat = student.dropLatitude ?? AppConstants.defaultSchoolLatitude;
      final stopLng = student.dropLongitude ?? AppConstants.defaultSchoolLongitude;

      final distance = LocationUtils.calculateDistance(
        trip.currentLatitude,
        trip.currentLongitude,
        stopLat,
        stopLng,
      );

      if (distance < 1500.0) {
        _triggeredDrops.add(stopName);
        _showStopReachedDialog(stopName, stopStudents, false);
      }
    });
  }

  Future<void> _updateStudentTransitState(BuildContext context, StudentModel student, bool isPickup) async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);

    double lat = AppConstants.defaultSchoolLatitude;
    double lng = AppConstants.defaultSchoolLongitude;
    try {
      final pos = await appState.locationService.getCurrentLocation();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}

    final nextStatus = isPickup ? StudentStatus.inTransit : (student.pickupPoint == student.dropPoint || student.dropPoint.contains('School') ? StudentStatus.atSchool : StudentStatus.home);
    final scanType = isPickup ? 'pickup' : (nextStatus == StudentStatus.atSchool ? 'school_arrival' : 'home_drop');

    final log = ScanLogModel(
      id: 'log-${DateTime.now().millisecondsSinceEpoch}',
      studentId: student.id,
      scannerId: 'mock-ride-1',
      scanType: scanType,
      timestamp: DateTime.now(),
      latitude: lat,
      longitude: lng,
      status: 'success',
    );
    await appState.scanLogRepository.logScan(log);
    await appState.studentRepository.updateAttendance(student.id, nextStatus);
    // Refresh the full route student list for drivers/assistants
    await attendance.fetchAllStudents();
  }

  void _showStopReachedDialog(String stopName, List<StudentModel> stopStudents, bool isPickup) {
    // Trigger notifications to parents of all students at this stop
    for (var student in stopStudents) {
      if (student.status == StudentStatus.absent) continue;
      NotificationService().triggerNotification(
        title: isPickup ? '🚐 Van Arriving for Pickup' : '🚐 Van Arrived at Drop-off Stop',
        body: isPickup
            ? 'The school van has reached the stop "${stopName}". Please make sure ${student.name} is ready for boarding.'
            : 'The school van has reached the stop "${stopName}" to drop ${student.name}.',
        studentId: student.id,
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final Map<String, bool> processingMap = {};
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            final attendance = Provider.of<AttendanceProvider>(context);
            
            // Map student status dynamically to check if already processed
            bool isStudentProcessed(StudentModel s) {
              if (isPickup) {
                return s.status == StudentStatus.inTransit;
              } else {
                return s.status == StudentStatus.atSchool || s.status == StudentStatus.home;
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isPickup ? AppTheme.success : AppTheme.warning).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: isPickup ? AppTheme.success : AppTheme.warning,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Stop Reached',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stopName,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPickup ? AppTheme.success : AppTheme.warning).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isPickup ? AppTheme.success : AppTheme.warning).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isPickup ? 'BOARDING STOP' : 'DROP-OFF STOP',
                      style: TextStyle(
                        color: isPickup ? AppTheme.success : AppTheme.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stopStudents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final initialStudent = stopStudents[index];
                    
                    // Look up current live student object from provider
                    final student = attendance.myStudents.firstWhere(
                      (s) => s.id == initialStudent.id,
                      orElse: () => initialStudent,
                    );

                    final processed = isStudentProcessed(student);
                    final isProcessing = processingMap[student.id] ?? false;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                            radius: 18,
                            child: Text(
                              student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                              style: const TextStyle(color: AppTheme.primaryLight, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${student.className} • ${student.section}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (processed)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  isPickup ? 'Boarded' : 'Dropped',
                                  style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          else if (isProcessing)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                            )
                          else
                            ElevatedButton(
                              onPressed: () async {
                                dialogSetState(() {
                                  processingMap[student.id] = true;
                                });
                                await _updateStudentTransitState(context, student, isPickup);
                                dialogSetState(() {
                                  processingMap[student.id] = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPickup ? AppTheme.success : AppTheme.warning,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                isPickup ? 'Board' : 'Drop',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.04),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Continue Route', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCustomRouteDialog(BuildContext context, LocationProvider locationProv, String currentRouteName) {
    final controller = TextEditingController(text: currentRouteName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_road_rounded, color: AppTheme.primaryLight),
              SizedBox(width: 8),
              Text(
                'Change Active Route',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter a custom name for the active transit route:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Greenwood Route 4B (Alt Route 3)',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.02),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  locationProv.updateRouteName('mock-ride-1', text);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleBulkAction(BuildContext context, StudentStatus nextStatus) async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    final idsToUpdate = List<String>.from(_selectedStudentIds);
    setState(() {
      _selectedStudentIds.clear();
    });

    int count = 0;
    for (var id in idsToUpdate) {
      try {
        final student = attendance.myStudents.firstWhere((s) => s.id == id);
        if (student.status == nextStatus || student.status == StudentStatus.absent) continue;

        final scanType = nextStatus == StudentStatus.inTransit 
            ? 'pickup' 
            : (nextStatus == StudentStatus.atSchool ? 'school_arrival' : 'home_drop');
        final log = ScanLogModel(
          id: 'log-${DateTime.now().millisecondsSinceEpoch}-$id',
          studentId: id,
          scannerId: 'mock-ride-1',
          scanType: scanType,
          timestamp: DateTime.now(),
          latitude: AppConstants.defaultSchoolLatitude,
          longitude: AppConstants.defaultSchoolLongitude,
          status: 'success',
        );
        await appState.scanLogRepository.logScan(log);
        await appState.studentRepository.updateAttendance(id, nextStatus);
        count++;
      } catch (_) {}
    }

    if (count > 0) {
      await attendance.fetchAllStudents();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Successfully updated status for $count student(s) in bulk!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _showManualStatusDialog(BuildContext context, StudentModel student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            'Update Status: ${student.name}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.directions_bus_rounded, color: AppTheme.success),
                title: const Text('Picked Up (Boarded)', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Mark student as picked up inside the van', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(context);
                  await _updateManualStatus(context, student, StudentStatus.inTransit);
                },
              ),
              const Divider(color: Colors.white10),
               ListTile(
                leading: const Icon(Icons.school_rounded, color: AppTheme.primaryLight),
                title: const Text('Reached School', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Mark student as safely reached school', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(context);
                  await _updateManualStatus(context, student, StudentStatus.atSchool);
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.home_rounded, color: AppTheme.warning),
                title: const Text('Dropped Home', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Mark student as safely dropped at home stop', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(context);
                  await _updateManualStatus(context, student, StudentStatus.home);
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: AppTheme.error),
                title: const Text('Mark On Leave / Absent', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Mark student absent for the day', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(context);
                  await _updateManualStatus(context, student, StudentStatus.absent);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateManualStatus(BuildContext context, StudentModel student, StudentStatus nextStatus) async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final scanType = nextStatus == StudentStatus.inTransit 
          ? 'pickup' 
          : (nextStatus == StudentStatus.atSchool ? 'school_arrival' : 'home_drop');
      
      final log = ScanLogModel(
        id: 'log-${DateTime.now().millisecondsSinceEpoch}',
        studentId: student.id,
        scannerId: 'mock-ride-1',
        scanType: scanType,
        timestamp: DateTime.now(),
        latitude: AppConstants.defaultSchoolLatitude,
        longitude: AppConstants.defaultSchoolLongitude,
        status: 'success',
      );
      await appState.scanLogRepository.logScan(log);
      await appState.studentRepository.updateAttendance(student.id, nextStatus);
      await attendance.fetchAllStudents();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Successfully updated ${student.name} status to ${nextStatus.name.toUpperCase()}!'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
