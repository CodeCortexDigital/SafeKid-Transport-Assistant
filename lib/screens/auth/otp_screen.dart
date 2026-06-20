import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/glass_card.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    if (_formKey.currentState!.validate()) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.verifyOtp(_otpController.text.trim());

      if (mounted) {
        if (success) {
          if (auth.needsRegistration) {
            // Redirect to Profile Setup
            Navigator.pushNamedAndRemoveUntil(context, '/profile-setup', (route) => false);
          } else {
            // Redirect to Home Dashboard immediately
            Navigator.pushNamedAndRemoveUntil(context, AppConstants.routeHome, (route) => false);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.errorMessage ?? 'OTP verification failed'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: AppTheme.backgroundColor,
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: 450,
            child: GlassCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 48,
                      color: AppTheme.accentLight,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Verify Phone',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the 6-digit code sent to ${auth.phoneNumber ?? 'your number'}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    CustomTextField(
                      controller: _otpController,
                      labelText: 'Verification Code',
                      hintText: '123456',
                      prefixIcon: Icons.lock_clock_outlined,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Verification code is required';
                        if (val.length != 6) return 'Code must be exactly 6 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Verify & Sign In',
                      onPressed: _handleVerifyOtp,
                      isLoading: auth.isLoading,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Didn\'t receive the code? ',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        TextButton(
                          onPressed: auth.isLoading
                              ? null
                              : () async {
                                  if (auth.phoneNumber != null) {
                                    await auth.sendOtp(auth.phoneNumber!);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('OTP Code resent!')),
                                      );
                                    }
                                  }
                                },
                          child: const Text(
                            'Resend Code',
                            style: TextStyle(color: AppTheme.accentLight, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
