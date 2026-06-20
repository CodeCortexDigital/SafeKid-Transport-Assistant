import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/glass_card.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  UserRole _selectedRole = UserRole.parent;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    if (_formKey.currentState!.validate()) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.registerUserProfile(
        _nameController.text.trim(),
        _selectedRole,
      );

      if (mounted) {
        if (success) {
          // Redirect to Home Dashboard
          Navigator.pushNamedAndRemoveUntil(context, AppConstants.routeHome, (route) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.errorMessage ?? 'Failed to create profile'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      Icons.person_add_alt_1_rounded,
                      size: 48,
                      color: AppTheme.accentLight,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Complete Profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Provide your name and role to set up your SafeKid console.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    CustomTextField(
                      controller: _nameController,
                      labelText: 'Full Name',
                      hintText: 'John Doe',
                      prefixIcon: Icons.badge_outlined,
                      keyboardType: TextInputType.name,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Full name is required';
                        if (val.length < 3) return 'Name must be at least 3 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Role Selector Dropdown
                    DropdownButtonFormField<UserRole>(
                      initialValue: _selectedRole,
                      dropdownColor: AppTheme.surfaceColor,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'I am a...',
                        prefixIcon: Icon(Icons.people_outline_rounded, color: AppTheme.textSecondary),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: UserRole.parent,
                          child: Text('Parent / Guardian'),
                        ),
                        DropdownMenuItem(
                          value: UserRole.driver,
                          child: Text('School Bus Driver'),
                        ),
                        DropdownMenuItem(
                          value: UserRole.assistant,
                          child: Text('Transit Assistant / Staff'),
                        ),
                      ],
                      onChanged: (UserRole? val) {
                        if (val != null) {
                          setState(() {
                            _selectedRole = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        return CustomButton(
                          text: 'Create Account',
                          onPressed: _handleSaveProfile,
                          isLoading: auth.isLoading,
                        );
                      },
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
