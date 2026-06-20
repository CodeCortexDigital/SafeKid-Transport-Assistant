import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../models/student_model.dart';
import '../../models/ride_model.dart';
import '../../core/errors/failures.dart';
import '../../core/constants/app_constants.dart';

abstract class FirestoreService {
  Future<StudentModel> getStudent(String studentId);
  Stream<StudentModel> streamStudent(String studentId);
  Future<void> updateStudentStatus(String studentId, StudentStatus status);
  
  Future<RideModel> getRide(String rideId);
  Stream<RideModel> streamRide(String rideId);
  Future<void> updateRideLocation(String rideId, double latitude, double longitude);
  Future<List<StudentModel>> getStudentsForParent(String parentUid);
}

/// Production implementation using Firebase Cloud Firestore
class FirebaseFirestoreService implements FirestoreService {
  final fs.FirebaseFirestore _firestore = fs.FirebaseFirestore.instance;

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
      final data = {
        'status': status.name,
        if (status == StudentStatus.atSchool) 'lastCheckIn': DateTime.now().toIso8601String(),
        if (status == StudentStatus.home) 'lastCheckOut': DateTime.now().toIso8601String(),
      };
      
      await _firestore.collection(AppConstants.studentsCollection).doc(studentId).update(data);
      
      // Log attendance event
      await _firestore.collection(AppConstants.attendanceCollection).add({
        'studentId': studentId,
        'status': status.name,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<RideModel> getRide(String rideId) async {
    try {
      final doc = await _firestore.collection(AppConstants.ridesCollection).doc(rideId).get();
      if (!doc.exists || doc.data() == null) {
        throw const ServerFailure('Ride not found.');
      }
      return RideModel.fromJson(doc.data()!, doc.id);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<RideModel> streamRide(String rideId) {
    return _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) {
            throw const ServerFailure('Ride details not found.');
          }
          return RideModel.fromJson(doc.data()!, doc.id);
        });
  }

  @override
  Future<void> updateRideLocation(String rideId, double latitude, double longitude) async {
    try {
      await _firestore.collection(AppConstants.ridesCollection).doc(rideId).update({
        'currentLatitude': latitude,
        'currentLongitude': longitude,
      });
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<StudentModel>> getStudentsForParent(String parentUid) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('parentUid', isEqualTo: parentUid)
          .get();
      
      return snapshot.docs
          .map((doc) => StudentModel.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}

/// Demo/Local Mock implementation using standard in-memory states and simulation
class MockFirestoreService implements FirestoreService {
  final Map<String, StudentModel> _students = {};
  final Map<String, RideModel> _rides = {};
  
  final Map<String, StreamController<StudentModel>> _studentStreamControllers = {};
  final Map<String, StreamController<RideModel>> _rideStreamControllers = {};

  MockFirestoreService() {
    // Populate mock students
    _students['mock-student-1'] = StudentModel(
      id: 'mock-student-1',
      name: 'Emma Doe',
      className: 'Grade 3',
      section: 'A',
      schoolName: 'Greenwood International',
      parentUid: AppConstants.mockParentUid,
      qrCodeData: 'STUDENT_EMMA_DOE_123',
      status: StudentStatus.home,
    );

    _students['mock-student-2'] = StudentModel(
      id: 'mock-student-2',
      name: 'Liam Doe',
      className: 'Grade 5',
      section: 'B',
      schoolName: 'Greenwood International',
      parentUid: AppConstants.mockParentUid,
      qrCodeData: 'STUDENT_LIAM_DOE_456',
      status: StudentStatus.atSchool,
    );

    // Populate mock rides
    _rides['mock-ride-1'] = RideModel(
      id: 'mock-ride-1',
      driverUid: AppConstants.mockDriverUid,
      routeName: 'Greenwood Route 4B',
      studentIds: ['mock-student-1', 'mock-student-2'],
      currentLatitude: AppConstants.defaultSchoolLatitude,
      currentLongitude: AppConstants.defaultSchoolLongitude,
      status: RideStatus.scheduled,
      etaMinutes: '--',
    );
  }

  @override
  Future<StudentModel> getStudent(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_students.containsKey(studentId)) {
      throw const ServerFailure('Mock student not found.');
    }
    return _students[studentId]!;
  }

  @override
  Stream<StudentModel> streamStudent(String studentId) {
    final controller = _studentStreamControllers.putIfAbsent(
      studentId, 
      () => StreamController<StudentModel>.broadcast()
    );
    // Add initial item
    if (_students.containsKey(studentId)) {
      controller.add(_students[studentId]!);
    }
    return controller.stream;
  }

  @override
  Future<void> updateStudentStatus(String studentId, StudentStatus status) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!_students.containsKey(studentId)) {
      throw const ServerFailure('Mock student not found.');
    }
    
    final updated = _students[studentId]!.copyWith(
      status: status,
      lastCheckIn: status == StudentStatus.atSchool ? DateTime.now() : _students[studentId]!.lastCheckIn,
      lastCheckOut: status == StudentStatus.home ? DateTime.now() : _students[studentId]!.lastCheckOut,
    );
    _students[studentId] = updated;
    
    // Notify streams
    _studentStreamControllers[studentId]?.add(updated);
  }

  @override
  Future<RideModel> getRide(String rideId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_rides.containsKey(rideId)) {
      throw const ServerFailure('Mock ride not found.');
    }
    return _rides[rideId]!;
  }

