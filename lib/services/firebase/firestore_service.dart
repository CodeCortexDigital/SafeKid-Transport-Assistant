import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../models/student_model.dart';
import '../../models/trip_model.dart';
import '../../models/user_model.dart';
import '../../models/vehicle_model.dart';
import '../../models/scan_log_model.dart';
import '../../models/message_model.dart';
import '../../models/feedback_model.dart';
import '../../models/billing_model.dart';
import '../../core/errors/failures.dart';
import '../../core/constants/app_constants.dart';
import 'notification_service.dart';

abstract class FirestoreService {
  // Users
  Future<void> createUserProfile(UserModel user);
  Future<UserModel?> getUserProfile(String uid);
  
  // Students
  Future<void> createStudent(StudentModel student);
  Future<StudentModel> getStudent(String studentId);
  Stream<StudentModel> streamStudent(String studentId);
  Future<void> updateStudentStatus(String studentId, StudentStatus status);
  Future<List<StudentModel>> getStudentsForParent(String parentUid, {String? parentPhone});
  Future<void> updateStudent(StudentModel student);
  Future<void> deleteStudent(String studentId);
  Future<List<StudentModel>> getAllStudents();
  Future<StudentModel?> getStudentByOtp(String otp);

  // Vehicles
  Future<VehicleModel> getVehicle(String vehicleId);
  Future<void> updateVehicleLocation(String vehicleId, double latitude, double longitude);
  Stream<VehicleModel> streamVehicle(String vehicleId);

  // Trips
  Future<TripModel> getTrip(String tripId);
  Future<void> updateTripStatus(String tripId, TripStatus status);
  Future<void> updateTripLocation(String tripId, double latitude, double longitude);
  Future<void> updateTripRouteName(String tripId, String routeName);
  Stream<TripModel> streamTrip(String tripId);

  // Scan Logs
  Future<void> createScanLog(ScanLogModel log);
  Future<List<ScanLogModel>> getScanLogsForStudent(String studentId);

  // Messages
  Future<void> sendMessage(MessageModel message);
  Stream<List<MessageModel>> streamMessages(String senderId, String receiverId);
  Future<List<UserModel>> getChatPartners(String currentUserId, UserRole role);
  Future<void> markMessagesAsRead(String senderId, String receiverId);

  // Feedback
  Future<void> submitFeedback(FeedbackModel feedback);
  Stream<List<FeedbackModel>> streamAllFeedback();

  // Billing
  Future<List<BillingModel>> getBillingRecords(String parentId);
  Stream<List<BillingModel>> streamBillingRecords(String parentId);
  Future<void> updateBillingStatus(String billId, String status, {String? paymentMethod});
  Future<List<BillingModel>> getBillingRecordsForParents(List<String> parentIds);
  Stream<List<BillingModel>> streamBillingRecordsForParents(List<String> parentIds);
  Future<void> createBillingRecord(BillingModel bill);
  Future<void> updateBillingRecord(BillingModel bill);
  Future<void> deleteBillingRecord(String billId);
  Future<bool> hasBillingRecordForMonth(String studentId, int year, int month);
}

/// Production implementation using Firebase Cloud Firestore
class FirebaseFirestoreService implements FirestoreService {
  final fs.FirebaseFirestore _firestore = fs.FirebaseFirestore.instance;

