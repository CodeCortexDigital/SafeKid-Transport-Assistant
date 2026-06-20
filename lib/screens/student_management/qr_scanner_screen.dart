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
  StudentModel? _lastScannedStudent;
  ScanEventType? _lastScannedType;
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void dispose() {
    _scannerController.dispose();
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
        await attendance.fetchMyStudents(user!.id);
      } else {
        await attendance.fetchMyStudents('mock-parent-uid-123');
      }

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

  @override
  Widget build(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);

    // Filter list for simulation manual options
    final students = attendance.myStudents;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text(
          'QR Transit Scanner',
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
              _buildEventTypeSelector(),
              const SizedBox(height: 20),

              // Camera Frame or Simulation Card
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: AppTheme.surfaceColor,
                    child: kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS
                        ? _buildSimulationPanel(students)
                        : _buildScannerCamera(context),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Bottom Scan Summary
              _buildScanSummaryCard(),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS: EVENT SELECTOR ---
  Widget _buildEventTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: ScanEventType.values.map((type) {
          final isSelected = _selectedEventType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedEventType = type;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getEventIcon(type),
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.name == 'schoolArrival'
                          ? 'Arrival'
                          : type.name == 'schoolDeparture'
                              ? 'Depart'
                              : type.name == 'homeDrop'
                                  ? 'Drop'
                                  : 'Pickup',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
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
}
