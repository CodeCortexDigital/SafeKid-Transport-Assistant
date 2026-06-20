import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/user_model.dart';
import '../../models/student_model.dart';
import '../../models/ride_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/responsive_layout.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        // Load student data linked to user
        final attendance = Provider.of<AttendanceProvider>(context, listen: false);
        attendance.fetchMyStudents(user.uid);
      }
    });
  }

  void _handleLogout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppConstants.routeLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final appState = Provider.of<AppStateProvider>(context);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/logo.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppConstants.appName,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ],
        ),
        actions: [
          // Database Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: appState.isFirebaseInitialized
                  ? AppTheme.success.withOpacity(0.1)
                  : AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: appState.isFirebaseInitialized ? AppTheme.success : AppTheme.warning,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  appState.isFirebaseInitialized ? Icons.cloud_done : Icons.cloud_off,
                  size: 14,
                  color: appState.isFirebaseInitialized ? AppTheme.success : AppTheme.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  appState.isFirebaseInitialized ? 'Firebase' : 'Demo Mode',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: appState.isFirebaseInitialized ? AppTheme.success : AppTheme.warning,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
            onPressed: _handleLogout,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveLayout(
          mobile: _buildMobileDashboard(context, user),
          tablet: _buildTabletDashboard(context, user),
        ),
      ),
    );
  }

  // --- MOBILE LAYOUT ---
  Widget _buildMobileDashboard(BuildContext context, UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWelcomeHeader(user),
          const SizedBox(height: 20),
          if (user.role == UserRole.parent) ...[
            _buildParentDashboard(context),
          ] else ...[
            _buildDriverDashboard(context),
          ],
        ],
      ),
    );
  }

  // --- TABLET/DESKTOP GRID LAYOUT ---
  Widget _buildTabletDashboard(BuildContext context, UserModel user) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Controls & Lists)
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWelcomeHeader(user),
                const SizedBox(height: 24),
                if (user.role == UserRole.parent) ...[
                  _buildChildrenListSection(context),
                ] else ...[
                  _buildDriverControlSection(context),
                ],
              ],
            ),
          ),
        ),
        // Vertical Divider
        VerticalDivider(color: Colors.white.withOpacity(0.08), width: 1),
        // Right Column (Map / Tracking Console)
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Live Transit Map Tracker',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildTrackingMap(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- WELCOME CARD ---
  Widget _buildWelcomeHeader(UserModel user) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
            child: Text(
              user.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${user.name}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  user.role == UserRole.parent
                      ? 'Parent Profile • Greenwood District'
                      : 'Bus Driver Profile • Greenwood School Bus 4B',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PARENT VIEWS ---
  Widget _buildParentDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildChildrenListSection(context),
        const SizedBox(height: 20),
        const Text(
          'Live Tracking Tracker',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildTrackingMap(context),
          ),
        ),
      ],
    );
  }

  Widget _buildChildrenListSection(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);

    if (attendance.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    if (attendance.myStudents.isEmpty) {
      return const GlassCard(
        child: Center(child: Text('No registered children associated with this profile.')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Children',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.primaryLight, size: 20),
              onPressed: () {
                final uid = Provider.of<AuthProvider>(context, listen: false).user?.uid;
                if (uid != null) attendance.fetchMyStudents(uid);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: attendance.myStudents.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final student = attendance.myStudents[index];
            return _buildStudentCard(context, student);
          },
        ),
      ],
    );
  }

  Widget _buildStudentCard(BuildContext context, StudentModel student) {
    final locationProv = Provider.of<LocationProvider>(context);

    // Color and Icon based on student safety status
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (student.status) {
      case StudentStatus.home:
        statusColor = AppTheme.success;
        statusIcon = Icons.home_outlined;
        statusText = 'At Home';
        break;
      case StudentStatus.inTransit:
        statusColor = AppTheme.warning;
        statusIcon = Icons.directions_bus_outlined;
        statusText = 'In Transit';
        break;
      case StudentStatus.atSchool:
        statusColor = AppTheme.primaryLight;
        statusIcon = Icons.school_outlined;
        statusText = 'At School';
        break;
      case StudentStatus.absent:
        statusColor = AppTheme.error;
        statusIcon = Icons.cancel_outlined;
        statusText = 'Absent';
        break;
    }

    return Card(
      color: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(statusIcon, color: statusColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      Text(
                        '${student.className} • Section ${student.section}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // QR Button
                TextButton.icon(
                  onPressed: () => _showQrDialog(context, student),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Show QR', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.accentLight),
                ),
                const SizedBox(width: 8),
                // Live track button
                ElevatedButton.icon(
                  onPressed: student.status == StudentStatus.inTransit
                      ? () {
                          // Start listening to the mock ride route
                          locationProv.startTrackingRide('mock-ride-1');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Connected to live school bus tracking stream.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.location_searching_rounded, size: 16),
                  label: const Text('Track Bus', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white.withOpacity(0.04),
                    disabledForegroundColor: Colors.white.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- DRIVER VIEWS ---
  Widget _buildDriverDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDriverControlSection(context),
        const SizedBox(height: 20),
        const Text(
          'Active Route GPS',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildTrackingMap(context),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverControlSection(BuildContext context) {
    final locationProv = Provider.of<LocationProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Route Console',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 10),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Greenwood Route 4B',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      Text(
                        locationProv.isSharingLocation ? 'Sharing GPS location live' : 'Offline • GPS inactive',
                        style: TextStyle(
                          fontSize: 12,
                          color: locationProv.isSharingLocation ? AppTheme.success : AppTheme.textSecondary,
                        ),
                      )
                    ],
                  ),
                  Icon(
                    Icons.directions_bus,
                    color: locationProv.isSharingLocation ? AppTheme.success : AppTheme.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: locationProv.isSharingLocation ? 'Stop Sharing GPS' : 'Start Sharing GPS Location',
                isSecondary: locationProv.isSharingLocation,
                onPressed: () {
                  if (locationProv.isSharingLocation) {
                    locationProv.stopSharing();
                  } else {
                    locationProv.startSharing('mock-ride-1');
                  }
                },
              ),
              const SizedBox(height: 12),
              // Scanner button
              OutlinedButton.icon(
                onPressed: () => _openScanner(context),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan Student QR Code'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- QR GENERATION POPUP ---
  void _showQrDialog(BuildContext context, StudentModel student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(
            '${student.name}\'s Safety Badge',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: student.qrCodeData,
                  version: QrVersions.auto,
                  size: 200.0,
                  gapless: false,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                student.qrCodeData,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Let the school bus driver or gate administrator scan this QR code for check-in/out updates.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppTheme.primaryLight)),
            )
          ],
        );
      },
    );
  }

  // --- QR SCANNING SHEET ---
  void _openScanner(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Scan Student Safety Code',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: _buildScannerCamera(context),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildScannerCamera(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context, listen: false);
    bool hasScanned = false; // Prevent multiple triggers in milliseconds

    // Because mobile scanner might not initialize on desktop/simulators, we offer an interactive manual fallback
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS) {
      return Container(
        color: AppTheme.surfaceColor,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_outlined, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Camera Scanner Unavailable',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const Text(
              'Scanner hardware is only active on Android/iOS/Web. Choose a mock student to trigger check status manually:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await attendance.scanQrCode('STUDENT_EMMA_DOE_123', StudentStatus.atSchool);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(attendance.successMessage ?? 'Success')),
                        );
                      }
                    },
                    child: const Text('Check-In Emma (School)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await attendance.scanQrCode('STUDENT_EMMA_DOE_123', StudentStatus.home);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(attendance.successMessage ?? 'Success')),
                        );
                      }
                    },
                    child: const Text('Check-Out Emma (Home)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await attendance.scanQrCode('STUDENT_LIAM_DOE_456', StudentStatus.inTransit);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(attendance.successMessage ?? 'Success')),
                        );
                      }
                    },
                    child: const Text('Check Liam in Transit'),
                  ),
                ),
              ],
            )
          ],
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) async {
            if (hasScanned) return;
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                hasScanned = true;
                final success = await attendance.scanQrCode(
                  barcode.rawValue!, 
                  StudentStatus.inTransit // Default status when scan happens on the bus
                );
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? (attendance.successMessage ?? 'Logged') : (attendance.errorMessage ?? 'Error')),
                      backgroundColor: success ? AppTheme.success : AppTheme.error,
                    ),
                  );
                }
                break;
              }
            }
          },
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accentLight, width: 2.5),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Text(
            'Align student QR code inside the box.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
          ),
        )
      ],
    );
  }

  // --- MAP VIEW ---
  Widget _buildTrackingMap(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProv, _) {
        final ride = locationProv.currentRide;
        final isSharing = locationProv.isSharingLocation;

        // Custom High-fidelity Schematic Map Simulator for non-mobile or demo environments
        return Container(
          color: AppTheme.backgroundColor,
          child: CustomPaint(
            painter: MapSchemaPainter(
              schoolLat: AppConstants.defaultSchoolLatitude,
              schoolLng: AppConstants.defaultSchoolLongitude,
              homeLat: AppConstants.defaultHomeLatitude,
              homeLng: AppConstants.defaultHomeLongitude,
              busLat: ride?.currentLatitude ?? (isSharing ? AppConstants.defaultSchoolLatitude : null),
              busLng: ride?.currentLongitude ?? (isSharing ? AppConstants.defaultSchoolLongitude : null),
              busEta: ride?.etaMinutes ?? '--',
              rideStatus: ride?.status ?? (isSharing ? RideStatus.active : RideStatus.scheduled),
            ),
          ),
        );
      },
    );
  }
}

