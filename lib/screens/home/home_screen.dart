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
import '../../widgets/glass_card.dart';
import '../../widgets/interactive_google_map.dart';
import '../../providers/chat_provider.dart';
import 'dart:async';
import '../student_management/student_management_screen.dart';
import '../chat/chat_list_screen.dart';
import '../student_management/qr_scanner_screen.dart';
import '../settings/driver_settings_screen.dart';
import '../notification/ai_notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        final attendance = Provider.of<AttendanceProvider>(context, listen: false);
        if (user.role == UserRole.parent) {
          attendance.fetchMyStudents(user.id, parentPhone: user.phone);
        } else {
          attendance.fetchMyStudents('mock-parent-uid-123', parentPhone: '');
        }
        Provider.of<ChatProvider>(context, listen: false).fetchConversations(user.id, user.role);

        if (user.role == UserRole.driver || user.role == UserRole.assistant) {
          Provider.of<LocationProvider>(context, listen: false).startTrackingTrip('mock-ride-1');
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

  void _onNavTapped(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
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
      appBar: _currentNavIndex == 0 ? _buildHomeAppBar(user, appState) : null,
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildHomeContent(user),
          const StudentManagementScreen(),
          const QrScannerScreen(),
          const ChatListScreen(),
          user.role == UserRole.driver
              ? const DriverSettingsScreen()
              : const AiNotificationScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(user),
      floatingActionButton: _currentNavIndex == 0 && user.role == UserRole.parent
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, AppConstants.routeChatbot),
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.support_agent_rounded, color: Colors.white),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildHomeAppBar(UserModel user, AppStateProvider appState) {
    return AppBar(
      backgroundColor: AppTheme.surfaceColor,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset('assets/images/logo.png', width: 28, height: 28, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Text(AppConstants.appName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: (appState.isFirebaseInitialized ? AppTheme.success : AppTheme.warning).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: appState.isFirebaseInitialized ? AppTheme.success : AppTheme.warning, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(appState.isFirebaseInitialized ? Icons.cloud_done : Icons.cloud_off, size: 14,
                  color: appState.isFirebaseInitialized ? AppTheme.success : AppTheme.warning),
              const SizedBox(width: 4),
              Text(appState.isFirebaseInitialized ? 'Firebase' : 'Demo Mode',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                      color: appState.isFirebaseInitialized ? AppTheme.success : AppTheme.warning)),
            ],
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.textSecondary),
              onPressed: () => setState(() => _currentNavIndex = 3),
              tooltip: 'Messages',
            ),
            Positioned(right: 6, top: 6, child: TotalUnreadBadge(currentUserId: user.id)),
          ],
        ),
        PopupMenuButton<int>(
          icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
          offset: const Offset(0, 40),
          color: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withOpacity(0.08))),
          onSelected: (value) {
            if (value == 0) _handleLogout();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 0,
              child: Row(children: [Icon(Icons.logout_rounded, size: 18, color: AppTheme.error), SizedBox(width: 10), Text('Sign Out', style: TextStyle(color: AppTheme.error))]),
            ),
          ],
        ),
      ],
    );
  }

  // ─── HOME PAGE (no duplication of nav items) ────────────────────

  Widget _buildHomeContent(UserModel user) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final locationProv = Provider.of<LocationProvider>(context);
    final isSharing = locationProv.isSharingLocation;

    final atHome = attendance.myStudents.where((s) => s.status == StudentStatus.home).length;
    final inTransit = attendance.myStudents.where((s) => s.status == StudentStatus.inTransit).length;
    final atSchool = attendance.myStudents.where((s) => s.status == StudentStatus.atSchool).length;
    final driverPickups = attendance.myStudents.where((s) => s.status != StudentStatus.absent).length;
    final driverPending = attendance.myStudents.where((s) => s.status == StudentStatus.home).length;
    final driverParents = attendance.myStudents.map((s) => s.parentUid).toSet().length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWelcomeHeader(user),
            const SizedBox(height: 16),

            // Same standard layout for all roles: Stats → Status Card → Map
            if (user.role == UserRole.parent) ...[
              _buildStatsRow([
                _StatItem('Children', '${attendance.myStudents.length}', Icons.people_alt_rounded, AppTheme.primaryLight),
                _StatItem('Home', '$atHome', Icons.home_rounded, AppTheme.success),
                _StatItem('Transit', '$inTransit', Icons.directions_bus_rounded, AppTheme.warning),
                _StatItem('School', '$atSchool', Icons.school_rounded, AppTheme.primaryLight),
              ]),
              const SizedBox(height: 12),
              _childrenOverviewCard(context),
            ] else if (user.role == UserRole.driver) ...[
              _buildStatsRow([
                _StatItem('Students', '${attendance.myStudents.length}', Icons.people_alt_rounded, AppTheme.primaryLight),
                _StatItem('Pickups', '$driverPickups', Icons.airport_shuttle_rounded, AppTheme.accentLight),
                _StatItem('Pending', '$driverPending', Icons.pending_actions_rounded, AppTheme.warning),
                _StatItem('Parents', '$driverParents', Icons.family_restroom_rounded, AppTheme.info),
              ]),
              const SizedBox(height: 12),
              _routeConsoleCard(locationProv, isSharing),
            ] else ...[
              _buildStatsRow([
                _StatItem('Total', '${attendance.myStudents.length}', Icons.people_alt_rounded, AppTheme.primaryLight),
                _StatItem('Boarded', '$inTransit', Icons.directions_bus_rounded, AppTheme.success),
                _StatItem('School', '$atSchool', Icons.school_rounded, AppTheme.primaryLight),
                _StatItem('Home', '$atHome', Icons.home_rounded, AppTheme.warning),
              ]),
            ],

            const SizedBox(height: 12),
            SizedBox(height: 260, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: _buildTrackingMap(context))),
          ],
        ),
      ),
    );
  }

  // ─── WELCOME ────────────────────────────────────────────────────

  Widget _buildWelcomeHeader(UserModel user) {
    String subtitle = 'Parent Profile';
    if (user.role == UserRole.driver) subtitle = 'Van Driver Profile';
    if (user.role == UserRole.assistant) subtitle = 'Transit Assistant Profile';

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
            child: Text(user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryLight)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name.isNotEmpty ? 'Hello, ${user.name}' : 'Welcome to SafeKid',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text('$subtitle • ${user.phone}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<_StatItem> items) {
    return Row(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _miniStatCard(item.label, item.value, item.icon, item.color),
      )).toList(),
    );
  }

  // ─── DRIVER WIDGETS ─────────────────────────────────────────────

  Widget _routeConsoleCard(LocationProvider locationProv, bool isSharing) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isSharing ? AppTheme.success : AppTheme.textMuted).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(isSharing ? Icons.location_on_rounded : Icons.location_off_rounded,
                color: isSharing ? AppTheme.success : AppTheme.textMuted, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(locationProv.currentTrip?.routeName ?? 'Greenwood Route 4B (Standard)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(isSharing ? 'Live GPS sharing active' : 'GPS inactive',
                    style: TextStyle(fontSize: 11, color: isSharing ? AppTheme.success : AppTheme.textSecondary)),
              ],
            ),
          ),
          if (isSharing)
            Container(width: 8, height: 8,
                decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppTheme.success, blurRadius: 6, spreadRadius: 1)])),
        ],
      ),
    );
  }

  // ─── PARENT CHILDREN OVERVIEW CARD ──────────────────────────────

  Widget _childrenOverviewCard(BuildContext context) {
    final attendance = Provider.of<AttendanceProvider>(context);
    final children = attendance.myStudents;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.child_care_rounded,
                color: AppTheme.primaryLight, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  children.isEmpty ? 'No children registered' : '${children.length} child${children.length == 1 ? '' : 'ren'} registered',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  children.isEmpty
                      ? 'Link with your driver to get started'
                      : '${children.where((s) => s.status == StudentStatus.home).length} at home · '
                          '${children.where((s) => s.status == StudentStatus.inTransit).length} in transit · '
                          '${children.where((s) => s.status == StudentStatus.atSchool).length} at school',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (children.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: children.any((s) => s.status == StudentStatus.inTransit)
                    ? AppTheme.warning.withOpacity(0.15) : AppTheme.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                children.any((s) => s.status == StudentStatus.inTransit) ? 'EN ROUTE' : 'ALL SAFE',
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.bold,
                  color: children.any((s) => s.status == StudentStatus.inTransit) ? AppTheme.warning : AppTheme.success,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── SHARED UTILITY WIDGETS ─────────────────────────────────────

  Widget _miniStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ]),
    );
  }

  Widget _buildTrackingMap(BuildContext context) {
    return Consumer2<LocationProvider, AttendanceProvider>(
      builder: (context, locationProv, attendanceProv, _) {
        final trip = locationProv.currentTrip;
        final isSharing = locationProv.isSharingLocation;
        final student = attendanceProv.myStudents.isNotEmpty ? attendanceProv.myStudents.first : null;

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

  // ─── BOTTOM NAV ─────────────────────────────────────────────────

  Widget _buildBottomNav(UserModel user) {
    final isDriver = user.role == UserRole.driver;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavTapped,
        backgroundColor: AppTheme.surfaceColor,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryLight,
        unselectedItemColor: AppTheme.textMuted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), activeIcon: Icon(Icons.people_alt_rounded), label: 'Students'),
          BottomNavigationBarItem(
            icon: Icon(isDriver ? Icons.route_outlined : Icons.qr_code_scanner_outlined),
            activeIcon: Icon(isDriver ? Icons.route_rounded : Icons.qr_code_scanner_rounded),
            label: isDriver ? 'Pick/Drop' : 'Pick/Drop',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), activeIcon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
          BottomNavigationBarItem(
            icon: Icon(isDriver ? Icons.settings_outlined : Icons.notifications_outlined),
            activeIcon: Icon(isDriver ? Icons.settings_rounded : Icons.notifications_rounded),
            label: isDriver ? 'Settings' : 'Alerts',
          ),
        ],
      ),
    );
  }

}

