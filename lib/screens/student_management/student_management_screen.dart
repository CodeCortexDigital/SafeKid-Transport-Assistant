import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/app_state_provider.dart';
import '../../models/student_model.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_text_field.dart';
import '../../core/constants/app_constants.dart';
import '../../services/firebase/notification_service.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AttendanceProvider>(context, listen: false).fetchAllStudents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);

    // Filter students based on search query
    final filteredStudents = attendance.myStudents.where((student) {
      final query = _searchQuery.toLowerCase();
      return student.name.toLowerCase().contains(query) ||
          student.parentName.toLowerCase().contains(query) ||
          student.schoolName.toLowerCase().contains(query) ||
          student.className.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text(
          'Student Directory',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryLight),
            onPressed: () => attendance.fetchAllStudents(),
            tooltip: 'Refresh List',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStudentForm(context, null),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Search Students',
                  hintText: 'Search by name, parent, or school...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // Student List
              Expanded(
                child: attendance.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    : filteredStudents.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            itemCount: filteredStudents.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final student = filteredStudents[index];
                              return _buildStudentCard(context, student);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline_rounded, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text(
            'No Students Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search terms.'
                : 'Get started by adding a student to the directory.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showStudentDetailsDialog(BuildContext context, StudentModel student) {
    showDialog(
      context: context,
      builder: (context) {
        String statusLabel = 'At Home';
        Color statusColor = AppTheme.success;
        IconData statusIcon = Icons.home_rounded;

        switch (student.status) {
          case StudentStatus.home:
            statusLabel = 'At Home';
            statusColor = AppTheme.success;
            statusIcon = Icons.home_rounded;
            break;
          case StudentStatus.inTransit:
            statusLabel = 'In Transit';
            statusColor = AppTheme.warning;
            statusIcon = Icons.directions_bus_rounded;
            break;
          case StudentStatus.atSchool:
            statusLabel = 'At School';
            statusColor = AppTheme.primaryLight;
            statusIcon = Icons.school_rounded;
            break;
          case StudentStatus.absent:
            statusLabel = 'Absent';
            statusColor = AppTheme.error;
            statusIcon = Icons.cancel_rounded;
            break;
        }

        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                child: const Icon(Icons.face_rounded, color: AppTheme.primaryLight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      '${student.schoolName} • Class ${student.className} (${student.section})',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Current Status: $statusLabel',
                          style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Readiness Alert Section
                if (student.isStudentReady) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.success.withOpacity(0.2), width: 1),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Child is ready at the gate for pickup',
                            style: TextStyle(color: AppTheme.success, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Timings Row
                if (student.hasCustomTimings) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentColor.withOpacity(0.2), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.alarm_rounded, color: AppTheme.accentLight, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '⏰ Tomorrow\'s Custom Timings',
                                style: TextStyle(color: AppTheme.accentLight, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pickup: ${student.customPickupTime ?? "N/A"} • Drop: ${student.customDropTime ?? "N/A"}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Parent Details
                const Text(
                  'Parent Contact Details',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildModalDetailRow(Icons.person_rounded, 'Name', student.parentName),
                _buildModalDetailRow(Icons.phone_iphone_rounded, 'Phone', student.parentPhone),
                const SizedBox(height: 16),

                // Route Details
                const Text(
                  'Route & Stop Locations',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildModalDetailRow(Icons.location_on_rounded, 'Pickup Point', student.pickupPoint.isNotEmpty ? student.pickupPoint : 'Not set'),
                _buildModalDetailRow(Icons.location_searching_rounded, 'Drop Point', student.dropPoint.isNotEmpty ? student.dropPoint : 'Not set'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModalDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, StudentModel student) {
    return GestureDetector(
      onTap: () => _showStudentDetailsDialog(context, student),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Header (Name & Status Badge & Actions)
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                  child: const Icon(Icons.face_rounded, color: AppTheme.primaryLight),
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
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          if (student.hasCustomTimings) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.alarm_rounded, size: 14, color: AppTheme.accentLight),
                          ],
                        ],
                      ),
                      Text(
                        '${student.schoolName} • ${student.className} - ${student.section}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      if (student.parentUid.isEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.warning.withOpacity(0.3), width: 0.5),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.pending_rounded, size: 10, color: AppTheme.warning),
                                  SizedBox(width: 4),
                                  Text(
                                    'PENDING LINK',
                                    style: TextStyle(color: AppTheme.warning, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            if (student.linkingOtp != null) ...[
                              const SizedBox(width: 8),
                              (() {
                                final isExpired = student.linkingOtpExpires != null && DateTime.now().isAfter(student.linkingOtpExpires!);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isExpired ? AppTheme.error : AppTheme.success).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: (isExpired ? AppTheme.error : AppTheme.success).withOpacity(0.3), width: 0.5),
                                  ),
                                  child: Text(
                                    'OTP: ${student.linkingOtp} ${isExpired ? "(EXPIRED)" : "(ACTIVE)"}',
                                    style: TextStyle(
                                      color: isExpired ? AppTheme.error : AppTheme.success,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              })(),
                            ],
                          ],
                        ),
                      ],
                      if (student.isStudentReady || student.status == StudentStatus.absent || student.hasCustomTimings) ...[
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
                                  border: Border.all(color: AppTheme.success.withOpacity(0.3), width: 0.5),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 10, color: AppTheme.success),
                                    SizedBox(width: 4),
                                    Text(
                                      'READY',
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
                                   border: Border.all(color: AppTheme.warning.withOpacity(0.3), width: 0.5),
                                 ),
                                 child: const Row(
                                   children: [
                                     Icon(Icons.access_time_rounded, size: 10, color: AppTheme.warning),
                                     SizedBox(width: 4),
                                     Text(
                                       'WAITING',
                                       style: TextStyle(color: AppTheme.warning, fontSize: 8, fontWeight: FontWeight.bold),
                                     ),
                                   ],
                                 ),
                               ),
                             ],
                            if (student.status == StudentStatus.absent) ...[
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.cancel_outlined, size: 10, color: AppTheme.error),
                                    SizedBox(width: 4),
                                    Text(
                                      'LEAVE',
                                      style: TextStyle(color: AppTheme.error, fontSize: 8, fontWeight: FontWeight.bold),
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
                PopupMenuButton<String>(
                  onSelected: (val) async {
                    if (val == 'edit') {
                      _showStudentForm(context, student);
                    } else if (val == 'delete') {
                      _showDeleteConfirm(context, student);
                    } else if (val == 'qr') {
                      Navigator.pushNamed(context, '/qr-card', arguments: student);
                    } else if (val == 'otp') {
                      final otp = (100000 + Random().nextInt(900000)).toString();
                      final expires = DateTime.now().add(const Duration(minutes: 5));
                      final updated = student.copyWith(
                        linkingOtp: otp,
                        linkingOtpExpires: expires,
                      );
                      final ok = await Provider.of<AttendanceProvider>(context, listen: false).editStudent(updated);
                      if (ok && context.mounted) {
                        _showOtpShareDialog(context, student.name, otp);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'qr',
                      child: Row(
                        children: [
                          Icon(Icons.qr_code_rounded, size: 18, color: AppTheme.accentLight),
                          SizedBox(width: 8),
                          Text('View Pass QR'),
                        ],
                      ),
                    ),
                    if (student.parentUid.isEmpty)
                      PopupMenuItem(
                        value: 'otp',
                        child: Row(
                          children: [
                            const Icon(Icons.vpn_key_rounded, size: 18, color: AppTheme.accentLight),
                            const SizedBox(width: 8),
                            Text(student.linkingOtp == null ? 'Generate Link OTP' : 'Regenerate Link OTP'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 18, color: AppTheme.primaryLight),
                          SizedBox(width: 8),
                          Text('Edit Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever_rounded, size: 18, color: AppTheme.error),
                          SizedBox(width: 8),
                          Text('Remove Student', style: TextStyle(color: AppTheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white10, height: 1),
            ),
            // Row 2: Details Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(Icons.person_outline_rounded, 'Parent', student.parentName),
                      const SizedBox(height: 8),
                      _buildDetailRow(Icons.phone_iphone_rounded, 'Phone', student.parentPhone),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(Icons.location_on_outlined, 'Pickup', student.pickupPoint.isNotEmpty ? student.pickupPoint : 'Not set'),
                      const SizedBox(height: 8),
                      _buildDetailRow(Icons.location_searching_rounded, 'Drop', student.dropPoint.isNotEmpty ? student.dropPoint : 'Not set'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppTheme.accentLight),
        const SizedBox(width: 6),
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- ACTIONS: ADD / EDIT DIALOG FORM ---
  void _showStudentForm(BuildContext context, StudentModel? student) {
    final isEdit = student != null;
    final nameController = TextEditingController(text: student?.name);
    final schoolController = TextEditingController(text: student?.schoolName ?? 'Greenwood International');
    final classController = TextEditingController(text: student?.className);
    final sectionController = TextEditingController(text: student?.section);
    final parentNameController = TextEditingController(text: student?.parentName);
    final parentPhoneController = TextEditingController(text: student?.parentPhone);
    final pickupController = TextEditingController(text: student?.pickupPoint);
    final dropController = TextEditingController(text: student?.dropPoint);
    final feeController = TextEditingController(text: student != null ? student.monthlyFee.toStringAsFixed(2) : '150.00');
    final formKey = GlobalKey<FormState>();

    double pickupLat = student?.pickupLatitude ?? AppConstants.defaultHomeLatitude;
    double pickupLng = student?.pickupLongitude ?? AppConstants.defaultHomeLongitude;
    double dropLat = student?.dropLatitude ?? AppConstants.defaultHomeLatitude;
    double dropLng = student?.dropLongitude ?? AppConstants.defaultHomeLongitude;

    bool isPickupLocating = false;
    bool isDropLocating = false;
    bool hasCustom = student?.hasCustomTimings ?? false;
    final customPickupController = TextEditingController(text: student?.customPickupTime ?? '08:30 AM');
    final customDropController = TextEditingController(text: student?.customDropTime ?? '01:30 PM');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: Text(
                isEdit ? 'Edit Student Details' : 'Add New Student',
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomTextField(
                        controller: nameController,
                        labelText: 'Student Full Name',
                        hintText: 'e.g. Emma Doe',
                        prefixIcon: Icons.badge_outlined,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Student Name required' : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: schoolController,
                        labelText: 'School Name',
                        hintText: 'e.g. Greenwood School',
                        prefixIcon: Icons.school_outlined,
                        validator: (val) => val == null || val.trim().isEmpty ? 'School Name required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: classController,
                              labelText: 'Grade / Class',
                              hintText: 'e.g. Grade 3',
                              prefixIcon: Icons.class_outlined,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Class required' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: CustomTextField(
                              controller: sectionController,
                              labelText: 'Section',
                              hintText: 'e.g. A',
                              prefixIcon: Icons.grid_view_outlined,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Section required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: parentNameController,
                        labelText: 'Parent Name',
                        hintText: 'e.g. John Doe',
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Parent Name required' : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: parentPhoneController,
                        labelText: 'Parent Phone Number',
                        hintText: 'e.g. +1 555-1111',
                        prefixIcon: Icons.phone_iphone_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Parent Phone required' : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: pickupController,
                        labelText: 'Pickup Point Address',
                        hintText: 'e.g. 74th St & Madison Ave',
                        prefixIcon: Icons.location_on_outlined,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Pickup point required' : null,
                        suffixIcon: StatefulBuilder(
                          builder: (context, setSuffixState) {
                            return isPickupLocating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentLight),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.my_location_rounded, color: AppTheme.accentLight),
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
                                        pickupController.text = '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)} (Current Location)';
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Successfully loaded current GPS coordinates for Pickup Point!'),
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
                      CustomTextField(
                        controller: dropController,
                        labelText: 'Drop Point Address',
                        hintText: 'e.g. 82nd St & Lex Ave',
                        prefixIcon: Icons.location_searching_rounded,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Drop point required' : null,
                        suffixIcon: StatefulBuilder(
                          builder: (context, setSuffixState) {
                            return isDropLocating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentLight),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.my_location_rounded, color: AppTheme.accentLight),
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
                                        dropController.text = '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)} (Current Location)';
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Successfully loaded current GPS coordinates for Drop Point!'),
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
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: feeController,
                        labelText: 'Monthly Fee (\$)',
                        hintText: 'e.g. 150.00',
                        prefixIcon: Icons.attach_money_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          final fee = double.tryParse(val.trim());
                          if (fee == null) return 'Invalid fee';
                          if (fee < 0) return 'Cannot be negative';
                          return null;
                        },
                      ),
                      const Divider(color: Colors.white10),
                      SwitchListTile(
                        title: const Text('Custom Schedule', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Enable special pickup/drop times', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: customPickupController,
                          labelText: 'Custom Pickup Time',
                          hintText: 'e.g. 08:30 AM',
                          prefixIcon: Icons.alarm_rounded,
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time_rounded, color: AppTheme.accentLight, size: 18),
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                customPickupController.text = time.format(context);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: customDropController,
                          labelText: 'Custom Drop Time',
                          hintText: 'e.g. 01:30 PM',
                          prefixIcon: Icons.alarm_off_rounded,
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time_rounded, color: AppTheme.accentLight, size: 18),
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                customDropController.text = time.format(context);
                              }
                            },
                          ),
                        ),
                      ],
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
                      final attendance = Provider.of<AttendanceProvider>(context, listen: false);
                      final id = isEdit ? student.id : 'mock-student-${DateTime.now().millisecondsSinceEpoch}';
                      final otp = isEdit ? student.linkingOtp : (100000 + Random().nextInt(900000)).toString();
                      final expires = isEdit ? student.linkingOtpExpires : DateTime.now().add(const Duration(minutes: 5));
                      
                      final updatedStudent = StudentModel(
                        id: id,
                        name: nameController.text.trim(),
                        className: classController.text.trim(),
                        section: sectionController.text.trim(),
                        schoolName: schoolController.text.trim(),
                        parentUid: student?.parentUid ?? '',
                        qrCodeData: student?.qrCodeData ?? 'STUDENT_${nameController.text.trim().replaceAll(' ', '_').toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}',
                        status: student?.status ?? StudentStatus.home,
                        parentName: parentNameController.text.trim(),
                        parentPhone: parentPhoneController.text.trim(),
                        pickupPoint: pickupController.text.trim(),
                        dropPoint: dropController.text.trim(),
                        pickupLatitude: pickupLat,
                        pickupLongitude: pickupLng,
                        dropLatitude: dropLat,
                        dropLongitude: dropLng,
                        lastCheckIn: student?.lastCheckIn,
                        lastCheckOut: student?.lastCheckOut,
                        linkingOtp: otp,
                        linkingOtpExpires: expires,
                        hasCustomTimings: hasCustom,
                        customPickupTime: hasCustom ? customPickupController.text.trim() : null,
                        customDropTime: hasCustom ? customDropController.text.trim() : null,
                        monthlyFee: double.tryParse(feeController.text.trim()) ?? 150.0,
                      );

                      bool success;
                      if (isEdit) {
                        success = await attendance.editStudent(updatedStudent);
                      } else {
                        success = await attendance.addStudent(updatedStudent);
                      }

                      if (success) {
                        if (hasCustom) {
                          NotificationService().triggerNotification(
                            title: 'Custom Schedule Updated',
                            body: 'Driver has set custom pickup/drop timings for ${updatedStudent.name}: Pickup at ${updatedStudent.customPickupTime ?? "N/A"}, Drop at ${updatedStudent.customDropTime ?? "N/A"}.',
                            studentId: updatedStudent.id,
                          );
                        } else if (isEdit && student.hasCustomTimings) {
                          NotificationService().triggerNotification(
                            title: 'Route Timings Reset',
                            body: 'Driver has reset timings for ${updatedStudent.name} to standard schedule.',
                            studentId: updatedStudent.id,
                          );
                        }
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? (attendance.successMessage ?? 'Changes saved!')
                                : (attendance.errorMessage ?? 'An error occurred.')),
                            backgroundColor: success ? AppTheme.success : AppTheme.error,
                          ),
                        );
                        if (success && !isEdit && otp != null) {
                          _showOtpShareDialog(context, updatedStudent.name, otp);
                        }
                      }
                    }
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Add Student'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- ACTIONS: CONFIRM DELETE ---
  void _showDeleteConfirm(BuildContext context, StudentModel student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text('Delete Student?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to remove ${student.name} from the student directory? This action cannot be undone.',
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
                final attendance = Provider.of<AttendanceProvider>(context, listen: false);
                final success = await attendance.deleteStudent(student.id);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Student deleted successfully!' : (attendance.errorMessage ?? 'Delete failed.')),
                      backgroundColor: success ? AppTheme.success : AppTheme.error,
                    ),
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

  void _showOtpShareDialog(BuildContext context, String kidName, String otp) {
    showDialog(
      context: context,
      builder: (context) {
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
              Expanded(
                child: Text(
                  'Linking OTP for $kidName',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share this code with the parent. They must enter it on their dashboard to link their account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accentLight.withOpacity(0.3)),
                ),
                child: SelectableText(
                  otp,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentLight,
                    letterSpacing: 6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: AppTheme.warning),
                  SizedBox(width: 4),
                  Text(
                    'Expires in 5 minutes',
                    style: TextStyle(fontSize: 11, color: AppTheme.warning, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: otp));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('OTP copied to clipboard!'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              },
              child: const Text('Copy Code', style: TextStyle(color: AppTheme.accentLight)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
