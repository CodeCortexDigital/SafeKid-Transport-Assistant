import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../models/user_model.dart';
import '../../core/errors/failures.dart';
import '../../core/constants/app_constants.dart';

abstract class AuthService {
  Future<UserModel> signInWithEmailAndPassword(String email, String password);
  Future<void> signOut();
  UserModel? get currentUser;
  Stream<UserModel?> get authStateChanges;
}

/// Production implementation of [AuthService] using Firebase Auth
class FirebaseAuthService implements AuthService {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;

  UserModel _mapFirebaseUser(fb.User user) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? 'Firebase User',
      phone: user.phoneNumber ?? '',
      role: UserRole.parent, // In production, role is retrieved from Firestore
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
  Future<UserModel> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user == null) {
        throw const AuthFailure('Failed to sign in. User is null.');
      }
      return _mapFirebaseUser(credential.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthFailure(e.message ?? 'Authentication error occurred.');
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}

/// Demo/Local Mock implementation of [AuthService] used when Firebase is unavailable
class MockAuthService implements AuthService {
  final StreamController<UserModel?> _authStateController = StreamController<UserModel?>.broadcast();
  UserModel? _currentUser;

  MockAuthService() {
    // Initial State: user is logged out
    _authStateController.add(null);
  }

  @override
  UserModel? get currentUser => _currentUser;

  @override
  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  @override
  Future<UserModel> signInWithEmailAndPassword(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate network latency

    if (email == AppConstants.mockEmail && password == AppConstants.mockPassword) {
      _currentUser = UserModel(
        uid: AppConstants.mockParentUid,
        email: AppConstants.mockEmail,
        name: AppConstants.mockParentName,
        phone: '+1 (555) 123-4567',
        role: UserRole.parent,
        emergencyContacts: ['+1 (555) 987-6543'],
      );
      _authStateController.add(_currentUser);
      return _currentUser!;
    } else if (email == AppConstants.mockDriverEmail && password == AppConstants.mockPassword) {
      _currentUser = UserModel(
        uid: AppConstants.mockDriverUid,
        email: AppConstants.mockDriverEmail,
        name: AppConstants.mockDriverName,
        phone: '+1 (555) 456-7890',
        role: UserRole.driver,
      );
      _authStateController.add(_currentUser);
      return _currentUser!;
    } else {
      throw const AuthFailure('Invalid email or password. Use parent@safekid.com / password123');
    }
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _currentUser = null;
    _authStateController.add(null);
  }
}
