import '../services/firebase/auth_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final AuthService _authService;

  AuthRepository(this._authService);

  UserModel? get currentUser => _authService.currentUser;

  Stream<UserModel?> get authStateChanges => _authService.authStateChanges;

  Future<UserModel> signIn(String email, String password) async {
    return await _authService.signInWithEmailAndPassword(email, password);
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
