import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_state_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/attendance_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/student_management/student_management_screen.dart';
import 'screens/student_management/qr_card_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStateProvider(),
      child: const SafeKidApp(),
    ),
  );
}

class SafeKidApp extends StatelessWidget {
  const SafeKidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        if (appState.isLoading) {
          return MaterialApp(
            title: AppConstants.appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            ),
          );
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(appState.authRepository),
            ),
            ChangeNotifierProvider<LocationProvider>(
              create: (_) => LocationProvider(appState.tripRepository),
            ),
            ChangeNotifierProvider<AttendanceProvider>(
              create: (_) => AttendanceProvider(appState.studentRepository),
            ),
          ],
          child: MaterialApp(
            title: AppConstants.appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            initialRoute: AppConstants.routeSplash,
            routes: {
              AppConstants.routeSplash: (context) => const SplashScreen(),
              AppConstants.routeLogin: (context) => const LoginScreen(),
              AppConstants.routeHome: (context) => const HomeScreen(),
              AppConstants.routeStudentManagement: (context) => const StudentManagementScreen(),
              AppConstants.routeQrCard: (context) => const QrCardScreen(),
              '/otp': (context) => const OtpScreen(),
              '/profile-setup': (context) => const ProfileSetupScreen(),
            },
          ),
        );
      },
    );
  }
}
