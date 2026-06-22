import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _keyCachedUser = 'cached_user';
  static const String _keyBiometricEnabled = 'biometric_enabled';

  /// Check if the device is capable of biometric authentication
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  /// Trigger biometric authentication
  static Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to log in to SafeKid',
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }

  /// Check if biometric login has been configured and is enabled
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// Get the cached user profile
  static Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyCachedUser);
    if (userJson == null) return null;
    try {
      final Map<String, dynamic> userMap = jsonDecode(userJson);
      return UserModel.fromJson(userMap, userMap['id'] ?? '');
    } catch (_) {
      return null;
    }
  }

  /// Save user session and enable biometric login
  static Future<void> saveSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final userMap = user.toJson();
    userMap['id'] = user.id;
    await prefs.setString(_keyCachedUser, jsonEncode(userMap));
    await prefs.setBool(_keyBiometricEnabled, true);
  }

  /// Clear the cached session (e.g. on logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCachedUser);
    await prefs.setBool(_keyBiometricEnabled, false);
  }
}
