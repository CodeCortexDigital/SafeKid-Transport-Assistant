import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../widgets/glass_card.dart';

import '../../services/auth/biometric_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isBiometricsAvailable = false;
  bool _isBiometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.isBiometricAvailable();
    final enabled = await BiometricService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isBiometricsAvailable = available;
        _isBiometricsEnabled = enabled;
      });
      if (available && enabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _triggerBiometricLogin();
        });
      }
    }
  }

  Future<void> _triggerBiometricLogin() async {
    final authenticated = await BiometricService.authenticate();
    if (!authenticated) return;

    final cachedUser = await BiometricService.getCachedUser();
    if (cachedUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No cached user found. Please sign in with Google or Demo Shortcuts first.'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
      return;
    }

    if (mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      
      // Show verifying indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verifying security session...'),
          duration: Duration(seconds: 1),
        ),
      );

      final isValid = await auth.verifyCachedUser(cachedUser);
      if (!isValid) {
        if (mounted) {
          await BiometricService.clearSession();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your session has expired or has been revoked. Please sign in again.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
        return;
      }

      auth.loginWithCachedUser(cachedUser);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${cachedUser.name}!'),
          backgroundColor: AppTheme.success,
        ),
      );

      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  Future<void> _handleDemoLogin(String roleKey) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.loginAsMockUser(roleKey);
    
    if (mounted) {
      if (auth.needsRegistration) {
        Navigator.pushNamed(context, '/profile-setup');
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    Widget buildForm() {
      return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Hero(
                tag: 'app_logo',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign In',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a secure authentication method to access your console.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return ElevatedButton.icon(
                  onPressed: auth.isLoading ? null : () async {
                    final success = await auth.signInWithGoogle();
                    if (mounted) {
                      if (success) {
                        if (auth.needsRegistration) {
                          Navigator.pushNamed(context, '/profile-setup');
                        } else {
                          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(auth.errorMessage ?? 'Google sign-in failed'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.account_circle_rounded),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1F2937),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
            if (_isBiometricsAvailable && _isBiometricsEnabled) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _triggerBiometricLogin,
                icon: const Icon(Icons.fingerprint_rounded, color: AppTheme.accentLight, size: 24),
                label: const Text(
                  'Sign In with Fingerprint',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  side: BorderSide(color: AppTheme.accentLight.withOpacity(0.5), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: AppTheme.textPrimary,
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'DEMO SHORTCUTS',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: auth.isLoading ? null : () => _handleDemoLogin('parent'),
                      icon: Icon(Icons.supervisor_account_outlined, size: 16, color: AppTheme.accentLight),
                      label: const Text('Parent Demo', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: auth.isLoading ? null : () => _handleDemoLogin('driver'),
                      icon: Icon(Icons.directions_bus_outlined, size: 16, color: AppTheme.primaryLight),
                      label: const Text('Driver Demo', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: auth.isLoading ? null : () => _handleDemoLogin('assistant'),
                      icon: Icon(Icons.support_agent_rounded, size: 16, color: Colors.purpleAccent),
                      label: const Text('Assistant Demo', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: auth.isLoading ? null : () => _handleDemoLogin('new'),
                      icon: Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.orangeAccent),
                      label: const Text('New Register', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ],
                );
              }
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        color: AppTheme.backgroundColor,
        child: ResponsiveLayout(
          mobile: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: GlassCard(
                child: buildForm(),
              ),
            ),
          ),
          tablet: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: SizedBox(
                width: size.width * 0.85,
                height: 600,
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                          ),
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppConstants.appName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.lock_person_outlined,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'OTP Shield Logins',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Access your role console securely. No passwords required, authenticated via high-speed OTP messaging.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.check_circle_outline, color: Colors.white.withOpacity(0.6), size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Google Firebase Secure',
                                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: SingleChildScrollView(
                            child: buildForm(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
