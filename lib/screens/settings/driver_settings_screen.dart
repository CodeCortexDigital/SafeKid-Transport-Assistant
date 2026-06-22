import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/billing_provider.dart';
import '../../models/student_model.dart';
import '../../models/billing_model.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_text_field.dart';
import '../../services/firebase/notification_service.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AttendanceProvider>(context, listen: false).fetchAllStudents();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text(
          'Driver Control Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryLight,
          labelColor: AppTheme.primaryLight,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Kids'),
            Tab(icon: Icon(Icons.payment_rounded), text: 'Bills'),
            Tab(icon: Icon(Icons.alarm_rounded), text: 'Timings'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildKidsTab(),
            _buildBillsTab(),
            _buildTimingsTab(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // KIDS TAB
  // ==========================================
  Widget _buildKidsTab() {
    final attendance = Provider.of<AttendanceProvider>(context);
    final kids = attendance.myStudents;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-kid-fab',
        onPressed: () => _showKidForm(context, null),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Kid', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: attendance.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : kids.isEmpty
              ? _buildEmptyState(Icons.face_rounded, 'No Kids Registered', 'Add a kid to get started.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: kids.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final kid = kids[index];
                    return GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
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
                                  kid.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${kid.schoolName} • Class ${kid.className}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                if (kid.parentUid.isEmpty) ...[
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
                                      if (kid.linkingOtp != null) ...[
                                        const SizedBox(width: 8),
                                        (() {
                                          final isExpired = kid.linkingOtpExpires != null && DateTime.now().isAfter(kid.linkingOtpExpires!);
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (isExpired ? AppTheme.error : AppTheme.success).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: (isExpired ? AppTheme.error : AppTheme.success).withOpacity(0.3), width: 0.5),
                                            ),
                                            child: Text(
                                              'OTP: ${kid.linkingOtp} ${isExpired ? "(EXPIRED)" : "(ACTIVE)"}',
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
                                ] else if (kid.parentPhone.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Parent: ${kid.parentName} (${kid.parentPhone})',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (kid.parentUid.isEmpty)
                            IconButton(
                              icon: const Icon(Icons.vpn_key_rounded, color: AppTheme.accentLight, size: 20),
                              tooltip: kid.linkingOtp == null ? 'Generate Linking OTP' : 'Regenerate Linking OTP',
                              onPressed: () async {
                                final otp = (100000 + Random().nextInt(900000)).toString();
                                final expires = DateTime.now().add(const Duration(minutes: 5));
                                final updatedKid = kid.copyWith(
                                  linkingOtp: otp,
                                  linkingOtpExpires: expires,
                                );
                                final ok = await attendance.editStudent(updatedKid);
                                if (ok && context.mounted) {
                                  _showOtpShareDialog(context, kid.name, otp);
                                }
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryLight, size: 20),
                            onPressed: () => _showKidForm(context, kid),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.error, size: 20),
                            onPressed: () => _showKidDeleteConfirm(context, kid),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  void _showKidForm(BuildContext context, StudentModel? kid) {
    final isEdit = kid != null;
    final nameController = TextEditingController(text: kid?.name);
    final schoolController = TextEditingController(text: kid?.schoolName ?? 'Attock City School');
    final classController = TextEditingController(text: kid?.className);
    final sectionController = TextEditingController(text: kid?.section);
    final parentNameController = TextEditingController(text: kid?.parentName);
    final parentPhoneController = TextEditingController(text: kid?.parentPhone);
    final pickupController = TextEditingController(text: kid?.pickupPoint);
    final dropController = TextEditingController(text: kid?.dropPoint);
    final feeController = TextEditingController(text: kid != null ? kid.monthlyFee.toStringAsFixed(2) : '150.00');
    final formKey = GlobalKey<FormState>();

    bool hasCustom = kid?.hasCustomTimings ?? false;
    final customPickupController = TextEditingController(text: kid?.customPickupTime ?? '08:30 AM');
    final customDropController = TextEditingController(text: kid?.customDropTime ?? '01:30 PM');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: Text(
                isEdit ? 'Edit Kid Details' : 'Add New Kid',
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
                        labelText: 'Full Name',
                        hintText: 'e.g. Liam Smith',
                        prefixIcon: Icons.person_rounded,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: schoolController,
                        labelText: 'School Name',
                        hintText: 'e.g. Attock City School',
                        prefixIcon: Icons.school_rounded,
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: classController,
                              labelText: 'Class',
                              hintText: 'e.g. Grade 5',
                              prefixIcon: Icons.class_rounded,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              controller: sectionController,
                              labelText: 'Section',
                              hintText: 'e.g. B',
                              prefixIcon: Icons.grid_view_rounded,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: parentNameController,
                        labelText: 'Parent Name',
                        hintText: 'e.g. John Smith',
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: parentPhoneController,
                        labelText: 'Parent Phone',
                        hintText: 'e.g. +923001234567',
                        prefixIcon: Icons.phone_iphone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: pickupController,
                        labelText: 'Pickup Stop Point',
                        hintText: 'e.g. Hazro Stop',
                        prefixIcon: Icons.location_on_rounded,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: dropController,
                        labelText: 'Drop Stop Point',
                        hintText: 'e.g. Attock School Stop',
                        prefixIcon: Icons.location_searching_rounded,
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
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      
                      if (isEdit) {
                        final updatedKid = kid.copyWith(
                          name: nameController.text.trim(),
                          schoolName: schoolController.text.trim(),
                          className: classController.text.trim(),
                          section: sectionController.text.trim(),
                          parentName: parentNameController.text.trim(),
                          parentPhone: parentPhoneController.text.trim(),
                          pickupPoint: pickupController.text.trim(),
                          dropPoint: dropController.text.trim(),
                          hasCustomTimings: hasCustom,
                          customPickupTime: hasCustom ? customPickupController.text.trim() : null,
                          customDropTime: hasCustom ? customDropController.text.trim() : null,
                          monthlyFee: double.tryParse(feeController.text.trim()) ?? 150.0,
                        );
                        final ok = await attendance.editStudent(updatedKid);
                        if (ok) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('Kid updated successfully'), backgroundColor: AppTheme.success),
                          );
                          if (hasCustom) {
                            NotificationService().triggerNotification(
                              title: 'Custom Schedule Updated',
                              body: 'Driver has set custom pickup/drop timings for ${updatedKid.name}: Pickup at ${updatedKid.customPickupTime ?? "N/A"}, Drop at ${updatedKid.customDropTime ?? "N/A"}.',
                              studentId: updatedKid.id,
                            );
                          } else if (kid.hasCustomTimings) {
                            NotificationService().triggerNotification(
                              title: 'Route Timings Reset',
                              body: 'Driver has reset timings for ${updatedKid.name} to standard schedule.',
                              studentId: updatedKid.id,
                            );
                          }
                        }
                      } else {
                        final newId = 'student-${DateTime.now().millisecondsSinceEpoch}';
                        final otp = (100000 + Random().nextInt(900000)).toString();
                        final expires = DateTime.now().add(const Duration(minutes: 5));
                        final newKid = StudentModel(
                          id: newId,
                          name: nameController.text.trim(),
                          schoolName: schoolController.text.trim(),
                          className: classController.text.trim(),
                          section: sectionController.text.trim(),
                          parentName: parentNameController.text.trim(),
                          parentPhone: parentPhoneController.text.trim(),
                          pickupPoint: pickupController.text.trim(),
                          dropPoint: dropController.text.trim(),
                          parentUid: '',
                          qrCodeData: newId,
                          linkingOtp: otp,
                          linkingOtpExpires: expires,
                          hasCustomTimings: hasCustom,
                          customPickupTime: hasCustom ? customPickupController.text.trim() : null,
                          customDropTime: hasCustom ? customDropController.text.trim() : null,
                          monthlyFee: double.tryParse(feeController.text.trim()) ?? 150.0,
                        );
                        final ok = await attendance.addStudent(newKid);
                        if (ok) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('Kid registered successfully'), backgroundColor: AppTheme.success),
                          );
                          if (hasCustom) {
                            NotificationService().triggerNotification(
                              title: 'Custom Schedule Updated',
                              body: 'Driver has set custom pickup/drop timings for ${newKid.name}: Pickup at ${newKid.customPickupTime ?? "N/A"}, Drop at ${newKid.customDropTime ?? "N/A"}.',
                              studentId: newKid.id,
                            );
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            _showOtpShareDialog(context, newKid.name, otp);
                          }
                          return;
                        }
                      }
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showKidDeleteConfirm(BuildContext context, StudentModel kid) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text('Delete Student?'),
          content: Text('Are you sure you want to remove "${kid.name}" from your route? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final attendance = Provider.of<AttendanceProvider>(context, listen: false);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final ok = await attendance.deleteStudent(kid.id);
                if (ok) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Kid deleted successfully'), backgroundColor: AppTheme.success),
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
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

  // ==========================================
  // BILLS TAB
  // ==========================================
  Widget _buildBillsTab() {
    final attendance = Provider.of<AttendanceProvider>(context);
    final billingProvider = Provider.of<BillingProvider>(context);

    final parentIds = attendance.myStudents
        .map((s) => s.parentUid)
        .where((uid) => uid.isNotEmpty)
        .toSet()
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-bill-fab',
        onPressed: () => _showBillForm(context, null),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add_card_rounded, color: Colors.white),
        label: const Text('Add Bill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<BillingModel>>(
        stream: billingProvider.streamDriverRouteBills(parentIds),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }
          final bills = snapshot.data ?? [];
          if (bills.isEmpty) {
            return _buildEmptyState(Icons.payment_rounded, 'No Invoices Found', 'Add a billing record for a student.');
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bills.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final bill = bills[index];
              final isPaid = bill.status.toLowerCase() == 'paid';
              
              final kid = attendance.myStudents.firstWhere(
                (s) => s.id == bill.studentId,
                orElse: () => StudentModel(
                  id: bill.studentId,
                  name: 'Student (${bill.studentId})',
                  className: '',
                  section: '',
                  schoolName: '',
                  parentUid: bill.parentId,
                  qrCodeData: '',
                ),
              );

              return GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: (isPaid ? AppTheme.success : AppTheme.warning).withOpacity(0.12),
                      child: Icon(
                        isPaid ? Icons.check_circle_outline_rounded : Icons.hourglass_empty_rounded,
                        color: isPaid ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kid.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Amount: \$${bill.amount.toStringAsFixed(2)} • Status: ${bill.status.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold,
                              color: isPaid ? AppTheme.success : AppTheme.warning
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Due: ${bill.dueDate.day}/${bill.dueDate.month}/${bill.dueDate.year}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryLight, size: 20),
                      onPressed: () => _showBillForm(context, bill),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.error, size: 20),
                      onPressed: () => _showBillDeleteConfirm(context, bill),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showBillForm(BuildContext context, BillingModel? bill) {
    final isEdit = bill != null;
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    
    if (attendance.myStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one kid before generating bills'), backgroundColor: AppTheme.error),
      );
      return;
    }

    String selectedKidId = bill?.studentId ?? attendance.myStudents.first.id;
    final amountController = TextEditingController(text: bill?.amount.toString() ?? '150.0');
    String selectedStatus = bill?.status ?? 'pending';
    String selectedPaymentMethod = bill?.paymentMethod ?? 'Cash';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: Text(
                isEdit ? 'Edit Invoice' : 'Generate New Bill',
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Kid Dropdown Selector
                      if (!isEdit) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Select Kid:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: AppTheme.surfaceColor,
                              value: selectedKidId,
                              isExpanded: true,
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedKidId = val;
                                  });
                                }
                              },
                              items: attendance.myStudents.map((kid) {
                                return DropdownMenuItem<String>(
                                  value: kid.id,
                                  child: Text(kid.name, style: const TextStyle(color: Colors.white)),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      CustomTextField(
                        controller: amountController,
                        labelText: 'Bill Amount (\$)',
                        hintText: '150.0',
                        prefixIcon: Icons.attach_money_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          if (double.tryParse(val) == null) return 'Enter valid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Status Selector
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Invoice Status:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: AppTheme.surfaceColor,
                            value: selectedStatus,
                            isExpanded: true,
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedStatus = val;
                                });
                              }
                            },
                            items: const [
                              DropdownMenuItem(value: 'paid', child: Text('PAID', style: TextStyle(color: AppTheme.success))),
                              DropdownMenuItem(value: 'pending', child: Text('PENDING', style: TextStyle(color: AppTheme.warning))),
                              DropdownMenuItem(value: 'unpaid', child: Text('UNPAID', style: TextStyle(color: AppTheme.error))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Payment Method Selector
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Payment Method:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: AppTheme.surfaceColor,
                            value: selectedPaymentMethod,
                            isExpanded: true,
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedPaymentMethod = val;
                                });
                              }
                            },
                            items: const [
                              DropdownMenuItem(value: 'Cash', child: Text('Cash', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'Card', child: Text('Card', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'Bank', child: Text('Bank Transfer', style: TextStyle(color: Colors.white))),
                            ],
                          ),
                        ),
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
                      final billingProvider = Provider.of<BillingProvider>(context, listen: false);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final amt = double.parse(amountController.text);
                      
                      final selectedKid = attendance.myStudents.firstWhere((s) => s.id == selectedKidId);
                      final parentId = selectedKid.parentUid.isNotEmpty ? selectedKid.parentUid : 'mock-parent-uid-123';

                      if (isEdit) {
                        final updatedBill = bill.copyWith(
                          amount: amt,
                          status: selectedStatus,
                          paymentMethod: selectedPaymentMethod,
                        );
                        await billingProvider.updateBill(updatedBill);
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Bill updated successfully'), backgroundColor: AppTheme.success),
                        );
                      } else {
                        final newId = 'bill-${DateTime.now().millisecondsSinceEpoch}';
                        final newBill = BillingModel(
                          id: newId,
                          parentId: parentId,
                          studentId: selectedKidId,
                          amount: amt,
                          status: selectedStatus,
                          billingDate: DateTime.now(),
                          dueDate: DateTime.now().add(const Duration(days: 15)),
                          paymentMethod: selectedPaymentMethod,
                        );
                        await billingProvider.createBill(newBill);
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Bill generated successfully'), backgroundColor: AppTheme.success),
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBillDeleteConfirm(BuildContext context, BillingModel bill) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text('Delete Invoice?'),
          content: const Text('Are you sure you want to remove this billing record? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final billingProvider = Provider.of<BillingProvider>(context, listen: false);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                await billingProvider.deleteBill(bill.id);
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Bill deleted successfully'), backgroundColor: AppTheme.success),
                );
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // TIMINGS TAB
  // ==========================================
  Widget _buildTimingsTab() {
    final attendance = Provider.of<AttendanceProvider>(context);
    final kids = attendance.myStudents;

    return Scaffold(
      body: attendance.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : kids.isEmpty
              ? _buildEmptyState(Icons.alarm_rounded, 'No Timings Found', 'Timings are managed per kid.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: kids.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final kid = kids[index];
                    final hasCustom = kid.hasCustomTimings;
                    final pickupTime = hasCustom && kid.customPickupTime != null ? kid.customPickupTime! : '08:30 AM';
                    final dropTime = hasCustom && kid.customDropTime != null ? kid.customDropTime! : '01:30 PM';

                    return GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: (hasCustom ? AppTheme.accentColor : AppTheme.primaryColor).withOpacity(0.12),
                            child: Icon(
                              Icons.alarm_rounded,
                              color: hasCustom ? AppTheme.accentLight : AppTheme.primaryLight,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  kid.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text('Starts: ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                    Text(
                                      pickupTime,
                                      style: TextStyle(
                                        fontSize: 12, 
                                        fontWeight: FontWeight.bold,
                                        color: hasCustom ? AppTheme.accentLight : Colors.white
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Text('Packup: ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                    Text(
                                      dropTime,
                                      style: TextStyle(
                                        fontSize: 12, 
                                        fontWeight: FontWeight.bold,
                                        color: hasCustom ? AppTheme.accentLight : Colors.white
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasCustom ? '🔔 Tomorrow\'s custom timings active' : '📅 Normal route schedule',
                                  style: TextStyle(
                                    fontSize: 10, 
                                    fontStyle: FontStyle.italic,
                                    color: hasCustom ? AppTheme.accentLight : AppTheme.textSecondary
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_calendar_rounded, color: AppTheme.primaryLight, size: 24),
                            onPressed: () => _showTimingsForm(context, kid),
                            tooltip: 'Modify Timings',
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  void _showTimingsForm(BuildContext context, StudentModel kid) {
    bool hasCustom = kid.hasCustomTimings;
    final pickupController = TextEditingController(text: kid.customPickupTime ?? '08:30 AM');
    final dropController = TextEditingController(text: kid.customDropTime ?? '01:30 PM');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: Text(
                'Edit Timings: ${kid.name}',
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Switch to enable/disable
                      SwitchListTile(
                        title: const Text('Custom Schedule', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Enable special pickup/drop times for next day', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        value: hasCustom,
                        activeColor: AppTheme.accentLight,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setDialogState(() {
                            hasCustom = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (hasCustom) ...[
                        CustomTextField(
                          controller: pickupController,
                          labelText: 'Class Start/Van Pickup (e.g. 08:30 AM)',
                          hintText: '08:30 AM',
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
                                pickupController.text = time.format(context);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: dropController,
                          labelText: 'Class Dismiss/Van Drop (e.g. 01:30 PM)',
                          hintText: '01:30 PM',
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
                                dropController.text = time.format(context);
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
                    if (!hasCustom || (formKey.currentState?.validate() ?? false)) {
                      final attendance = Provider.of<AttendanceProvider>(context, listen: false);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      
                      final updatedKid = kid.copyWith(
                        hasCustomTimings: hasCustom,
                        customPickupTime: hasCustom ? pickupController.text.trim() : null,
                        customDropTime: hasCustom ? dropController.text.trim() : null,
                      );
                      final ok = await attendance.editStudent(updatedKid);
                      if (ok) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Timings updated successfully'), backgroundColor: AppTheme.success),
                        );
                        if (hasCustom) {
                          NotificationService().triggerNotification(
                            title: 'Custom Schedule Updated',
                            body: 'Driver has set custom pickup/drop timings for ${updatedKid.name}: Pickup at ${updatedKid.customPickupTime ?? "N/A"}, Drop at ${updatedKid.customDropTime ?? "N/A"}.',
                            studentId: updatedKid.id,
                          );
                        } else if (kid.hasCustomTimings) {
                          NotificationService().triggerNotification(
                            title: 'Route Timings Reset',
                            body: 'Driver has reset timings for ${updatedKid.name} to standard schedule.',
                            studentId: updatedKid.id,
                          );
                        }
                      }
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // HELPERS
  // ==========================================
  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
