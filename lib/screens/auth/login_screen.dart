import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_state_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (_formKey.currentState!.validate()) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final phone = _phoneController.text.trim();
      
      final success = await auth.sendOtp(phone);

      if (mounted) {
        if (success) {
          // Navigate to OTP Screen
          Navigator.pushNamed(context, '/otp');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.errorMessage ?? 'Failed to send verification code'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  void _quickFill(String phone) {
    setState(() {
      _phoneController.text = phone;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final appState = Provider.of<AppStateProvider>(context);

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
              'Enter your phone number to receive a verification OTP code.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            CustomTextField(
              controller: _phoneController,
              labelText: 'Phone Number',
              hintText: '+1 555-0199',
              prefixIcon: Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Phone number is required';
                if (!val.startsWith('+')) return 'Include country code (e.g. +1)';
                if (val.length < 9) return 'Enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 24),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return CustomButton(
                  text: 'Send Verification Code',
                  onPressed: _handleSendOtp,
                  isLoading: auth.isLoading,
                );
              },
            ),
            
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
              ],
            ),
            
            const SizedBox(height: 24),
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
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1F2937),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    disabledBackgroundColor: Colors.grey,
                  ),
                );
              },
            ),
            
            if (!appState.isFirebaseInitialized) ...[
              const SizedBox(height: 24),
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
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _quickFill('+15551111111'),
                    icon: Icon(Icons.supervisor_account_outlined, size: 16, color: AppTheme.accentLight),
                    label: const Text('Parent Demo', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _quickFill('+15552222222'),
                    icon: Icon(Icons.directions_bus_outlined, size: 16, color: AppTheme.primaryLight),
                    label: const Text('Driver Demo', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _quickFill('+15553333333'),
                    icon: Icon(Icons.support_agent_rounded, size: 16, color: Colors.purpleAccent),
                    label: const Text('Assistant Demo', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _quickFill('+15559999999'),
                    icon: Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.orangeAccent),
                    label: const Text('New Register', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
            ],
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