// Visual map schema canvas painter to represent Google Maps tracking in all environments
class MapSchemaPainter extends CustomPainter {
  final double schoolLat;
  final double schoolLng;
  final double homeLat;
  final double homeLng;
  final double? busLat;
  final double? busLng;
  final String busEta;
  final RideStatus rideStatus;

  MapSchemaPainter({
    required this.schoolLat,
    required this.schoolLng,
    required this.homeLat,
    required this.homeLng,
    required this.busLat,
    required this.busLng,
    required this.busEta,
    required this.rideStatus,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.surfaceColor
      ..style = PaintingStyle.fill;
    
    // Draw background board
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(16)), paint);

    // Draw grid paths
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double j = 0; j < size.height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), gridPaint);
    }

    // Scale mapping coordinates to visual offsets
    // School is top-left, Home is bottom-right
    final Offset schoolOffset = Offset(size.width * 0.25, size.height * 0.25);
    final Offset homeOffset = Offset(size.width * 0.75, size.height * 0.75);

    // Draw connecting highway route line
    final routePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final Path path = Path();
    path.moveTo(schoolOffset.dx, schoolOffset.dy);
    // Add custom curve representing winding roads
    path.quadraticBezierTo(
      size.width * 0.35, size.height * 0.65, 
      size.width * 0.5, size.height * 0.5
    );
    path.quadraticBezierTo(
      size.width * 0.65, size.height * 0.35, 
      homeOffset.dx, homeOffset.dy
    );
    canvas.drawPath(path, routePaint);

    // Draw School Node
    final nodePaint = Paint()..style = PaintingStyle.fill;
    nodePaint.color = AppTheme.primaryColor;
    canvas.drawCircle(schoolOffset, 16, nodePaint);
    nodePaint.color = Colors.white;
    canvas.drawCircle(schoolOffset, 6, nodePaint);

    // Draw Home Node
    nodePaint.color = AppTheme.success;
    canvas.drawCircle(homeOffset, 16, nodePaint);
    nodePaint.color = Colors.white;
    canvas.drawCircle(homeOffset, 6, nodePaint);

    // Render labels
    _drawText(canvas, schoolOffset - const Offset(0, 36), 'Greenwood School', Colors.white, 12, FontWeight.bold);
    _drawText(canvas, homeOffset + const Offset(-20, 24), 'Student Safe Zone', Colors.white, 12, FontWeight.bold);

    // Draw simulated bus node if active
    if (busLat != null && busLng != null) {
      // Calculate bus position along the curve based on Lat/Lng coordinates
      // Since it's simulated linearly, interpolate:
      double t = (busLat! - schoolLat) / (homeLat - schoolLat);
      if (t < 0) t = 0;
      if (t > 1) t = 1;

      // Follow the Bezier curve calculation matching canvas path
      final double busX = _calculateBezierPosition(schoolOffset.dx, size.width * 0.35, size.width * 0.5, homeOffset.dx, t);
      final double busY = _calculateBezierPosition(schoolOffset.dy, size.height * 0.65, size.height * 0.5, homeOffset.dy, t);
      final Offset busOffset = Offset(busX, busY);

      // Pulse ring animation simulation
      final pulsePaint = Paint()
        ..color = AppTheme.warning.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(busOffset, 24, pulsePaint);

      nodePaint.color = AppTheme.warning;
      canvas.drawCircle(busOffset, 12, nodePaint);
      nodePaint.color = Colors.black;
      canvas.drawCircle(busOffset, 4, nodePaint);

      // Driver live indicator tag
      final tagRect = Rect.fromLTWH(busOffset.dx - 45, busOffset.dy - 35, 90, 18);
      nodePaint.color = AppTheme.cardColor;
      canvas.drawRRect(RRect.fromRectAndRadius(tagRect, const Radius.circular(4)), nodePaint);
      
      _drawText(
        canvas, 
        Offset(busOffset.dx - 40, busOffset.dy - 33), 
        'Transit • ETA: $busEta m', 
        AppTheme.textPrimary, 
        8, 
        FontWeight.bold
      );
    } else {
      // Draw idle state message
      _drawText(
        canvas, 
        Offset(size.width * 0.5 - 110, size.height * 0.5 - 10), 
        'TRACKER IDLE • WAITING FOR ACTIVE TRIP', 
        AppTheme.textMuted, 
        10, 
        FontWeight.bold
      );
    }
  }

  double _calculateBezierPosition(double p0, double p1, double p2, double p3, double t) {
    // Cubic bezier formula: (1-t)^3*p0 + 3*(1-t)^2*t*p1 + 3*(1-t)*t^2*p2 + t^3*p3
    final double u = 1 - t;
    return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3;
  }

  void _drawText(Canvas canvas, Offset offset, String text, Color color, double fontSize, FontWeight weight) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
