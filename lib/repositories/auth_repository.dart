import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  AuthRepository(this._authService, this._firestoreService);

  UserModel? get currentUser => _authService.currentUser;

  Stream<UserModel?> get authStateChanges => _authService.authStateChanges;

  Future<void> verifyPhone(
    String phoneNumber, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    await _authService.verifyPhoneNumber(
      phoneNumber,
      onCodeSent: onCodeSent,
      onVerificationFailed: onFailed,
    );
  }

  Future<UserModel> verifyOtp(String verificationId, String smsCode) async {
    return await _authService.signInWithOtp(verificationId, smsCode);
  }

  Future<UserModel> signInWithGoogle() async {
    return await _authService.signInWithGoogle();
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<UserModel?> getUserProfile(String uid) async {
    return await _firestoreService.getUserProfile(uid);
  }

  Future<void> createUserProfile(UserModel user) async {
    await _firestoreService.createUserProfile(user);
  }
}
