import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/user_model.dart';
import '../../models/student_model.dart';
import '../../models/trip_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/responsive_layout.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_button.dart';
import 'widgets/driver_dashboard.dart';
import 'widgets/parent_dashboard.dart';
import '../../widgets/interactive_google_map.dart';

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
        final attendance = Provider.of<AttendanceProvider>(context, listen: false);
        // Load default students for parent or general boarding verification
        if (user.role == UserRole.parent) {
          attendance.fetchMyStudents(user.id);
        } else {
          // For driver/assistant: load mock route boarding students
          attendance.fetchMyStudents('mock-parent-uid-123');
        }
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
          ] else if (user.role == UserRole.driver) ...[
            _buildDriverDashboard(context),
          ] else ...[
            _buildAssistantDashboard(context),
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
                  const ParentDashboard(),
                ] else if (user.role == UserRole.driver) ...[
                  const DriverDashboard(),
                ] else ...[
                  _buildAssistantControlSection(context),
                ],
              ],
            ),
          ),
        ),
        VerticalDivider(color: Colors.white.withOpacity(0.08), width: 1),
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

  Widget _buildWelcomeHeader(UserModel user) {
    String subtitle = 'Parent Profile';
    if (user.role == UserRole.driver) subtitle = 'Bus Driver Profile';
    if (user.role == UserRole.assistant) subtitle = 'Transit Assistant Profile';

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
            child: Text(
              user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isNotEmpty ? 'Hello, ${user.name}' : 'Welcome to SafeKid',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '$subtitle • ${user.phone}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PARENT VIEW ---
  Widget _buildParentDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ParentDashboard(),
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

  // --- DRIVER VIEW ---
  Widget _buildDriverDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DriverDashboard(),
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

  // --- ASSISTANT VIEW ---
  Widget _buildAssistantDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAssistantControlSection(context),
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




  // --- ASSISTANT CONTROLS ---
  Widget _buildAssistantControlSection(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Assistant Console',
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
                        'Boarding Assistance',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const Text(
                        'Role: Transit Staff',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      )
                    ],
                  ),
                  const Icon(
                    Icons.assignment_ind_outlined,
                    color: AppTheme.accentLight,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Scan Boarding QR Code',
                icon: Icons.qr_code_scanner_rounded,
                onPressed: () => Navigator.pushNamed(context, AppConstants.routeQrScanner),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('Boarded', '${attendance.myStudents.where((s) => s.status == StudentStatus.inTransit).length}'),
                  _buildStatItem('At School', '${attendance.myStudents.where((s) => s.status == StudentStatus.atSchool).length}'),
                  _buildStatItem('At Home', '${attendance.myStudents.where((s) => s.status == StudentStatus.home).length}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }




  // --- MAP VIEW ---
  Widget _buildTrackingMap(BuildContext context) {
    return Consumer2<LocationProvider, AttendanceProvider>(
      builder: (context, locationProv, attendanceProv, _) {
        final trip = locationProv.currentTrip;
        final isSharing = locationProv.isSharingLocation;
        
        final student = attendanceProv.myStudents.isNotEmpty 
            ? attendanceProv.myStudents.first 
            : null;

        return InteractiveGoogleMap(
          currentLatitude: trip?.currentLatitude ?? (isSharing ? AppConstants.defaultSchoolLatitude : 0.0),
          currentLongitude: trip?.currentLongitude ?? (isSharing ? AppConstants.defaultSchoolLongitude : 0.0),
          tripStatus: trip?.status ?? (isSharing ? TripStatus.active : TripStatus.scheduled),
          etaMinutes: trip?.etaMinutes ?? '--',
          pickupLatitude: student?.pickupLatitude,
          pickupLongitude: student?.pickupLongitude,
          schoolLatitude: AppConstants.defaultSchoolLatitude,
          schoolLongitude: AppConstants.defaultSchoolLongitude,
          childName: student?.name ?? 'Child',
        );
      },
    );
  }
}
