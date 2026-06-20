import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../core/errors/failures.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  
  String? _verificationId;
  String? _phoneNumber;
  bool _needsRegistration = false;
  bool _isManualLoginInProgress = false;

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  String? get verificationId => _verificationId;
  String? get phoneNumber => _phoneNumber;
  bool get needsRegistration => _needsRegistration;

  AuthProvider(this._authRepository) {
    // Listen to changes in authentication state
    _authRepository.authStateChanges.listen((UserModel? fbUser) async {
      if (_isManualLoginInProgress) return;
      if (fbUser == null) {
        _user = null;
        _needsRegistration = false;
        notifyListeners();
      } else {
        // Authenticated. Check if profile exists in Firestore.
        _isLoading = true;
        notifyListeners();
        
        try {
          final profile = await _authRepository.getUserProfile(fbUser.id);
          if (profile != null) {
            _user = profile;
            _needsRegistration = false;
          } else {
            // Keep the basic auth user and trigger registration flow
            _user = fbUser;
            _needsRegistration = true;
          }
        } catch (e) {
          _errorMessage = e.toString();
        }
        
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  /// Initiates Phone Number OTP Verification
  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final completer = Completer<bool>();

    try {
      await _authRepository.verifyPhone(
        phone,
        onCodeSent: (verId) {
          _verificationId = verId;
          _phoneNumber = phone;
          _isLoading = false;
          notifyListeners();
          completer.complete(true);
        },
        onFailed: (err) {
          _errorMessage = err;
          _isLoading = false;
          notifyListeners();
          completer.complete(false);
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      completer.complete(false);
    }

    return completer.future;
  }

  /// Confirms OTP input and checks database registration status
  Future<bool> verifyOtp(String smsCode) async {
    if (_verificationId == null) {
      _errorMessage = 'Verification code not sent. Please try again.';
      return false;
    }

    _isLoading = true;
    _isManualLoginInProgress = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authUser = await _authRepository.verifyOtp(_verificationId!, smsCode);
      
      // Check if profile document exists in Firestore
      final profile = await _authRepository.getUserProfile(authUser.id);
      
      if (profile != null) {
        _user = profile;
        _needsRegistration = false;
      } else {
        // Profile setup is required
        _user = authUser;
        _needsRegistration = true;
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    } finally {
      _isManualLoginInProgress = false;
    }
  }

  /// Signs in with Google account
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _isManualLoginInProgress = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authUser = await _authRepository.signInWithGoogle();
      
      // Check if profile document exists in Firestore
      final profile = await _authRepository.getUserProfile(authUser.id);
      
      if (profile != null) {
        _user = profile;
        _needsRegistration = false;
      } else {
        // Profile setup is required
        _user = authUser;
        _needsRegistration = true;
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    } finally {
      _isManualLoginInProgress = false;
    }
  }

  /// Inserts a new user profile document into the Firestore users collection
  Future<bool> registerUserProfile(String name, UserRole role) async {
    if (_user == null) {
      _errorMessage = 'No authenticated user session found.';
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newUser = UserModel(
        id: _user!.id,
        name: name,
        phone: _user!.phone.isNotEmpty ? _user!.phone : (_phoneNumber ?? ''),
        role: role,
        createdAt: DateTime.now(),
      );

      await _authRepository.createUserProfile(newUser);
      
      _user = newUser;
      _needsRegistration = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _authRepository.signOut();
      _user = null;
      _verificationId = null;
      _phoneNumber = null;
      _needsRegistration = false;
    } catch (_) {}
    
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