  @override
  Stream<RideModel> streamRide(String rideId) {
    final controller = _rideStreamControllers.putIfAbsent(
      rideId, 
      () => StreamController<RideModel>.broadcast()
    );
    
    if (_rides.containsKey(rideId)) {
      controller.add(_rides[rideId]!);
    }
    
    // Simulate motion if it's active
    _simulateRideMovement(rideId);
    
    return controller.stream;
  }

  void _simulateRideMovement(String rideId) {
    int tick = 0;
    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_rides.containsKey(rideId)) {
        timer.cancel();
        return;
      }
      
      final currentRide = _rides[rideId]!;
      if (currentRide.status == RideStatus.completed || currentRide.status == RideStatus.cancelled) {
        timer.cancel();
        return;
      }

      // Linear interpolation between School and Home
      double progress = (tick % 10) / 10.0;
      double lat = AppConstants.defaultSchoolLatitude + 
          (AppConstants.defaultHomeLatitude - AppConstants.defaultSchoolLatitude) * progress;
      double lng = AppConstants.defaultSchoolLongitude + 
          (AppConstants.defaultHomeLongitude - AppConstants.defaultSchoolLongitude) * progress;
      
      int minutesRemaining = (15 - tick * 1.5).round();
      if (minutesRemaining < 1) minutesRemaining = 1;
      
      RideStatus nextStatus = currentRide.status;
      if (tick == 0) {
        nextStatus = RideStatus.active;
      } else if (tick >= 10) {
        nextStatus = RideStatus.completed;
      }

      final updated = currentRide.copyWith(
        status: nextStatus,
        currentLatitude: lat,
        currentLongitude: lng,
        etaMinutes: nextStatus == RideStatus.completed ? '0' : '$minutesRemaining',
      );
      
      _rides[rideId] = updated;
      _rideStreamControllers[rideId]?.add(updated);
      
      if (nextStatus == RideStatus.completed) {
        // Also update students status to home when ride is completed
        for (var sid in currentRide.studentIds) {
          updateStudentStatus(sid, StudentStatus.home);
        }
        timer.cancel();
      }
      tick++;
    });
  }

  @override
  Future<void> updateRideLocation(String rideId, double latitude, double longitude) async {
    if (!_rides.containsKey(rideId)) {
      throw const ServerFailure('Mock ride not found.');
    }
    final updated = _rides[rideId]!.copyWith(
      currentLatitude: latitude,
      currentLongitude: longitude,
    );
    _rides[rideId] = updated;
    _rideStreamControllers[rideId]?.add(updated);
  }

  @override
  Future<List<StudentModel>> getStudentsForParent(String parentUid) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _students.values.where((student) => student.parentUid == parentUid).toList();
  }
}
