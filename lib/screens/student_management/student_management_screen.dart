import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/student_model.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_text_field.dart';

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

  Widget _buildStudentCard(BuildContext context, StudentModel student) {
    return GlassCard(
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
                    Text(
                      student.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    Text(
                      '${student.schoolName} • ${student.className} - ${student.section}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'edit') {
                    _showStudentForm(context, student);
                  } else if (val == 'delete') {
                    _showDeleteConfirm(context, student);
                  } else if (val == 'qr') {
                    Navigator.pushNamed(context, '/qr-card', arguments: student);
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
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
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
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: dropController,
                    labelText: 'Drop Point Address',
                    hintText: 'e.g. 82nd St & Lex Ave',
                    prefixIcon: Icons.location_searching_rounded,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Drop point required' : null,
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
                  final attendance = Provider.of<AttendanceProvider>(context, listen: false);
                  final id = isEdit ? student.id : 'mock-student-${DateTime.now().millisecondsSinceEpoch}';
                  
                  final updatedStudent = StudentModel(
                    id: id,
                    name: nameController.text.trim(),
                    className: classController.text.trim(),
                    section: sectionController.text.trim(),
                    schoolName: schoolController.text.trim(),
                    parentUid: student?.parentUid ?? 'mock-parent-uid-123',
                    qrCodeData: student?.qrCodeData ?? 'STUDENT_${nameController.text.trim().replaceAll(' ', '_').toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}',
                    status: student?.status ?? StudentStatus.home,
                    parentName: parentNameController.text.trim(),
                    parentPhone: parentPhoneController.text.trim(),
                    pickupPoint: pickupController.text.trim(),
                    dropPoint: dropController.text.trim(),
                    lastCheckIn: student?.lastCheckIn,
                    lastCheckOut: student?.lastCheckOut,
                  );

                  bool success;
                  if (isEdit) {
                    success = await attendance.editStudent(updatedStudent);
                  } else {
                    success = await attendance.addStudent(updatedStudent);
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
                  }
                }
              },
              child: Text(isEdit ? 'Save Changes' : 'Add Student'),
            ),
          ],
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
}
