import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/student_repository.dart';
import '../models/student_model.dart';
import '../core/errors/failures.dart';
import '../services/firebase/notification_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final StudentRepository _studentRepository;
  
  List<StudentModel> _myStudents = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  List<StudentModel> get myStudents => _myStudents;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  Timer? _readinessCheckTimer;
  final Set<String> _notifiedReadinessIds = {};

  AttendanceProvider(this._studentRepository) {
    startReadinessCheckTimer();
  }

  /// Fetches students linked to the current logged-in parent
  Future<void> fetchMyStudents(String parentUid, {String? parentPhone}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _myStudents = await _studentRepository.fetchParentStudents(parentUid, parentPhone: parentPhone);
      _isLoading = false;
      notifyListeners();
    } on Failure catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a new student and refreshes list
  Future<bool> addStudent(StudentModel student) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _studentRepository.createStudent(student);
      _myStudents.add(student);
      _successMessage = 'Student "${student.name}" registered successfully!';
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

  /// Processes QR codes, matching the scanned data to student IDs, and updating attendance
  Future<bool> scanQrCode(String qrData, StudentStatus status) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      String studentId = '';
      if (qrData.contains('|')) {
        studentId = qrData.split('|')[0];
      } else if (qrData.contains('STUDENT_EMMA_DOE_123') || qrData == 'mock-student-1') {
        studentId = 'mock-student-1';
      } else if (qrData.contains('STUDENT_LIAM_DOE_456') || qrData == 'mock-student-2') {
        studentId = 'mock-student-2';
      } else {
        // Fallback: direct ID matching
        studentId = qrData;
      }

      await _studentRepository.updateAttendance(studentId, status);
      
      // Update in local list for responsive UI update
      final index = _myStudents.indexWhere((student) => student.id == studentId);
      if (index != -1) {
        _myStudents[index] = _myStudents[index].copyWith(
          status: status,
          lastCheckIn: status == StudentStatus.atSchool ? DateTime.now() : _myStudents[index].lastCheckIn,
          lastCheckOut: status == StudentStatus.home ? DateTime.now() : _myStudents[index].lastCheckOut,
        );
      }
      
      _successMessage = 'Check-${status == StudentStatus.atSchool ? 'In' : 'Out'} logged successfully!';
      _isLoading = false;
      notifyListeners();
      return true;
    } on Failure catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Scan processing failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetches all students in the system (for admin management)
  Future<void> fetchAllStudents() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _myStudents = await _studentRepository.getAllStudents();
      _isLoading = false;
      notifyListeners();
    } on Failure catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates an existing student
  Future<bool> editStudent(StudentModel student) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _studentRepository.updateStudent(student);
      final index = _myStudents.indexWhere((s) => s.id == student.id);
      if (index != -1) {
        _myStudents[index] = student;
      }
      _successMessage = 'Student "${student.name}" updated successfully!';
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

  /// Deletes a student
  Future<bool> deleteStudent(String studentId) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _studentRepository.deleteStudent(studentId);
      _myStudents.removeWhere((s) => s.id == studentId);
      _successMessage = 'Student deleted successfully!';
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

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Links a student created by the driver to the parent account using a 5-minute unique OTP code
  Future<bool> linkStudentViaOtp(String otp, String parentUid, String parentPhone, String parentName) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final student = await _studentRepository.getStudentByOtp(otp);
      if (student == null) {
        throw const AuthFailure('Invalid OTP code. No student found.');
      }

      // Check expiration
      if (student.linkingOtpExpires == null || DateTime.now().isAfter(student.linkingOtpExpires!)) {
        throw const AuthFailure('This linking OTP has expired. Please ask the driver to generate a new one.');
      }

      // Update student profile with parent info, clearing the OTP
      final updatedStudent = student.copyWith(
        parentUid: parentUid,
        parentPhone: parentPhone,
        parentName: parentName,
        clearOtp: true,
      );

      await _studentRepository.updateStudent(updatedStudent);

      // Add to local list if not already present
      final index = _myStudents.indexWhere((s) => s.id == updatedStudent.id);
      if (index == -1) {
        _myStudents.add(updatedStudent);
      } else {
        _myStudents[index] = updatedStudent;
      }

      _successMessage = 'Linked child "${updatedStudent.name}" successfully!';
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

  /// Resets all loaded route students' statuses to home and clears check-in/out timestamps for a new trip
  Future<void> resetStudentsForTrip() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final isSunday = DateTime.now().weekday == DateTime.sunday;
      for (var student in _myStudents) {
        final isAbsent = student.status == StudentStatus.absent;
        final resetStudent = student.copyWith(
          status: isAbsent
              ? StudentStatus.absent
              : StudentStatus.home,
          clearCheckIn: true,
          clearCheckOut: true,
          isReadyForPickup: !isSunday && !isAbsent,
        );
        await _studentRepository.updateStudent(resetStudent);
      }
      // Re-fetch all to sync states
      _myStudents = await _studentRepository.getAllStudents();
      _isLoading = false;
      notifyListeners();
    } on Failure catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _readinessCheckTimer?.cancel();
    super.dispose();
  }

  void startReadinessCheckTimer() {
    _readinessCheckTimer?.cancel();
    _readinessCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkStudentReadinessTimings();
    });
  }

  void _checkStudentReadinessTimings() {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';

    for (var student in _myStudents) {
      if (student.hasCustomTimings && student.customPickupTime != null) {
        final key = '${student.id}_$todayStr';
        if (!_notifiedReadinessIds.contains(key)) {
          if (student.isStudentReady) {
            _notifiedReadinessIds.add(key);
            NotificationService().triggerNotification(
              title: '🔔 ${student.name} is Ready',
              body: '${student.name}\'s custom schedule timing (${student.customPickupTime}) has been reached. The student is ready at the gate for pickup.',
              studentId: student.id,
            );
          }
        }
      }
    }
  }
}
