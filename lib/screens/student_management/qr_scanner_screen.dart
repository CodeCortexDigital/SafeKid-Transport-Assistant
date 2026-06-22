import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/student_model.dart';
import '../../models/scan_log_model.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/glass_card.dart';

enum ScanEventType {
  pickup,
  schoolArrival,
  schoolDeparture,
  homeDrop,
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  ScanEventType _selectedEventType = ScanEventType.pickup;
  bool _isProcessing = false;
  bool _useManualEntry = false;
  bool _showScanner = false;
  StudentModel? _lastScannedStudent;
  ScanEventType? _lastScannedType;
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualEntryController = TextEditingController();

  @override
  void dispose() {
    _scannerController.dispose();
    _manualEntryController.dispose();
    super.dispose();
  }

  String _getEventLabel(ScanEventType type) {
    switch (type) {
      case ScanEventType.pickup:
        return 'Pickup (Board Bus)';
      case ScanEventType.schoolArrival:
        return 'School Arrival (Drop)';
      case ScanEventType.schoolDeparture:
        return 'School Departure (Board)';
      case ScanEventType.homeDrop:
        return 'Home Drop-off';
    }
  }

  IconData _getEventIcon(ScanEventType type) {
    switch (type) {
      case ScanEventType.pickup:
        return Icons.airport_shuttle_rounded;
      case ScanEventType.schoolArrival:
        return Icons.school_rounded;
      case ScanEventType.schoolDeparture:
        return Icons.logout_rounded;
      case ScanEventType.homeDrop:
        return Icons.home_rounded;
    }
  }

  StudentStatus _getStudentStatus(ScanEventType type) {
    switch (type) {
      case ScanEventType.pickup:
        return StudentStatus.inTransit;
      case ScanEventType.schoolArrival:
        return StudentStatus.atSchool;
      case ScanEventType.schoolDeparture:
        return StudentStatus.inTransit;
      case ScanEventType.homeDrop:
        return StudentStatus.home;
    }
  }

  bool _isToday(DateTime? dt) {
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool _isMorningPickupPhase(StudentModel student) {
    return student.status == StudentStatus.home && !_isToday(student.lastCheckOut);
  }

  bool _isMorningInTransit(StudentModel student) {
    return student.status == StudentStatus.inTransit && !_isToday(student.lastCheckIn);
  }

  bool _isAtSchoolPhase(StudentModel student) {
    return student.status == StudentStatus.atSchool;
  }

  bool _isAfternoonInTransit(StudentModel student) {
    return student.status == StudentStatus.inTransit && _isToday(student.lastCheckIn);
  }

  bool _isDroppedHomePhase(StudentModel student) {
    return student.status == StudentStatus.home && _isToday(student.lastCheckOut);
  }

  String _getEventRatioString(List<StudentModel> students, ScanEventType eventType) {
    final activeStudents = students.where((s) => s.status != StudentStatus.absent).toList();
    if (activeStudents.isEmpty) return '0/0';

    int completed = 0;
    int total = 0;

    switch (eventType) {
      case ScanEventType.pickup:
        total = activeStudents.length;
        completed = activeStudents.where((s) => !_isMorningPickupPhase(s)).length;
        break;
      case ScanEventType.schoolArrival:
        total = activeStudents.where((s) => !_isMorningPickupPhase(s)).length;
        completed = activeStudents.where((s) => _isAtSchoolPhase(s) || _isAfternoonInTransit(s) || _isDroppedHomePhase(s)).length;
        break;
      case ScanEventType.schoolDeparture:
        total = activeStudents.length;
        completed = activeStudents.where((s) => _isAfternoonInTransit(s) || _isDroppedHomePhase(s)).length;
        break;
      case ScanEventType.homeDrop:
        total = activeStudents.where((s) => _isAfternoonInTransit(s) || _isDroppedHomePhase(s)).length;
        completed = activeStudents.where((s) => _isDroppedHomePhase(s)).length;
        break;
    }

    return '$completed/$total';
  }

  // --- LOGIC: PROCESS SCANNED CODE ---
  Future<void> _processQrCode(String qrData) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);

