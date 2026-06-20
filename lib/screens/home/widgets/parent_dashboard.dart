import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/app_state_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/attendance_provider.dart';
import '../../../models/student_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/glass_card.dart';
import '../../../core/utils/location_utils.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _QrCodeDialog {
  static void show(BuildContext context, StudentModel student) {
    // Navigate to QR Pass screen directly
    Navigator.pushNamed(context, AppConstants.routeQrCard, arguments: student);
  }
}

class _ParentDashboardState extends State<ParentDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        Provider.of<AttendanceProvider>(context, listen: false).fetchMyStudents(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final appState = Provider.of<AppStateProvider>(context);

    if (attendance.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    if (attendance.myStudents.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Children Directory',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryLight, size: 22),
              onPressed: () {
                final user = Provider.of<AuthProvider>(context, listen: false).user;
                if (user != null) attendance.fetchMyStudents(user.id);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Build real-time card for each child
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: attendance.myStudents.length,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final baseStudent = attendance.myStudents[index];
            return StreamBuilder<StudentModel>(
              stream: appState.studentRepository.watchStudent(baseStudent.id),
              initialData: baseStudent,
              builder: (context, snapshot) {
                final student = snapshot.data ?? baseStudent;
                return _buildChildCard(context, student);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: const Column(
        children: [
          Icon(Icons.child_care_rounded, size: 48, color: AppTheme.textMuted),
          SizedBox(height: 12),
          Text(
            'No Children Registered',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          SizedBox(height: 4),
          Text(
            'Contact the administrator to link your children profiles to this phone number.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // --- CHILD CARD BUILDER ---
  Widget _buildChildCard(BuildContext context, StudentModel student) {
    final locationProv = Provider.of<LocationProvider>(context);

    // Determine Status color & description
    Color statusColor = AppTheme.success;
    String statusLabel = 'At Home';
    IconData statusIcon = Icons.home_rounded;

    switch (student.status) {
      case StudentStatus.home:
        statusColor = AppTheme.success;
        statusLabel = 'At Home';
        statusIcon = Icons.home_rounded;
        break;
      case StudentStatus.inTransit:
        statusColor = AppTheme.warning;
        statusLabel = 'In Transit';
        statusIcon = Icons.directions_bus_rounded;
        break;
      case StudentStatus.atSchool:
        statusColor = AppTheme.primaryLight;
        statusLabel = 'At School';
        statusIcon = Icons.school_rounded;
        break;
      case StudentStatus.absent:
        statusColor = AppTheme.error;
        statusLabel = 'Absent';
        statusIcon = Icons.cancel_rounded;
        break;
    }

    // Calculate distance and ETA to bus if in transit
    double? distanceMeters;
    int? etaMinutes;
    if (student.status == StudentStatus.inTransit &&
        locationProv.currentTrip != null &&
        locationProv.currentTrip!.currentLatitude != 0.0) {
      final pickupLat = student.pickupLatitude ?? AppConstants.defaultHomeLatitude;
      final pickupLng = student.pickupLongitude ?? AppConstants.defaultHomeLongitude;
      
      distanceMeters = LocationUtils.calculateDistance(
        locationProv.currentTrip!.currentLatitude,
        locationProv.currentTrip!.currentLongitude,
        pickupLat,
        pickupLng,
      );
      etaMinutes = LocationUtils.calculateEtaMinutes(distanceMeters);
    }

    return Card(
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Profile Info & Status Badge
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.12),
                  child: Icon(statusIcon, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      Text(
                        '${student.schoolName} • ${student.className} (${student.section})',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                  ),
                  child: Text(
                    statusLabel.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (distanceMeters != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_bus_rounded, size: 16, color: AppTheme.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        etaMinutes == 0 
                            ? 'Van Arrived!' 
                            : 'Van arriving in $etaMinutes minutes',
                        style: const TextStyle(
                          fontSize: 12, 
                          color: AppTheme.warning, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      distanceMeters < 1000.0
                          ? '${distanceMeters.toStringAsFixed(0)} m'
                          : '${(distanceMeters / 1000.0).toStringAsFixed(2)} km',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Row 2: Status Timeline Title
            const Text(
              'Transit Timeline',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),

            // Row 3: Status Timeline List
            _buildTimeline(student),
            const SizedBox(height: 20),

            // Row 4: Route details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
              ),
              child: Column(
                children: [
                  _buildRoutePoint('Pickup Point', student.pickupPoint.isNotEmpty ? student.pickupPoint : 'Not set'),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Colors.white10, height: 1),
                  ),
                  _buildRoutePoint('Drop Point', student.dropPoint.isNotEmpty ? student.dropPoint : 'Not set'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Row 5: Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _QrCodeDialog.show(context, student),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Safety Pass'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.accentLight),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: student.status == StudentStatus.inTransit
                      ? () {
                          locationProv.startTrackingTrip('mock-ride-1');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Connected to live transit GPS tracker.'),
                              backgroundColor: AppTheme.primaryColor,
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.location_searching_rounded, size: 16),
                  label: const Text('Track Bus'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white.withOpacity(0.04),
                    disabledForegroundColor: Colors.white.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutePoint(String label, String value) {
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.accentLight),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- TIMELINE GENERATOR ---
  Widget _buildTimeline(StudentModel student) {
    // Determine active steps
    final isAbsent = student.status == StudentStatus.absent;

    // Check-in dates validation
    final hasCheckInToday = student.lastCheckIn != null &&
        student.lastCheckIn!.day == DateTime.now().day &&
        student.lastCheckIn!.month == DateTime.now().month;

    final hasCheckOutToday = student.lastCheckOut != null &&
        student.lastCheckOut!.day == DateTime.now().day &&
        student.lastCheckOut!.month == DateTime.now().month;

    // Determine states of each step
    final step1Waiting = !isAbsent;
    
    // Picked Up is true if student is inTransit or reached school, or dropped home (and it occurred today)
    final step2PickedUp = !isAbsent && (student.status == StudentStatus.inTransit || student.status == StudentStatus.atSchool || (student.status == StudentStatus.home && hasCheckOutToday));
    
    // Reached School is true if atSchool or inTransit (afternoon departure) or dropped home
    final step3ReachedSchool = !isAbsent && (student.status == StudentStatus.atSchool || (student.status == StudentStatus.inTransit && hasCheckInToday) || (student.status == StudentStatus.home && hasCheckOutToday));
    
    // Returned (departed school) is true if inTransit (afternoon) or dropped home
    final step4Returned = !isAbsent && ((student.status == StudentStatus.inTransit && hasCheckInToday) || (student.status == StudentStatus.home && hasCheckOutToday));
    
    // Dropped Home is true if home and check-out is today
    final step5DroppedHome = !isAbsent && (student.status == StudentStatus.home && hasCheckOutToday);

    // Format timestamps
    final pickupTimeStr = student.lastCheckIn != null ? _formatTime(student.lastCheckIn!) : 'Scheduled';
    final arrivalTimeStr = student.lastCheckIn != null ? _formatTime(student.lastCheckIn!.add(const Duration(minutes: 15))) : '--:--';
    final departureTimeStr = student.lastCheckOut != null ? _formatTime(student.lastCheckOut!.subtract(const Duration(minutes: 15))) : '--:--';
    final dropTimeStr = student.lastCheckOut != null ? _formatTime(student.lastCheckOut!) : '--:--';

    return Column(
      children: [
        _buildTimelineNode(
          label: 'Waiting',
          subtitle: 'Waiting for morning bus pickup',
          time: '07:30 AM',
          isCompleted: step1Waiting,
          isActive: student.status == StudentStatus.home && !hasCheckOutToday && !isAbsent,
        ),
        _buildTimelineNode(
          label: 'Picked Up',
          subtitle: 'Boarded Greenwood Route 4B',
          time: pickupTimeStr,
          isCompleted: step2PickedUp,
          isActive: student.status == StudentStatus.inTransit && !hasCheckInToday && !isAbsent,
        ),
        _buildTimelineNode(
          label: 'Reached School',
          subtitle: 'Arrived at Greenwood School gate',
          time: arrivalTimeStr,
          isCompleted: step3ReachedSchool,
          isActive: student.status == StudentStatus.atSchool && !isAbsent,
        ),
        _buildTimelineNode(
          label: 'Returned',
          subtitle: 'Departed school route back home',
          time: departureTimeStr,
          isCompleted: step4Returned,
          isActive: student.status == StudentStatus.inTransit && hasCheckInToday && !isAbsent,
        ),
        _buildTimelineNode(
          label: 'Dropped Home',
          subtitle: 'Safely arrived home and checked out',
          time: dropTimeStr,
          isCompleted: step5DroppedHome,
          isActive: student.status == StudentStatus.home && hasCheckOutToday && !isAbsent,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTimelineNode({
    required String label,
    required String subtitle,
    required String time,
    required bool isCompleted,
    required bool isActive,
    bool isLast = false,
  }) {
    Color nodeColor = AppTheme.textMuted;
    if (isCompleted) nodeColor = AppTheme.primaryLight;
    if (isActive) nodeColor = AppTheme.warning;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Circle & Line Indicator column
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isCompleted ? AppTheme.primaryColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: nodeColor,
                    width: isActive ? 3 : 2,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppTheme.warning.withOpacity(0.3),
                            blurRadius: 6,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? AppTheme.primaryLight.withOpacity(0.5) : Colors.white10,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content Row
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isActive ? AppTheme.warning : isCompleted ? Colors.white : AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? AppTheme.accentLight : AppTheme.textMuted,
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

  String _formatTime(DateTime time) {
    final hr = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final min = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hr:$min $ampm';
  }
}