// ─── UNREAD BADGE ─────────────────────────────────────────────────

class TotalUnreadBadge extends StatelessWidget {
  final String currentUserId;
  const TotalUnreadBadge({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    if (chatProvider.conversations.isEmpty) return const SizedBox.shrink();
    if (chatProvider.conversations.length == 1) {
      return StreamBuilder<int>(
        stream: chatProvider.watchUnreadCount(currentUserId, chatProvider.conversations.first.id),
        builder: (context, snapshot) {
          final count = snapshot.data ?? 0;
          if (count == 0) return const SizedBox.shrink();
          return _buildBadge(count);
        },
      );
    }
    return _MultiUnreadBadge(currentUserId: currentUserId, partners: chatProvider.conversations);
  }

  Widget _buildBadge(int count) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
      ),
    );
  }
}

class _MultiUnreadBadge extends StatefulWidget {
  final String currentUserId;
  final List<UserModel> partners;
  const _MultiUnreadBadge({required this.currentUserId, required this.partners});

  @override
  State<_MultiUnreadBadge> createState() => _MultiUnreadBadgeState();
}

class _MultiUnreadBadgeState extends State<_MultiUnreadBadge> {
  final Map<String, int> _unreadCounts = {};
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() { super.initState(); _subscribe(); }

  @override
  void didUpdateWidget(covariant _MultiUnreadBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.partners != widget.partners || oldWidget.currentUserId != widget.currentUserId) {
      _unsubscribe(); _subscribe();
    }
  }

  @override
  void dispose() { _unsubscribe(); super.dispose(); }

  void _unsubscribe() {
    for (final sub in _subscriptions) { sub.cancel(); }
    _subscriptions.clear(); _unreadCounts.clear();
  }

  void _subscribe() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    for (final partner in widget.partners) {
      final sub = chatProvider.watchUnreadCount(widget.currentUserId, partner.id).listen((count) {
        if (mounted) setState(() { _unreadCounts[partner.id] = count; });
      });
      _subscriptions.add(sub);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _unreadCounts.values.fold(0, (sum, count) => sum + count);
    if (total == 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        child: Text('$total', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}