  @override
  Future<void> createUserProfile(UserModel user) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(user.id).set(user.toJson());
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromJson(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> createStudent(StudentModel student) async {
    try {
      await _firestore.collection(AppConstants.studentsCollection).doc(student.id).set(student.toJson());
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<StudentModel> getStudent(String studentId) async {
    try {
      final doc = await _firestore.collection(AppConstants.studentsCollection).doc(studentId).get();
      if (!doc.exists || doc.data() == null) {
        throw const ServerFailure('Student record not found.');
      }
      return StudentModel.fromJson(doc.data()!, doc.id);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<StudentModel> streamStudent(String studentId) {
    return _firestore
        .collection(AppConstants.studentsCollection)
        .doc(studentId)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) {
            throw const ServerFailure('Student record not found.');
          }
          return StudentModel.fromJson(doc.data()!, doc.id);
        });
  }

  @override
  Future<void> updateStudentStatus(String studentId, StudentStatus status) async {
    try {
      final student = await getStudent(studentId);
      final oldStatus = student.status;

      await _firestore.collection(AppConstants.studentsCollection).doc(studentId).update({
        'status': status.name,
        'isReadyForPickup': false,
        if (status == StudentStatus.atSchool) 'lastCheckIn': DateTime.now().toIso8601String(),
        if (status == StudentStatus.home) 'lastCheckOut': DateTime.now().toIso8601String(),
      });

      _dispatchStudentStatusNotification(student.name, studentId, oldStatus, status);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<StudentModel>> getStudentsForParent(String parentUid, {String? parentPhone}) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('parentUid', isEqualTo: parentUid)
          .get();
      return snapshot.docs.map((doc) => StudentModel.fromJson(doc.data(), doc.id)).toList();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateStudent(StudentModel student) async {
    try {
      await _firestore.collection(AppConstants.studentsCollection).doc(student.id).update(student.toJson());
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteStudent(String studentId) async {
    try {
      await _firestore.collection(AppConstants.studentsCollection).doc(studentId).delete();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<StudentModel>> getAllStudents() async {
    try {
      final snapshot = await _firestore.collection(AppConstants.studentsCollection).get();
      return snapshot.docs.map((doc) => StudentModel.fromJson(doc.data(), doc.id)).toList();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<StudentModel?> getStudentByOtp(String otp) async {
    try {
      final snap = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('linkingOtp', isEqualTo: otp)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return StudentModel.fromJson(snap.docs.first.data(), snap.docs.first.id);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<VehicleModel> getVehicle(String vehicleId) async {
    try {
      final doc = await _firestore.collection('vehicles').doc(vehicleId).get();
      if (!doc.exists || doc.data() == null) {
        throw const ServerFailure('Vehicle details not found.');
      }
      return VehicleModel.fromJson(doc.data()!, doc.id);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateVehicleLocation(String vehicleId, double latitude, double longitude) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'currentLatitude': latitude,
        'currentLongitude': longitude,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<VehicleModel> streamVehicle(String vehicleId) {
    return _firestore.collection('vehicles').doc(vehicleId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        throw const ServerFailure('Vehicle data stream error.');
      }
      return VehicleModel.fromJson(doc.data()!, doc.id);
    });
  }

  @override
  Future<TripModel> getTrip(String tripId) async {
    try {
      final doc = await _firestore.collection('trips').doc(tripId).get();
      if (!doc.exists || doc.data() == null) {
        throw const ServerFailure('Trip route details not found.');
      }
      return TripModel.fromJson(doc.data()!, doc.id);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateTripStatus(String tripId, TripStatus status) async {
    try {
      await _firestore.collection('trips').doc(tripId).update({
        'status': status.name,
        if (status == TripStatus.active) 'startTime': DateTime.now().toIso8601String(),
        if (status == TripStatus.completed) 'endTime': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateTripLocation(String tripId, double latitude, double longitude) async {
    try {
      await _firestore.collection('trips').doc(tripId).update({
        'currentLatitude': latitude,
        'currentLongitude': longitude,
      });
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateTripRouteName(String tripId, String routeName) async {
    try {
      await _firestore.collection('trips').doc(tripId).update({
        'routeName': routeName,
      });
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<TripModel> streamTrip(String tripId) {
    return _firestore.collection('trips').doc(tripId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        throw const ServerFailure('Trip tracking stream error.');
      }
      return TripModel.fromJson(doc.data()!, doc.id);
    });
  }

  @override
  Future<void> createScanLog(ScanLogModel log) async {
    try {
      await _firestore.collection('scan_logs').doc(log.id).set(log.toJson());
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<ScanLogModel>> getScanLogsForStudent(String studentId) async {
    try {
      final snap = await _firestore
          .collection('scan_logs')
          .where('studentId', isEqualTo: studentId)
          .get();
      final logs = snap.docs.map((doc) => ScanLogModel.fromJson(doc.data(), doc.id)).toList();
      // Sort in-memory by timestamp descending to avoid composite index requirements
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> sendMessage(MessageModel message) async {
    try {
      await _firestore.collection('messages').doc(message.id).set(message.toJson());
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<MessageModel>> streamMessages(String senderId, String receiverId) {
    return _firestore
        .collection('messages')
        .where('senderId', whereIn: [senderId, receiverId])
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => MessageModel.fromJson(doc.data(), doc.id))
              .where((m) =>
                  (m.senderId == senderId && m.receiverId == receiverId) ||
                  (m.senderId == receiverId && m.receiverId == senderId))
              .toList();
          // Sort in-memory by timestamp ascending to avoid composite index requirements
          list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return list;
        });
  }

  @override
  Future<List<UserModel>> getChatPartners(String currentUserId, UserRole role) async {
    try {
      if (role == UserRole.parent) {
        final students = await getStudentsForParent(currentUserId);
        final driverIds = <String>{};
        
        final tripsSnap = await _firestore.collection('trips').get();
        for (var doc in tripsSnap.docs) {
          final trip = TripModel.fromJson(doc.data(), doc.id);
          final intersection = trip.studentIds.toSet().intersection(students.map((s) => s.id).toSet());
          if (intersection.isNotEmpty && trip.driverId.isNotEmpty) {
            driverIds.add(trip.driverId);
          }
        }

        if (driverIds.isEmpty) {
          final driversSnap = await _firestore
              .collection(AppConstants.usersCollection)
              .where('role', isEqualTo: UserRole.driver.name)
              .get();
          return driversSnap.docs.map((doc) => UserModel.fromJson(doc.data(), doc.id)).toList();
        }

        final List<UserModel> partners = [];
        for (var dId in driverIds) {
          final profile = await getUserProfile(dId);
          if (profile != null) partners.add(profile);
        }
        return partners;
      } else {
        final tripsSnap = await _firestore
            .collection('trips')
            .where('driverId', isEqualTo: currentUserId)
            .get();
        
        final parentIds = <String>{};
        for (var doc in tripsSnap.docs) {
          final trip = TripModel.fromJson(doc.data(), doc.id);
          for (var sId in trip.studentIds) {
            try {
              final student = await getStudent(sId);
              if (student.parentUid.isNotEmpty) {
                parentIds.add(student.parentUid);
              }
            } catch (_) {}
          }
        }

        if (parentIds.isEmpty) {
          final parentsSnap = await _firestore
              .collection(AppConstants.usersCollection)
              .where('role', isEqualTo: UserRole.parent.name)
              .get();
          return parentsSnap.docs.map((doc) => UserModel.fromJson(doc.data(), doc.id)).toList();
        }

        final List<UserModel> partners = [];
        for (var pId in parentIds) {
          final profile = await getUserProfile(pId);
          if (profile != null) partners.add(profile);
        }
        return partners;
      }
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> markMessagesAsRead(String senderId, String receiverId) async {
    try {
      final snap = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .where('receiverId', isEqualTo: receiverId)
          .where('isRead', isEqualTo: false)
          .get();
          
      final batch = _firestore.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> submitFeedback(FeedbackModel feedback) async {
    try {
      await _firestore.collection('feedback').doc(feedback.id).set(feedback.toJson());
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<FeedbackModel>> streamAllFeedback() {
    return _firestore
        .collection('feedback')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => FeedbackModel.fromJson(doc.data(), doc.id)).toList());
  }

  @override
  Future<List<BillingModel>> getBillingRecords(String parentId) async {
    try {
      final snap = await _firestore
          .collection('billing')
          .where('parentId', isEqualTo: parentId)
          .get();
      return snap.docs
          .map((doc) => BillingModel.fromJson(doc.data(), doc.id))
          .where((bill) => bill.status != 'deleted')
          .toList();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<BillingModel>> streamBillingRecords(String parentId) {
    return _firestore
        .collection('billing')
        .where('parentId', isEqualTo: parentId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => BillingModel.fromJson(doc.data(), doc.id))
            .where((bill) => bill.status != 'deleted')
            .toList());
  }

  @override
  Future<void> updateBillingStatus(String billId, String status, {String? paymentMethod}) async {
    try {
      final data = <String, dynamic>{'status': status};
      if (paymentMethod != null) {
        data['paymentMethod'] = paymentMethod;
      }
      await _firestore.collection('billing').doc(billId).update(data);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<BillingModel>> getBillingRecordsForParents(List<String> parentIds) async {
    if (parentIds.isEmpty) return [];
    try {
      final snap = await _firestore
          .collection('billing')
          .where('parentId', whereIn: parentIds)
          .get();
      return snap.docs
          .map((doc) => BillingModel.fromJson(doc.data(), doc.id))
          .where((bill) => bill.status != 'deleted')
          .toList();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<List<BillingModel>> streamBillingRecordsForParents(List<String> parentIds) {
    if (parentIds.isEmpty) return Stream.value([]);
    return _firestore
        .collection('billing')
        .where('parentId', whereIn: parentIds)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => BillingModel.fromJson(doc.data(), doc.id))
            .where((bill) => bill.status != 'deleted')
            .toList());
  }

  @override
  Future<void> createBillingRecord(BillingModel bill) async {
    try {
      await _firestore.collection('billing').doc(bill.id).set(bill.toJson());
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> updateBillingRecord(BillingModel bill) async {
    try {
      await _firestore.collection('billing').doc(bill.id).update(bill.toJson());
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteBillingRecord(String billId) async {
    try {
      await _firestore.collection('billing').doc(billId).update({'status': 'deleted'});
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<bool> hasBillingRecordForMonth(String studentId, int year, int month) async {
    try {
      final snap = await _firestore
          .collection('billing')
          .where('studentId', isEqualTo: studentId)
          .get();
      return snap.docs.any((doc) {
        final data = doc.data();
        final billingDateStr = data['billingDate']?.toString();
        if (billingDateStr == null) return false;
        final billingDate = DateTime.tryParse(billingDateStr);
        if (billingDate == null) return false;
        return billingDate.year == year && billingDate.month == month;
      });
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}

/// Demo/Local Mock implementation
class MockFirestoreService implements FirestoreService {
  final Map<String, StudentModel> _students = {};
  final Map<String, UserModel> _users = {};
  final Map<String, VehicleModel> _vehicles = {};
  final Map<String, TripModel> _trips = {};
  final Map<String, ScanLogModel> _scanLogs = {};
  final Map<String, MessageModel> _messages = {};
  final Map<String, FeedbackModel> _feedback = {};
  final Map<String, BillingModel> _billing = {};
  
  final Map<String, StreamController<StudentModel>> _studentStreamControllers = {};
  final Map<String, StreamController<VehicleModel>> _vehicleStreamControllers = {};
  final Map<String, StreamController<TripModel>> _tripStreamControllers = {};
  final Map<String, StreamController<List<MessageModel>>> _messageStreamControllers = {};
  final Map<String, StreamController<List<BillingModel>>> _billingStreamControllers = {};
  final StreamController<List<FeedbackModel>> _feedbackStreamController = StreamController<List<FeedbackModel>>.broadcast();

  MockFirestoreService() {
    // Users
    _users['mock-parent-uid-123'] = UserModel(
      id: 'mock-parent-uid-123',
      name: 'John Doe',
      phone: '+15551111111',
      role: UserRole.parent,
      createdAt: DateTime.now(),
    );
    _users['mock-driver-uid-456'] = UserModel(
      id: 'mock-driver-uid-456',
      name: 'Robert Smith',
      phone: '+15552222222',
      role: UserRole.driver,
      createdAt: DateTime.now(),
    );

    // Students
    _students['mock-student-1'] = StudentModel(
      id: 'mock-student-1',
      name: 'Emma Doe',
      className: 'Grade 3',
      section: 'A',
      schoolName: 'Attock City School',
      parentUid: 'mock-parent-uid-123',
      qrCodeData: 'STUDENT_EMMA_DOE_123',
      status: StudentStatus.home,
      isReadyForPickup: DateTime.now().weekday != DateTime.sunday,
      parentName: 'John Doe',
      parentPhone: '+15551111111',
      pickupPoint: 'Hazro Stop',
      dropPoint: 'Attock School Stop',
      pickupLatitude: 33.9100,
      pickupLongitude: 72.4900,
      dropLatitude: 33.7680,
      dropLongitude: 72.3620,
    );
    _students['mock-student-2'] = StudentModel(
      id: 'mock-student-2',
      name: 'Liam Doe',
      className: 'Grade 5',
      section: 'B',
      schoolName: 'Attock City School',
      parentUid: 'mock-parent-uid-123',
      qrCodeData: 'STUDENT_LIAM_DOE_456',
      status: StudentStatus.atSchool,
      parentName: 'John Doe',
      parentPhone: '+15551111111',
      pickupPoint: 'Sanjwal Stop',
      dropPoint: 'Attock School Stop',
      pickupLatitude: 33.8500,
      pickupLongitude: 72.4200,
      dropLatitude: 33.7680,
      dropLongitude: 72.3620,
    );

    // Vehicles
    _vehicles['mock-vehicle-1'] = VehicleModel(
      id: 'mock-vehicle-1',
      vehicleNumber: 'GK-882',
      model: 'Ford Transit Bus',
      capacity: 24,
      driverId: 'mock-driver-uid-456',
      status: 'active',
      currentLatitude: AppConstants.defaultSchoolLatitude,
      currentLongitude: AppConstants.defaultSchoolLongitude,
      lastUpdated: DateTime.now(),
    );

    // Trips
    _trips['mock-ride-1'] = TripModel(
      id: 'mock-ride-1',
      vehicleId: 'mock-vehicle-1',
      driverId: 'mock-driver-uid-456',
      routeName: 'Greenwood Route 4B (Standard)',
      studentIds: ['mock-student-1', 'mock-student-2'],
      currentLatitude: AppConstants.defaultSchoolLatitude,
      currentLongitude: AppConstants.defaultSchoolLongitude,
      etaMinutes: '--',
      status: TripStatus.scheduled,
    );

    // Billing
    _billing['mock-bill-1'] = BillingModel(
      id: 'mock-bill-1',
      parentId: 'mock-parent-uid-123',
      studentId: 'mock-student-1',
      amount: 150.00,
      status: 'paid',
      billingDate: DateTime.now().subtract(const Duration(days: 30)),
      dueDate: DateTime.now().subtract(const Duration(days: 15)),
      paymentMethod: 'Card',
    );
    _billing['mock-bill-2'] = BillingModel(
      id: 'mock-bill-2',
      parentId: 'mock-parent-uid-123',
      studentId: 'mock-student-2',
      amount: 150.00,
      status: 'pending',
      billingDate: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 15)),
    );

    // Messages (Initial Chat)
    _messages['mock-msg-1'] = MessageModel(
      id: 'mock-msg-1',
      senderId: 'mock-driver-uid-456',
      receiverId: 'mock-parent-uid-123',
      messageText: 'Hello! I am Robert, Greenwood route driver. Bus is ready.',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: true,
      tripId: 'mock-ride-1',
    );
  }

  @override
  Future<void> createUserProfile(UserModel user) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _users[user.id] = user;
  }

  @override
  Future<UserModel?> getUserProfile(String uid) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _users[uid];
  }

  @override
  Future<void> createStudent(StudentModel student) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _students[student.id] = student;
    _studentStreamControllers[student.id]?.add(student);
  }

  @override
  Future<StudentModel> getStudent(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_students.containsKey(studentId)) {
      throw const ServerFailure('Student not found.');
    }
    return _students[studentId]!;
  }

  @override
  Stream<StudentModel> streamStudent(String studentId) {
    final controller = _studentStreamControllers.putIfAbsent(
      studentId, 
      () => StreamController<StudentModel>.broadcast()
    );
    if (_students.containsKey(studentId)) {
      controller.add(_students[studentId]!);
    }
    return controller.stream;
  }

  @override
  Future<void> updateStudentStatus(String studentId, StudentStatus status) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_students.containsKey(studentId)) return;
    
    final student = _students[studentId]!;
    final oldStatus = student.status;

    final updated = student.copyWith(
      status: status,
      isReadyForPickup: false,
      lastCheckIn: status == StudentStatus.atSchool ? DateTime.now() : student.lastCheckIn,
      lastCheckOut: status == StudentStatus.home ? DateTime.now() : student.lastCheckOut,
    );
    _students[studentId] = updated;
    _studentStreamControllers[studentId]?.add(updated);

    _dispatchStudentStatusNotification(student.name, studentId, oldStatus, status);
  }

  @override
  Future<List<StudentModel>> getStudentsForParent(String parentUid, {String? parentPhone}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _students.values.where((student) => student.parentUid == parentUid).toList();
  }

  @override
  Future<void> updateStudent(StudentModel student) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _students[student.id] = student;
    _studentStreamControllers[student.id]?.add(student);
  }

  @override
  Future<void> deleteStudent(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _students.remove(studentId);
    _studentStreamControllers.remove(studentId);
  }

  @override
  Future<List<StudentModel>> getAllStudents() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _students.values.toList();
  }

  @override
  Future<StudentModel?> getStudentByOtp(String otp) async {
    await Future.delayed(const Duration(milliseconds: 200));
    for (var student in _students.values) {
      if (student.linkingOtp == otp) {
        return student;
      }
    }
    return null;
  }

  @override
  Future<VehicleModel> getVehicle(String vehicleId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_vehicles.containsKey(vehicleId)) {
      throw const ServerFailure('Vehicle details not found.');
    }
    return _vehicles[vehicleId]!;
  }

  @override
  Future<void> updateVehicleLocation(String vehicleId, double latitude, double longitude) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_vehicles.containsKey(vehicleId)) return;

    final updated = _vehicles[vehicleId]!.copyWith(
      currentLatitude: latitude,
      currentLongitude: longitude,
      lastUpdated: DateTime.now(),
    );
    _vehicles[vehicleId] = updated;
    _vehicleStreamControllers[vehicleId]?.add(updated);
  }

  @override
  Stream<VehicleModel> streamVehicle(String vehicleId) {
    final controller = _vehicleStreamControllers.putIfAbsent(
      vehicleId, 
      () => StreamController<VehicleModel>.broadcast()
    );
    if (_vehicles.containsKey(vehicleId)) {
      controller.add(_vehicles[vehicleId]!);
    }
    return controller.stream;
  }

  @override
  Future<TripModel> getTrip(String tripId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_trips.containsKey(tripId)) {
      throw const ServerFailure('Trip not found.');
    }
    return _trips[tripId]!;
  }

  @override
  Future<void> updateTripStatus(String tripId, TripStatus status) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_trips.containsKey(tripId)) return;

    final updated = _trips[tripId]!.copyWith(
      status: status,
      startTime: status == TripStatus.active ? DateTime.now() : _trips[tripId]!.startTime,
      endTime: status == TripStatus.completed ? DateTime.now() : _trips[tripId]!.endTime,
    );
    _trips[tripId] = updated;
    _tripStreamControllers[tripId]?.add(updated);
  }

  @override
  Future<void> updateTripLocation(String tripId, double latitude, double longitude) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_trips.containsKey(tripId)) return;

    final updated = _trips[tripId]!.copyWith(
      currentLatitude: latitude,
      currentLongitude: longitude,
    );
    _trips[tripId] = updated;
    _tripStreamControllers[tripId]?.add(updated);
  }

  @override
  Future<void> updateTripRouteName(String tripId, String routeName) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_trips.containsKey(tripId)) return;

    final updated = _trips[tripId]!.copyWith(
      routeName: routeName,
    );
    _trips[tripId] = updated;
    _tripStreamControllers[tripId]?.add(updated);
  }

  @override
  Stream<TripModel> streamTrip(String tripId) {
    final controller = _tripStreamControllers.putIfAbsent(
      tripId, 
      () => StreamController<TripModel>.broadcast()
    );
    if (_trips.containsKey(tripId)) {
      controller.add(_trips[tripId]!);
    }
    _simulateTripMovement(tripId);
    return controller.stream;
  }

  void _simulateTripMovement(String tripId) {
    int tick = 0;
    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_trips.containsKey(tripId)) {
        timer.cancel();
        return;
      }
      
      final currentTrip = _trips[tripId]!;
      if (currentTrip.status == TripStatus.completed || currentTrip.status == TripStatus.cancelled) {
        timer.cancel();
        return;
      }

      double progress = (tick % 10) / 10.0;
      double lat = AppConstants.defaultSchoolLatitude + 
          (AppConstants.defaultHomeLatitude - AppConstants.defaultSchoolLatitude) * progress;
      double lng = AppConstants.defaultSchoolLongitude + 
          (AppConstants.defaultHomeLongitude - AppConstants.defaultSchoolLongitude) * progress;
      
      int minutesRemaining = (15 - tick * 1.5).round();
      if (minutesRemaining < 1) minutesRemaining = 1;
      
      TripStatus nextStatus = currentTrip.status;
      if (tick == 0) {
        nextStatus = TripStatus.active;
      } else if (tick >= 10) {
        nextStatus = TripStatus.completed;
      }

      final updated = currentTrip.copyWith(
        status: nextStatus,
        currentLatitude: lat,
        currentLongitude: lng,
        etaMinutes: nextStatus == TripStatus.completed ? '0' : '$minutesRemaining',
      );
      
      _trips[tripId] = updated;
      _tripStreamControllers[tripId]?.add(updated);
      
      // Update vehicle coordinates too (fire and forget, with error handling)
      updateVehicleLocation('mock-vehicle-1', lat, lng).catchError((_) {
        // Silently catch errors (e.g., if vehicle doesn't exist)
      });
      
      if (nextStatus == TripStatus.completed) {
        for (var sid in currentTrip.studentIds) {
          updateStudentStatus(sid, StudentStatus.home);
        }
        timer.cancel();
      }
      tick++;
    });
  }

  @override
  Future<void> createScanLog(ScanLogModel log) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _scanLogs[log.id] = log;
  }

  @override
  Future<List<ScanLogModel>> getScanLogsForStudent(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _scanLogs.values.where((log) => log.studentId == studentId).toList();
  }

  @override
  Future<void> sendMessage(MessageModel message) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _messages[message.id] = message;
    
    // Trigger update on listeners
    _notifyMessagesUpdate(message.senderId, message.receiverId);
  }

  void _notifyMessagesUpdate(String senderId, String receiverId) {
    final queryKey = _getMessageKey(senderId, receiverId);
    if (_messageStreamControllers.containsKey(queryKey)) {
      final list = _messages.values
          .where((m) =>
              (m.senderId == senderId && m.receiverId == receiverId) ||
              (m.senderId == receiverId && m.receiverId == senderId))
          .toList();
      _messageStreamControllers[queryKey]!.add(list);
    }
  }

  String _getMessageKey(String id1, String id2) {
    final list = [id1, id2]..sort();
    return list.join('_');
  }

  @override
  Stream<List<MessageModel>> streamMessages(String senderId, String receiverId) {
    final queryKey = _getMessageKey(senderId, receiverId);
    final controller = _messageStreamControllers.putIfAbsent(
      queryKey, 
      () => StreamController<List<MessageModel>>.broadcast()
    );
    final initialList = _messages.values
        .where((m) =>
            (m.senderId == senderId && m.receiverId == receiverId) ||
            (m.senderId == receiverId && m.receiverId == senderId))
        .toList();
    controller.add(initialList);
    return controller.stream;
  }

  @override
  Future<List<UserModel>> getChatPartners(String currentUserId, UserRole role) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (role == UserRole.parent) {
      return _users.values.where((u) => u.role == UserRole.driver).toList();
    } else {
      return _users.values.where((u) => u.role == UserRole.parent).toList();
    }
  }

  @override
  Future<void> markMessagesAsRead(String senderId, String receiverId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    bool changed = false;
    _messages.forEach((key, message) {
      if (message.senderId == senderId && message.receiverId == receiverId && !message.isRead) {
        _messages[key] = message.copyWith(isRead: true);
        changed = true;
      }
    });

    if (changed) {
      _notifyMessagesUpdate(senderId, receiverId);
    }
  }

  @override
  Future<void> submitFeedback(FeedbackModel feed) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _feedback[feed.id] = feed;
    final list = _feedback.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _feedbackStreamController.add(list);
  }

  @override
  Stream<List<FeedbackModel>> streamAllFeedback() {
    final list = _feedback.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    Future.microtask(() => _feedbackStreamController.add(list));
    return _feedbackStreamController.stream;
  }

  @override
  Future<List<BillingModel>> getBillingRecords(String parentId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _billing.values
        .where((bill) => bill.parentId == parentId && bill.status != 'deleted')
        .toList();
  }

  @override
  Stream<List<BillingModel>> streamBillingRecords(String parentId) {
    final controller = _billingStreamControllers.putIfAbsent(
      parentId, 
      () => StreamController<List<BillingModel>>.broadcast()
    );
    final initialList = _billing.values
        .where((bill) => bill.parentId == parentId && bill.status != 'deleted')
        .toList();
    controller.add(initialList);
    return controller.stream;
  }

  @override
  Future<void> updateBillingStatus(String billId, String status, {String? paymentMethod}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final bill = _billing[billId];
    if (bill != null) {
      _billing[billId] = bill.copyWith(status: status, paymentMethod: paymentMethod);
      final parentId = bill.parentId;
      
      // Notify parent stream and any parents list streams
      _billingStreamControllers.forEach((key, controller) {
        final keys = key.split('_');
        if (keys.contains(parentId) || key == parentId) {
          final list = _billing.values
              .where((b) => (keys.contains(b.parentId) || b.parentId == key) && b.status != 'deleted')
              .toList();
          controller.add(list);
        }
      });
    }
  }

  @override
  Future<List<BillingModel>> getBillingRecordsForParents(List<String> parentIds) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _billing.values
        .where((bill) => parentIds.contains(bill.parentId) && bill.status != 'deleted')
        .toList();
  }

  @override
  Stream<List<BillingModel>> streamBillingRecordsForParents(List<String> parentIds) {
    final queryKey = parentIds.join('_');
    final controller = _billingStreamControllers.putIfAbsent(
      queryKey, 
      () => StreamController<List<BillingModel>>.broadcast()
    );
    final initialList = _billing.values
        .where((bill) => parentIds.contains(bill.parentId) && bill.status != 'deleted')
        .toList();
    controller.add(initialList);
    return controller.stream;
  }

  @override
  Future<void> createBillingRecord(BillingModel bill) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _billing[bill.id] = bill;
    _notifyBillingUpdate(bill.parentId);
  }

  @override
  Future<void> updateBillingRecord(BillingModel bill) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _billing[bill.id] = bill;
    _notifyBillingUpdate(bill.parentId);
  }

  @override
  Future<void> deleteBillingRecord(String billId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final bill = _billing[billId];
    if (bill != null) {
      _billing[billId] = bill.copyWith(status: 'deleted');
      _notifyBillingUpdate(bill.parentId);
    }
  }

  @override
  Future<bool> hasBillingRecordForMonth(String studentId, int year, int month) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _billing.values.any((bill) =>
        bill.studentId == studentId &&
        bill.billingDate.year == year &&
        bill.billingDate.month == month);
  }

  void _notifyBillingUpdate(String parentId) {
    _billingStreamControllers.forEach((key, controller) {
      final keys = key.split('_');
      if (keys.contains(parentId) || key == parentId) {
        final list = _billing.values
            .where((b) => (keys.contains(b.parentId) || b.parentId == key) && b.status != 'deleted')
            .toList();
        controller.add(list);
      }
    });
  }
}

/// Helper function to dispatch student transit notifications dynamically
void _dispatchStudentStatusNotification(
  String studentName,
  String studentId,
  StudentStatus oldStatus,
  StudentStatus newStatus,
) {
  if (oldStatus == newStatus) return;

  String title = 'SafeKid Transit Alert';
  String body = '$studentName status updated to ${newStatus.name}.';

  if (newStatus == StudentStatus.inTransit) {
    if (oldStatus == StudentStatus.home) {
      title = '🚌 $studentName Picked Up';
      body = '$studentName has boarded the school van. En route to school.';
    } else if (oldStatus == StudentStatus.atSchool) {
      title = '🚌 $studentName Started Return Trip';
      body = '$studentName has boarded the van home. En route to drop point.';
    }
  } else if (newStatus == StudentStatus.atSchool) {
    title = '🏫 $studentName Reached School';
    body = '$studentName has arrived safely at school and checked in.';
  } else if (newStatus == StudentStatus.home) {
    title = '🏠 $studentName Dropped Home';
    body = '$studentName has arrived safely at home and checked out.';
  }

  NotificationService().triggerNotification(
    title: title,
    body: body,
    studentId: studentId,
  );
}
