import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../models/user_model.dart';
import '../../core/errors/failures.dart';

abstract class AuthService {
  Future<void> verifyPhoneNumber(
    String phoneNumber, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onVerificationFailed,
  });
  
  Future<UserModel> signInWithOtp(String verificationId, String smsCode);
  Future<void> signOut();
  UserModel? get currentUser;
  Stream<UserModel?> get authStateChanges;
}

/// Production implementation of [AuthService] using Firebase Auth
class FirebaseAuthService implements AuthService {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;

  UserModel _mapFirebaseUser(fb.User user) {
    return UserModel(
      id: user.uid,
      name: user.displayName ?? '',
      phone: user.phoneNumber ?? '',
      role: UserRole.parent, // Role is resolved from Firestore in repository/provider
      createdAt: DateTime.now(),
    );
  }

  @override
  UserModel? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user != null ? _mapFirebaseUser(user) : null;
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((user) {
      return user != null ? _mapFirebaseUser(user) : null;
    });
  }

  @override
  Future<void> verifyPhoneNumber(
    String phoneNumber, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onVerificationFailed,
  }) async {
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (fb.PhoneAuthCredential credential) async {
          await _firebaseAuth.signInWithCredential(credential);
        },
        verificationFailed: (fb.FirebaseAuthException e) {
          onVerificationFailed(e.message ?? 'Verification failed.');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onVerificationFailed(e.toString());
    }
  }

  @override
  Future<UserModel> signInWithOtp(String verificationId, String smsCode) async {
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      if (userCredential.user == null) {
        throw const AuthFailure('Auth failed. User is null.');
      }
      return _mapFirebaseUser(userCredential.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'OTP verification failed.');
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}

/// Demo/Local Mock implementation of [AuthService]
class MockAuthService implements AuthService {
  final StreamController<UserModel?> _authStateController = StreamController<UserModel?>.broadcast();
  UserModel? _currentUser;
  String _lastCheckedPhoneNumber = '';

  MockAuthService() {
    _authStateController.add(null);
  }

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  @override
  Future<void> verifyPhoneNumber(
    String phoneNumber, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onVerificationFailed,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _lastCheckedPhoneNumber = phoneNumber;
    onCodeSent('mock-verification-id-999');
  }

  @override
  Future<UserModel> signInWithOtp(String verificationId, String smsCode) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (smsCode == '123456') {
      // Map mock configurations based on phone numbers entered
      if (_lastCheckedPhoneNumber.contains('1111111')) {
        // Mock Parent
        _currentUser = UserModel(
          id: 'mock-parent-uid-123',
          name: 'John Doe',
          phone: _lastCheckedPhoneNumber,
          role: UserRole.parent,
          createdAt: DateTime.now(),
        );
      } else if (_lastCheckedPhoneNumber.contains('2222222')) {
        // Mock Driver
        _currentUser = UserModel(
          id: 'mock-driver-uid-456',
          name: 'Robert Smith',
          phone: _lastCheckedPhoneNumber,
          role: UserRole.driver,
          createdAt: DateTime.now(),
        );
      } else if (_lastCheckedPhoneNumber.contains('3333333')) {
        // Mock Assistant
        _currentUser = UserModel(
          id: 'mock-assistant-uid-789',
          name: 'Sarah Connor',
          phone: _lastCheckedPhoneNumber,
          role: UserRole.assistant,
          createdAt: DateTime.now(),
        );
      } else {
        // New number - needs profile setup
        _currentUser = UserModel(
          id: 'mock-user-new-${DateTime.now().millisecondsSinceEpoch}',
          name: '',
          phone: _lastCheckedPhoneNumber,
          role: UserRole.parent, // default
          createdAt: DateTime.now(),
        );
      }

      _authStateController.add(_currentUser);
      return _currentUser!;
    } else {
      throw const AuthFailure('Invalid verification code. Enter 123456 to log in.');
    }
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
    _authStateController.add(null);
  }
}
