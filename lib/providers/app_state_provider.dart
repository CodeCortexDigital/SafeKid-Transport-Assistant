import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';
import '../services/firebase/messaging_service.dart';
import '../services/device/location_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/location_repository.dart';

class AppStateProvider extends ChangeNotifier {
  bool _isFirebaseInitialized = false;
  bool _isLoading = true;

  bool get isFirebaseInitialized => _isFirebaseInitialized;
  bool get isLoading => _isLoading;

  late AuthService authService;
  late FirestoreService firestoreService;
  late StorageService storageService;
  late MessagingService messagingService;
  late LocationService locationService;

  late AuthRepository authRepository;
  late StudentRepository studentRepository;
  late LocationRepository locationRepository;

  AppStateProvider() {
    initializeApp();
  }

  Future<void> initializeApp() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize Firebase (will throw an exception if config is missing)
      await Firebase.initializeApp();
      _isFirebaseInitialized = true;

      // Assign production services
      authService = FirebaseAuthService();
      firestoreService = FirebaseFirestoreService();
      storageService = FirebaseStorageService();
      messagingService = FirebaseMessagingService();
      locationService = DeviceLocationService();
    } catch (e) {
      _isFirebaseInitialized = false;

      // Fallback to Mock services for Demo Mode
      authService = MockAuthService();
      firestoreService = MockFirestoreService();
      storageService = MockStorageService();
      messagingService = MockMessagingService();
      locationService = MockLocationService();
    }

    // Initialize Repositories using the resolved services
    authRepository = AuthRepository(authService);
    studentRepository = StudentRepository(firestoreService);
    locationRepository = LocationRepository(locationService, firestoreService);

    // Initialize Messaging
    await messagingService.initialize();

    _isLoading = false;
    notifyListeners();
  }
}
