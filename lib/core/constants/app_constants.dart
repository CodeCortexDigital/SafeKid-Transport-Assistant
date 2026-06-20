class AppConstants {
  static const String appName = 'SafeKid';
  static const String appTitle = 'SafeKid Transport Assistant';

  // Responsive Breakpoints
  static const double mobileMaxBreakpoint = 600.0;
  static const double tabletMaxBreakpoint = 1024.0;

  // Navigation Routes
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeHome = '/home';
  static const String routeStudentManagement = '/student-management';
  static const String routeQrCard = '/qr-card';
  static const String routeQrScanner = '/qr-scanner';
  static const String routeChatList = '/chat-list';
  static const String routeChat = '/chat';
  static const String routeChatbot = '/chatbot';
  static const String routeAiNotification = '/ai-notification';

  // Firestore Collection Names
  static const String usersCollection = 'users';
  static const String studentsCollection = 'students';
  static const String ridesCollection = 'rides';
  static const String attendanceCollection = 'attendance_logs';

  // Storage Folders
  static const String profilePicturesFolder = 'profiles';
  static const String studentQrsFolder = 'student_qrs';

  // Mock Credentials for Demo Mode
  static const String mockEmail = 'parent@safekid.com';
  static const String mockPassword = 'password123';
  static const String mockParentName = 'John Doe';
  static const String mockParentUid = 'mock-parent-uid-123';

  static const String mockDriverEmail = 'driver@safekid.com';
  static const String mockDriverName = 'Robert Smith';
  static const String mockDriverUid = 'mock-driver-uid-456';
  
  // Default coordinates (e.g. Central Park, NY for mock tracking)
  static const double defaultSchoolLatitude = 40.785091;
  static const double defaultSchoolLongitude = -73.968285;
  static const double defaultHomeLatitude = 40.760000;
  static const double defaultHomeLongitude = -73.985000;
}
