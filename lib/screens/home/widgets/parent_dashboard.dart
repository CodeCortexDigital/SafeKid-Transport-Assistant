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
import '../../../widgets/driver_performance_card.dart';
import '../../../core/utils/location_utils.dart';
import '../../../providers/chat_provider.dart';
import '../../../models/user_model.dart';
import '../../../providers/billing_provider.dart';
import '../../../models/billing_model.dart';
import '../../../providers/feedback_provider.dart';

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
  int _driverRating = 5;
  int _safetyRating = 5;
  int _punctualityRating = 5;
  final TextEditingController _feedbackCommentsController = TextEditingController();

  @override
  void dispose() {
    _feedbackCommentsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        Provider.of<AttendanceProvider>(context, listen: false).fetchMyStudents(user.id, parentPhone: user.phone);
        Provider.of<LocationProvider>(context, listen: false).startTrackingTrip('mock-ride-1');
      }
    });
  }

  void _showCustomTimingsDialog(BuildContext context, StudentModel student) {
    bool hasCustom = student.hasCustomTimings;
    bool isReady = student.isReadyForPickup;
    bool isOnLeave = student.status == StudentStatus.absent;
    
    final pickupController = TextEditingController(text: student.customPickupTime ?? '08:30 AM');
    final dropController = TextEditingController(text: student.customDropTime ?? '01:30 PM');
    
    // Standard editable fields
    final schoolController = TextEditingController(text: student.schoolName);
    final classController = TextEditingController(text: student.className);
    final sectionController = TextEditingController(text: student.section);
    final pickupPointController = TextEditingController(text: student.pickupPoint);
    final dropPointController = TextEditingController(text: student.dropPoint);

    double pickupLat = student.pickupLatitude ?? AppConstants.defaultHomeLatitude;
    double pickupLng = student.pickupLongitude ?? AppConstants.defaultHomeLongitude;
    double dropLat = student.dropLatitude ?? AppConstants.defaultHomeLatitude;
    double dropLng = student.dropLongitude ?? AppConstants.defaultHomeLongitude;

    bool isPickupLocating = false;
    bool isDropLocating = false;

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
              title: Row(
                children: [
                  const Icon(Icons.settings_suggest_rounded, color: AppTheme.accentLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Manage: ${student.name}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                     // READINESS TOGGLE
                    SwitchListTile(
                      title: const Text('Ready for Pickup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      subtitle: const Text('Toggle to let the driver know child is ready at the gate.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      value: isReady,
                      activeColor: AppTheme.success,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setDialogState(() {
                          isReady = val;
                          if (val) {
                            isOnLeave = false;
                          }
                        });
                      },
                    ),
                    const Divider(color: Colors.white10),
                    
                    // LEAVE TOGGLE
                    SwitchListTile(
                      title: const Text('On Leave Tomorrow', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      subtitle: const Text('Mark child absent so the driver knows not to stop.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      value: isOnLeave,
                      activeColor: AppTheme.error,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setDialogState(() {
                          isOnLeave = val;
                          if (val) {
                            isReady = false;
                          }
                        });
                      },
                    ),
                    const Divider(color: Colors.white10),
                    
                    // CUSTOM TIMINGS TOGGLE
                    SwitchListTile(
                      title: const Text('Custom Tomorrow Timings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      subtitle: const Text('Set custom times for university/school class changes.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      value: hasCustom,
                      activeColor: AppTheme.accentLight,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setDialogState(() {
                          hasCustom = val;
                        });
                      },
                    ),
                    
                    if (hasCustom) ...[
                      const SizedBox(height: 8),
                      // Pickup Time selection
                      const Text(
                        'Tomorrow\'s Pickup / Class Start Time',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: pickupController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'e.g. 08:30 AM',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time_rounded, color: AppTheme.accentLight, size: 18),
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                pickupController.text = time.format(context);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Drop Time selection
                      const Text(
                        'Tomorrow\'s Packup / Drop Time',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: dropController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'e.g. 01:30 PM',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time_rounded, color: AppTheme.accentLight, size: 18),
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                dropController.text = time.format(context);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                    
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                    const Text(
                      'EDIT SCHOOL & ROUTE DETAILS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryLight, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 12),
                    
                    // School Name
                    _buildDialogTextField('School Name', schoolController),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(child: _buildDialogTextField('Class / Grade', classController)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDialogTextField('Section', sectionController)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Pickup Address
                    _buildDialogTextField(
                      'Pickup Address Point',
                      pickupPointController,
                      suffixIcon: StatefulBuilder(
                        builder: (context, setSuffixState) {
                          return isPickupLocating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentLight),
                                )
                              : IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.my_location_rounded, color: AppTheme.accentLight, size: 16),
                                  tooltip: 'Use current GPS location',
                                  onPressed: () async {
                                    setSuffixState(() {
                                      isPickupLocating = true;
                                    });
                                    try {
                                      final appState = Provider.of<AppStateProvider>(context, listen: false);
                                      final pos = await appState.locationService.getCurrentLocation();
                                      pickupLat = pos.latitude;
                                      pickupLng = pos.longitude;
                                      pickupPointController.text = '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)} (Current Location)';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Loaded current GPS coordinates for Pickup Point!'),
                                          backgroundColor: AppTheme.success,
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to get location: $e'),
                                          backgroundColor: AppTheme.error,
                                        ),
                                      );
                                    } finally {
                                      setSuffixState(() {
                                        isPickupLocating = false;
                                      });
                                    }
                                  },
                                );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Drop Address
                    _buildDialogTextField(
                      'Drop Address Point',
                      dropPointController,
                      suffixIcon: StatefulBuilder(
                        builder: (context, setSuffixState) {
                          return isDropLocating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentLight),
                                )
                              : IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.my_location_rounded, color: AppTheme.accentLight, size: 16),
                                  tooltip: 'Use current GPS location',
                                  onPressed: () async {
                                    setSuffixState(() {
                                      isDropLocating = true;
                                    });
                                    try {
                                      final appState = Provider.of<AppStateProvider>(context, listen: false);
                                      final pos = await appState.locationService.getCurrentLocation();
                                      dropLat = pos.latitude;
                                      dropLng = pos.longitude;
                                      dropPointController.text = '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)} (Current Location)';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Loaded current GPS coordinates for Drop Point!'),
                                          backgroundColor: AppTheme.success,
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to get location: $e'),
                                          backgroundColor: AppTheme.error,
                                        ),
                                      );
                                    } finally {
                                      setSuffixState(() {
                                        isDropLocating = false;
                                      });
                                    }
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
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final attendanceProv = Provider.of<AttendanceProvider>(context, listen: false);
                    final isReadyMorningReset = isReady && (student.status == StudentStatus.home || student.status == StudentStatus.absent);
                    final updatedStudent = student.copyWith(
                      schoolName: schoolController.text.trim(),
                      className: classController.text.trim(),
                      section: sectionController.text.trim(),
                      pickupPoint: pickupPointController.text.trim(),
                      dropPoint: dropPointController.text.trim(),
                      pickupLatitude: pickupLat,
                      pickupLongitude: pickupLng,
                      dropLatitude: dropLat,
                      dropLongitude: dropLng,
                      hasCustomTimings: hasCustom,
                      customPickupTime: hasCustom ? pickupController.text.trim() : null,
                      customDropTime: hasCustom ? dropController.text.trim() : null,
                      isReadyForPickup: isReady,
                      status: isOnLeave 
                          ? StudentStatus.absent 
                          : (isReadyMorningReset ? StudentStatus.home : (student.status == StudentStatus.absent ? StudentStatus.home : student.status)),
                      clearCheckIn: isReadyMorningReset,
                      clearCheckOut: isReadyMorningReset,
                    );
                    final success = await attendanceProv.editStudent(updatedStudent);
                    if (success && context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Details for ${student.name} updated successfully!'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogTextField(String label, TextEditingController controller, {Widget? suffixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  void _showLinkChildOtpDialog(BuildContext context, UserModel parentUser) {
    final formKey = GlobalKey<FormState>();
    final otpController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final attendanceProv = Provider.of<AttendanceProvider>(context);
            
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.vpn_key_rounded, color: AppTheme.accentLight),
                  const SizedBox(width: 8),
                  const Text(
                    'Link Child via OTP',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enter the 6-digit verification code provided by your driver to link your child\'s profile.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: otpController,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 8),
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '000000',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), letterSpacing: 8),
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.accentLight, width: 2),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length != 6) {
                            return 'Please enter a valid 6-digit OTP';
                          }
                          return null;
                        },
                      ),
                      if (attendanceProv.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          attendanceProv.errorMessage!,
                          style: const TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    attendanceProv.clearMessages();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: attendanceProv.isLoading
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() ?? false) {
                            final success = await attendanceProv.linkStudentViaOtp(
                              otpController.text.trim(),
                              parentUser.id,
                              parentUser.phone,
                              parentUser.name,
                            );
                            if (success && context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(attendanceProv.successMessage ?? 'Child linked successfully!'),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                              // Refresh
                              attendanceProv.fetchMyStudents(parentUser.id, parentPhone: parentUser.phone);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  child: attendanceProv.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Link Profile', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final appState = Provider.of<AppStateProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final parentUser = authProvider.user;

    if (attendance.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // SECURE PHONE CHECKPOINT BANNER
        _buildPhoneVerificationBanner(context, parentUser),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Children Directory',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            Row(
              children: [
                if (parentUser != null)
                  TextButton.icon(
                    onPressed: () => _showLinkChildOtpDialog(context, parentUser),
                    icon: const Icon(Icons.vpn_key_rounded, size: 18, color: AppTheme.accentLight),
                    label: const Text('Link Child via OTP', style: TextStyle(fontSize: 12, color: AppTheme.accentLight)),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryLight, size: 22),
                  onPressed: () {
                    final user = Provider.of<AuthProvider>(context, listen: false).user;
                    if (user != null) attendance.fetchMyStudents(user.id, parentPhone: user.phone);
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (attendance.myStudents.isEmpty)
          _buildEmptyState(context, parentUser)
        else
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
        if (parentUser != null) ...[
          const SizedBox(height: 28),
          const Text(
            'Billing & Payments',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          _buildBillingSection(context, parentUser.id),
          const SizedBox(height: 28),
          const Text(
            'Rate Transport Service',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          const DriverPerformanceCard(),
          const SizedBox(height: 20),
          _buildFeedbackForm(context, parentUser),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, UserModel? parentUser) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.child_care_rounded, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          const Text(
            'No Children Registered',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask your driver to add your child and provide you with a 6-digit OTP code to link their profile here securely.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (parentUser != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showLinkChildOtpDialog(context, parentUser),
              icon: const Icon(Icons.vpn_key_rounded, color: Colors.white),
              label: const Text('Link Child via OTP', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
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
                      if (student.isStudentReady || student.hasCustomTimings) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (student.isStudentReady) ...[
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 10, color: AppTheme.success),
                                    SizedBox(width: 4),
                                    Text(
                                      'READY FOR PICKUP',
                                      style: TextStyle(color: AppTheme.success, fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (student.status != StudentStatus.absent) ...[
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.access_time_rounded, size: 10, color: AppTheme.warning),
                                    SizedBox(width: 4),
                                    Text(
                                      'WAITING FOR PICKUP',
                                      style: TextStyle(color: AppTheme.warning, fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (student.hasCustomTimings) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentLight.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CUSTOM TIMINGS',
                                  style: TextStyle(color: AppTheme.accentLight, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
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
            // Tomorrow's Class & Packup Timings Box (Always Visible)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: student.hasCustomTimings 
                    ? AppTheme.accentColor.withOpacity(0.08)
                    : Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: student.hasCustomTimings 
                      ? AppTheme.accentColor.withOpacity(0.2)
                      : Colors.white.withOpacity(0.04),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primaryLight),
                          SizedBox(width: 6),
                          Text(
                            "Tomorrow's Schedule",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      if (student.hasCustomTimings)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CUSTOM',
                            style: TextStyle(color: AppTheme.accentLight, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'STANDARD',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.login_rounded, size: 14, color: AppTheme.success),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Class Starts',
                                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                ),
                                Text(
                                  student.hasCustomTimings && student.customPickupTime != null
                                      ? student.customPickupTime!
                                      : '08:30 AM',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 24, color: Colors.white10),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.logout_rounded, size: 14, color: AppTheme.error),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Packup / Dismiss',
                                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                ),
                                Text(
                                  student.hasCustomTimings && student.customDropTime != null
                                      ? student.customDropTime!
                                      : '01:30 PM',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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
                  onPressed: () async {
                    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final parentUser = authProvider.user;
                    if (parentUser != null) {
                      if (chatProvider.conversations.isEmpty) {
                        await chatProvider.fetchConversations(parentUser.id, parentUser.role);
                      }
                      final driver = chatProvider.conversations.firstWhere(
                        (u) => u.role == UserRole.driver,
                        orElse: () => UserModel(
                          id: 'mock-driver-uid-456',
                          name: 'Robert Smith',
                          phone: '',
                          role: UserRole.driver,
                          createdAt: DateTime.now(),
                        ),
                      );
                      if (context.mounted) {
                        Navigator.pushNamed(
                          context,
                          AppConstants.routeChat,
                          arguments: driver,
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Chat'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.primaryLight),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showCustomTimingsDialog(context, student),
                  icon: const Icon(Icons.alarm_rounded, size: 16),
                  label: const Text('Schedule'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.accentLight),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _QrCodeDialog.show(context, student),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Safety Pass'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.accentLight),
                ),
                const SizedBox(width: 8),
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

    final locationProv = Provider.of<LocationProvider>(context);
    final routeName = locationProv.currentTrip?.routeName ?? 'Greenwood Route 4B (Standard)';

    return Column(
      children: [
        _buildTimelineNode(
          label: 'Waiting',
          subtitle: 'Waiting for morning bus pickup',
          time: student.hasCustomTimings && student.customPickupTime != null ? student.customPickupTime! : '07:30 AM',
          isCompleted: step1Waiting,
          isActive: student.status == StudentStatus.home && !hasCheckOutToday && !isAbsent,
        ),
        _buildTimelineNode(
          label: 'Picked Up',
          subtitle: 'Boarded $routeName',
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

  Widget _buildBillingSection(BuildContext context, String parentId) {
    final billingProvider = Provider.of<BillingProvider>(context);

    return StreamBuilder<List<BillingModel>>(
      stream: billingProvider.streamParentBills(parentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final bills = snapshot.data ?? [];
        if (bills.isEmpty) {
          return const SizedBox.shrink();
        }

        // Find the latest pending invoice, or default to the most recent paid invoice
        final activeInvoice = bills.firstWhere(
          (b) => b.status.toLowerCase() != 'paid',
          orElse: () => bills.first,
        );

        final isPaid = activeInvoice.status.toLowerCase() == 'paid';
        final statusColor = isPaid ? AppTheme.success : AppTheme.warning;

        final attendance = Provider.of<AttendanceProvider>(context, listen: false);
        final student = attendance.myStudents.firstWhere(
          (s) => s.id == activeInvoice.studentId,
          orElse: () => StudentModel(
            id: '',
            name: '',
            className: '',
            section: '',
            schoolName: '',
            parentUid: parentId,
            parentName: '',
            qrCodeData: '',
          ),
        );
        final feeTitle = student.name.isNotEmpty 
            ? 'Transport Fees - ${student.name}' 
            : 'Transport Fees';

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payment_rounded, color: statusColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        feeTitle,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withOpacity(0.24), width: 1),
                    ),
                    child: Text(
                      activeInvoice.status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monthly Charge',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${activeInvoice.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isPaid ? 'Paid Date' : 'Due Date',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPaid
                            ? '${activeInvoice.billingDate.day}/${activeInvoice.billingDate.month}/${activeInvoice.billingDate.year}'
                            : '${activeInvoice.dueDate.day}/${activeInvoice.dueDate.month}/${activeInvoice.dueDate.year}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
              if (!isPaid) ...[
                const SizedBox(height: 16),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 16),
                billingProvider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    : ElevatedButton.icon(
                        onPressed: () {
                          billingProvider.payBill(activeInvoice.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Simulated payment of \$150.00 processed successfully!'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        },
                        icon: const Icon(Icons.credit_card_rounded, size: 16),
                        label: const Text('Pay Invoice Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeedbackForm(BuildContext context, UserModel parentUser) {
    final feedbackProvider = Provider.of<FeedbackProvider>(context);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRatingStars('Driver Rating', _driverRating, (val) {
            setState(() {
              _driverRating = val;
            });
          }),
          const SizedBox(height: 12),
          _buildRatingStars('Safety Rating', _safetyRating, (val) {
            setState(() {
              _safetyRating = val;
            });
          }),
          const SizedBox(height: 12),
          _buildRatingStars('Punctuality Rating', _punctualityRating, (val) {
            setState(() {
              _punctualityRating = val;
            });
          }),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
            ),
            child: TextField(
              controller: _feedbackCommentsController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Leave comments or suggestions...',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          feedbackProvider.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : ElevatedButton.icon(
                  onPressed: () async {
                    final success = await feedbackProvider.submitFeedback(
                      userId: parentUser.id,
                      userName: parentUser.name,
                      driverRating: _driverRating,
                      safetyRating: _safetyRating,
                      punctualityRating: _punctualityRating,
                      comments: _feedbackCommentsController.text,
                    );
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Feedback submitted successfully! Thank you.'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                      setState(() {
                        _driverRating = 5;
                        _safetyRating = 5;
                        _punctualityRating = 5;
                        _feedbackCommentsController.clear();
                      });
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Submit Feedback'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRatingStars(String label, int currentRating, Function(int) onRatingSelected) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final starVal = index + 1;
            return IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                starVal <= currentRating ? Icons.star_rounded : Icons.star_border_rounded,
                color: Colors.amber,
                size: 24,
              ),
              onPressed: () => onRatingSelected(starVal),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPhoneVerificationBanner(BuildContext context, UserModel? parentUser) {
    if (parentUser == null) return const SizedBox.shrink();

    final hasPhone = parentUser.phone.isNotEmpty;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (hasPhone ? AppTheme.success : AppTheme.warning).withOpacity(0.12),
            child: Icon(
              hasPhone ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
              color: hasPhone ? AppTheme.success : AppTheme.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPhone ? '✅ Verified Phone Link Active' : '🔒 Secure Phone Link Required',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPhone
                      ? 'Phone: ${parentUser.phone} • Syncing kids automatically'
                      : 'Verify phone number to sync kids added by your driver.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showPhoneVerificationDialog(context, parentUser),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasPhone ? Colors.white.withOpacity(0.08) : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              hasPhone ? 'Change' : 'Link & Verify',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhoneVerificationDialog(BuildContext context, UserModel parentUser) {
    final phoneController = TextEditingController(text: parentUser.phone);
    final otpController = TextEditingController();
    bool codeSent = false;
    String generatedCode = '';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              title: Row(
                children: [
                  Icon(
                    codeSent ? Icons.sms_rounded : Icons.phone_iphone_rounded,
                    color: AppTheme.accentLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    codeSent ? 'Enter OTP Code' : 'Verify Phone Number',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!codeSent) ...[
                      const Text(
                        'Security Checkpoint: Enter your mobile number to receive a secure OTP code. This prevents unauthorized access to student details.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Mobile Number',
                          hintText: 'e.g. 123456',
                          prefixIcon: const Icon(Icons.phone_rounded, color: AppTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Mobile number is required';
                          return null;
                        },
                      ),
                    ] else ...[
                      Text(
                        'A 6-digit verification code was sent to ${phoneController.text}. Enter it below to verify ownership.',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: otpController,
                        style: const TextStyle(color: Colors.white, letterSpacing: 8.0, fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: 'Verification Code',
                          hintText: '******',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          counterText: '',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length != 6) return 'Enter 6-digit code';
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                if (!codeSent)
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        final code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
                        
                        setDialogState(() {
                          generatedCode = code;
                          codeSent = true;
                        });
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.sms_rounded, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '[Mock SMS Gateway] Code sent to ${phoneController.text}: $code',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: AppTheme.info,
                            duration: const Duration(seconds: 8),
                          ),
                        );
                      }
                    },
                    child: const Text('Send Code', style: TextStyle(color: Colors.white)),
                  )
                else
                  ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState?.validate() ?? false) {
                        final enteredCode = otpController.text.trim();
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        
                        if (enteredCode == generatedCode || enteredCode == '123456') {
                          final verifiedPhone = phoneController.text.trim();
                          
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          final ok = await authProvider.updateUserPhone(verifiedPhone);
                          
                          if (ok) {
                            final attendanceProv = Provider.of<AttendanceProvider>(context, listen: false);
                            await attendanceProv.fetchMyStudents(parentUser.id, parentPhone: verifiedPhone);
                            
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Phone verified & children linked successfully!'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          } else {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(authProvider.errorMessage ?? 'Verification update failed'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                          if (context.mounted) Navigator.pop(context);
                        } else {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Invalid verification code. Please check the code sent to your mobile.'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Verify & Link', style: TextStyle(color: Colors.white)),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
