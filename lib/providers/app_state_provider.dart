import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';
import '../services/firebase/messaging_service.dart';
import '../services/device/location_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/vehicle_repository.dart';
import '../repositories/trip_repository.dart';
import '../repositories/scan_log_repository.dart';
import '../repositories/message_repository.dart';
import '../repositories/feedback_repository.dart';
import '../repositories/billing_repository.dart';

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
  late VehicleRepository vehicleRepository;
  late TripRepository tripRepository;
  late ScanLogRepository scanLogRepository;
  late MessageRepository messageRepository;
  late FeedbackRepository feedbackRepository;
  late BillingRepository billingRepository;

  AppStateProvider() {
    initializeApp();
  }

  Future<void> initializeApp() async {
    _isLoading = true;
    notifyListeners();

    try {
      try {
        // First try native configuration files (google-services.json / GoogleService-Info.plist)
        await Firebase.initializeApp();
      } catch (_) {
        // Fallback to manual options matching the provided web parameters
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyD7kbY4q9yTC5yhwlkrqViy_8p_LBF_MgA',
            appId: '1:473302958295:web:6bad73cc657a509cedb092',
            messagingSenderId: '473302958295',
            projectId: 'safekid-transport-assistant',
            authDomain: 'safekid-transport-assistant.firebaseapp.com',
            storageBucket: 'safekid-transport-assistant.firebasestorage.app',
            measurementId: 'G-KQD6KX2P4G',
          ),
        );
      }
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
    authRepository = AuthRepository(authService, firestoreService);
    studentRepository = StudentRepository(firestoreService);
    vehicleRepository = VehicleRepository(firestoreService);
    tripRepository = TripRepository(locationService, firestoreService);
    scanLogRepository = ScanLogRepository(firestoreService);
    messageRepository = MessageRepository(firestoreService);
    feedbackRepository = FeedbackRepository(firestoreService);
    billingRepository = BillingRepository(firestoreService);

    // Initialize Messaging
    await messagingService.initialize();

    _isLoading = false;
    notifyListeners();
  }
}