    try {
      // 1. Parse studentId from QR data
      String studentId = qrData;
      if (qrData.contains('|')) {
        studentId = qrData.split('|')[0];
      }

      // 2. Fetch Student details to verify existence
      final student = await appState.studentRepository.getStudentDetails(studentId);

      if (student.status == StudentStatus.absent) {
        throw 'Student is marked as on leave/absent today.';
      }

      // 3. Fetch GPS coordinate
      double lat = AppConstants.defaultSchoolLatitude;
      double lng = AppConstants.defaultSchoolLongitude;
      try {
        final pos = await appState.locationService.getCurrentLocation();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {
        // Fallback silently to school coords
      }

      // 4. Log Scan event in scan_logs
      final log = ScanLogModel(
        id: 'log-${DateTime.now().millisecondsSinceEpoch}',
        studentId: student.id,
        scannerId: 'mock-ride-1', // active tripId
        scanType: _selectedEventType.name,
        timestamp: DateTime.now(),
        latitude: lat,
        longitude: lng,
        status: 'success',
      );
      await appState.scanLogRepository.logScan(log);

      // 5. Update Student Transit Status
      final nextStatus = _getStudentStatus(_selectedEventType);
      await appState.studentRepository.updateAttendance(student.id, nextStatus);

      // 6. Refresh locally
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user?.role == UserRole.parent) {
        await attendance.fetchMyStudents(user!.id, parentPhone: user.phone);
      } else {
        await attendance.fetchAllStudents();
      }

      // Auto-advance tab if current stage is fully completed
      _checkAndAutoAdvanceTab(attendance.myStudents);

      // 7. Update Scanned state
      setState(() {
        _lastScannedStudent = student.copyWith(status: nextStatus);
        _lastScannedType = _selectedEventType;
      });

      // Show Toast Notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('Logged ${_getEventLabel(_selectedEventType)} for ${student.name}!'),
              ],
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Scan Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      // Pause slightly before allowing next scan
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Color _getStudentColorForEvent(StudentModel student, ScanEventType eventType) {
    if (student.status == StudentStatus.absent) {
      return AppTheme.error;
    }
    switch (eventType) {
      case ScanEventType.pickup:
        if (student.status == StudentStatus.inTransit || student.status == StudentStatus.atSchool) {
          return AppTheme.success;
        } else if (student.status == StudentStatus.home) {
          return AppTheme.warning;
        }
        return AppTheme.textMuted;
      case ScanEventType.schoolArrival:
        if (student.status == StudentStatus.atSchool) {
          return AppTheme.success;
        } else if (student.status == StudentStatus.inTransit) {
          return AppTheme.warning;
        }
        return AppTheme.textMuted;
      case ScanEventType.schoolDeparture:
        if (student.status == StudentStatus.inTransit || student.status == StudentStatus.home) {
          return AppTheme.success;
        } else if (student.status == StudentStatus.atSchool) {
          return AppTheme.warning;
        }
        return AppTheme.textMuted;
      case ScanEventType.homeDrop:
        if (student.status == StudentStatus.home) {
          return AppTheme.success;
        } else if (student.status == StudentStatus.inTransit) {
          return AppTheme.warning;
        }
        return AppTheme.textMuted;
    }
  }

  String _getStudentStatusLabelForEvent(StudentModel student, ScanEventType eventType) {
    if (student.status == StudentStatus.absent) {
      return 'On Leave';
    }
    switch (eventType) {
      case ScanEventType.pickup:
        if (student.status == StudentStatus.inTransit || student.status == StudentStatus.atSchool) {
          return 'Picked Up';
        } else if (student.status == StudentStatus.home) {
          return student.isStudentReady ? 'Ready' : 'Waiting';
        }
        return 'Waiting';
      case ScanEventType.schoolArrival:
        if (student.status == StudentStatus.atSchool) {
          return 'Reached School';
        } else if (student.status == StudentStatus.inTransit) {
          return 'Onboard';
        }
        return 'Waiting';
      case ScanEventType.schoolDeparture:
        if (student.status == StudentStatus.inTransit || student.status == StudentStatus.home) {
          return 'Picked Up';
        } else if (student.status == StudentStatus.atSchool) {
          return 'Reached School';
        }
        return 'Reached School';
      case ScanEventType.homeDrop:
        if (student.status == StudentStatus.home) {
          return 'Dropped Home';
        } else if (student.status == StudentStatus.inTransit) {
          return 'Onboard';
        }
        return 'Onboard';
    }
  }

  void _checkAndAutoAdvanceTab(List<StudentModel> students) {
    final activeStudents = students.where((s) => s.status != StudentStatus.absent).toList();
    if (activeStudents.isEmpty) return;

    bool isCurrentTabComplete = false;
    switch (_selectedEventType) {
      case ScanEventType.pickup:
        isCurrentTabComplete = activeStudents.where((s) => _isMorningPickupPhase(s)).isEmpty;
        break;
      case ScanEventType.schoolArrival:
        final boarded = activeStudents.where((s) => !_isMorningPickupPhase(s)).toList();
        isCurrentTabComplete = boarded.isNotEmpty && boarded.where((s) => _isMorningInTransit(s)).isEmpty;
        break;
      case ScanEventType.schoolDeparture:
        isCurrentTabComplete = activeStudents.where((s) => _isAtSchoolPhase(s)).isEmpty;
        break;
      case ScanEventType.homeDrop:
        final departed = activeStudents.where((s) => _isAfternoonInTransit(s) || _isDroppedHomePhase(s)).toList();
        isCurrentTabComplete = departed.isNotEmpty && departed.where((s) => _isAfternoonInTransit(s)).isEmpty;
        break;
    }

    if (isCurrentTabComplete) {
      ScanEventType? nextType;
      if (_selectedEventType == ScanEventType.pickup) {
        nextType = ScanEventType.schoolArrival;
      } else if (_selectedEventType == ScanEventType.schoolArrival) {
        nextType = ScanEventType.schoolDeparture;
      } else if (_selectedEventType == ScanEventType.schoolDeparture) {
        nextType = ScanEventType.homeDrop;
      }

      if (nextType != null) {
        setState(() {
          _selectedEventType = nextType!;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('All students completed! Shifting to ${_getEventLabel(nextType)}'),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  List<StudentModel> _getFilteredStudentsForTab(List<StudentModel> students, ScanEventType tabType) {
    final activeStudents = students.where((s) => s.status != StudentStatus.absent).toList();

    switch (tabType) {
      case ScanEventType.pickup:
        return activeStudents.where((s) => _isMorningPickupPhase(s)).toList();
      case ScanEventType.schoolArrival:
        return activeStudents.where((s) => _isMorningInTransit(s)).toList();
      case ScanEventType.schoolDeparture:
        return activeStudents.where((s) => _isAtSchoolPhase(s)).toList();
      case ScanEventType.homeDrop:
        return activeStudents.where((s) => _isAfternoonInTransit(s)).toList();
    }
  }

  Widget _buildScannerStudentTile(BuildContext context, StudentModel student) {
    final statusColor = _getStudentColorForEvent(student, _selectedEventType);
    final statusLabel = _getStudentStatusLabelForEvent(student, _selectedEventType);
    
    IconData statusIcon = Icons.hourglass_empty_rounded;
    if (statusColor == AppTheme.success) {
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (statusColor == AppTheme.error) {
      statusIcon = Icons.cancel_rounded;
    } else if (statusColor == AppTheme.textMuted) {
      statusIcon = Icons.remove_circle_outline_rounded;
    }

    final actionText = (_selectedEventType == ScanEventType.pickup || _selectedEventType == ScanEventType.schoolDeparture)
        ? 'Board'
        : 'Drop';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: statusColor,
              ),
              Expanded(
                child: ListTile(
                  onTap: () async {
                    if (_useManualEntry) {
                      if (!_isProcessing) {
                        final color = _getStudentColorForEvent(student, _selectedEventType);
                        if (color == AppTheme.warning) {
                          await _processQrCode('${student.id}|${student.name}');
                        }
                      }
                    } else {
                      _showScannerStudentDetailsDialog(context, student);
                    }
                  },
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.12),
                    radius: 18,
                    child: Icon(statusIcon, color: statusColor, size: 16),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          student.name,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (student.isStudentReady) ...[
                        const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.success),
                        const SizedBox(width: 6),
                      ],
                      if (student.status == StudentStatus.absent) ...[
                        const Icon(Icons.cancel_rounded, size: 16, color: AppTheme.error),
                        const SizedBox(width: 6),
                      ],
                      if (student.hasCustomTimings) ...[
                        const Icon(Icons.alarm_rounded, size: 14, color: AppTheme.accentLight),
                        const SizedBox(width: 4),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${student.schoolName} • Class ${student.className}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                  trailing: _useManualEntry && statusColor == AppTheme.warning
                      ? ElevatedButton(
                          onPressed: _isProcessing
                              ? null
                              : () async {
                                  await _processQrCode('${student.id}|${student.name}');
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            actionText,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScannerStudentDetailsDialog(BuildContext context, StudentModel student) {
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

        // Determine manual action button label based on currently selected event type
        String manualBtnLabel = '';
        switch (_selectedEventType) {
          case ScanEventType.pickup:
            manualBtnLabel = 'Manually Board Bus (Pickup)';
            break;
          case ScanEventType.schoolArrival:
            manualBtnLabel = 'Manually Drop at School';
            break;
          case ScanEventType.schoolDeparture:
            manualBtnLabel = 'Manually Board for Return';
            break;
          case ScanEventType.homeDrop:
            manualBtnLabel = 'Manually Drop at Home';
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

                // Custom Timings Row
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

                // Stop Details
                const Text(
                  'Stops',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildModalDetailRow(Icons.location_on_rounded, 'Pickup', student.pickupPoint.isNotEmpty ? student.pickupPoint : 'Not set'),
                _buildModalDetailRow(Icons.location_searching_rounded, 'Drop', student.dropPoint.isNotEmpty ? student.dropPoint : 'Not set'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _processQrCode('${student.id}|${student.name}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(manualBtnLabel, style: const TextStyle(color: Colors.white, fontSize: 12)),
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

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);

    // Filter list for simulation manual options
    final students = attendance.myStudents;
    final filteredStudents = _getFilteredStudentsForTab(students, _selectedEventType);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text(
          'Transit Pick/Drop',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event Type Selection Segment Row
              const Text(
                'Select Active Event Type',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              _buildEventTypeSelector(students),
              const SizedBox(height: 16),

              // Route Students Header
              const Text(
                'Route Students (Tap name for details & manual log)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),

              // Route Students List (Just after the 4 cards)
              Expanded(
                child: filteredStudents.isEmpty
                    ? const Center(child: Text('No students pending action in this stage', style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.separated(
                        itemCount: filteredStudents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          return _buildScannerStudentTile(context, student);
                        },
                      ),
              ),
              const SizedBox(height: 16),

              // Bottom Section: Mode Toggle + Panels + Summary
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // QR vs Manual Mode Toggle Switch
                  _buildToggleSwitch(),
                  const SizedBox(height: 12),

                  // Camera Frame, Simulation Panel, or Manual Entry Panel
                  _useManualEntry
                      ? _buildManualEntryPanel()
                      : (_showScanner
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 200,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Container(
                                      color: AppTheme.surfaceColor,
                                      child: kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS
                                          ? _buildSimulationPanel(filteredStudents)
                                          : _buildScannerCamera(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _showScanner = false;
                                      });
                                    },
                                    icon: const Icon(Icons.videocam_off_rounded, size: 16, color: AppTheme.error),
                                    label: const Text('Hide Scanner', style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryLight, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Camera Scanner is Hidden',
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _showScanner = true;
                                      });
                                    },
                                    icon: const Icon(Icons.videocam_rounded, size: 14),
                                    label: const Text('Show Scanner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                  const SizedBox(height: 12),

                  // Bottom Scan Summary
                  _buildScanSummaryCard(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS: EVENT SELECTOR ---
  Widget _buildEventTypeSelector(List<StudentModel> students) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ScanEventType.values.map((type) {
          final isSelected = _selectedEventType == type;
          final ratioStr = _getEventRatioString(students, type);
          
          String title = 'Pickup';
          if (type == ScanEventType.schoolArrival) title = 'Arrival';
          if (type == ScanEventType.schoolDeparture) title = 'Depart';
          if (type == ScanEventType.homeDrop) title = 'Drop';

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedEventType = type;
              });
            },
            child: Container(
              width: 90,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppTheme.primaryColor.withOpacity(0.85) 
                    : AppTheme.cardColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.accentLight.withOpacity(0.6) : Colors.white.withOpacity(0.06),
                  width: 1.5,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ] : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getEventIcon(type),
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ratioStr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white70 : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- WIDGETS: SCANNER SCREEN ---
  Widget _buildScannerCamera(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _processQrCode(barcode.rawValue!);
                break;
              }
            }
          },
        ),
        // Custom square scan box overlay
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: _isProcessing ? AppTheme.warning : AppTheme.accentLight,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: _isProcessing
                ? const Center(child: CircularProgressIndicator(color: AppTheme.warning))
                : Stack(
                    children: [
                      // Scanner overlay decoration lines
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 220,
                          height: 2,
                          color: AppTheme.accentLight.withOpacity(0.5),
                        ),
                      )
                    ],
                  ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Align student QR pass inside the frame',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        )
      ],
    );
  }

  // --- WIDGETS: SIMULATION DIRECTORY ---
  Widget _buildSimulationPanel(List<StudentModel> students) {
    String? selectedStudentId = students.isNotEmpty ? students.first.id : null;

    return StatefulBuilder(
      builder: (context, setSimState) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.videocam_off_rounded, size: 64, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              const Text(
                'Camera Feed Simulator',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              const Text(
                'Since camera permissions are not supported natively in this build environment, choose a student below to simulate QR pass scan:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              if (students.isEmpty)
                const Center(child: Text('No students registered on route', style: TextStyle(color: AppTheme.textSecondary)))
              else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: AppTheme.surfaceColor,
                      value: selectedStudentId,
                      onChanged: (val) {
                        setSimState(() {
                          selectedStudentId = val;
                        });
                      },
                      items: students.map((student) {
                        return DropdownMenuItem<String>(
                          value: student.id,
                          child: Text(
                            '${student.name} (${student.className})',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (selectedStudentId != null) {
                            final match = students.firstWhere((s) => s.id == selectedStudentId);
                            await _processQrCode('${match.id}|${match.name}');
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                  label: Text(_isProcessing ? 'Processing...' : 'Simulate Scan Event'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                )
              ],
            ],
          ),
        );
      },
    );
  }

  // --- WIDGETS: BOTTOM SUMMARY ---
  Widget _buildScanSummaryCard() {
    if (_lastScannedStudent == null) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: AppTheme.textMuted),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No scan logged yet',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                  ),
                  Text(
                    'Select mode and scan a pass to begin',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final student = _lastScannedStudent!;
    final type = _lastScannedType!;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.success.withOpacity(0.12),
            child: const Icon(Icons.check_rounded, color: AppTheme.success),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Event: ${_getEventLabel(type)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.accentLight, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Time: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'SUCCESS',
              style: TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _useManualEntry = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_useManualEntry ? AppTheme.primaryColor.withOpacity(0.85) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 16,
                      color: !_useManualEntry ? Colors.white : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'QR Scanner Mode',
                      style: TextStyle(
                         fontSize: 12,
                         fontWeight: FontWeight.bold,
                         color: !_useManualEntry ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _useManualEntry = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _useManualEntry ? AppTheme.primaryColor.withOpacity(0.85) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.keyboard_rounded,
                      size: 16,
                      color: _useManualEntry ? Colors.white : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Manual Mode',
                      style: TextStyle(
                         fontSize: 12,
                         fontWeight: FontWeight.bold,
                         color: _useManualEntry ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntryPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard_rounded, color: AppTheme.primaryLight, size: 24),
              SizedBox(width: 8),
              Text(
                'Manual Student Entry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Enter the student ID or scan code manually to log the event:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualEntryController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. mock-student-1',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppTheme.cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryLight, width: 1),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () async {
                        final text = _manualEntryController.text.trim();
                        if (text.isNotEmpty) {
                          _manualEntryController.clear();
                          FocusScope.of(context).unfocus();
                          await _processQrCode(text);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a student ID'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
