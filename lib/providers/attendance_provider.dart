import 'package:flutter/material.dart';
import '../repositories/student_repository.dart';
import '../models/student_model.dart';
import '../core/errors/failures.dart';

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

  AttendanceProvider(this._studentRepository);

  /// Fetches students linked to the current logged-in parent
  Future<void> fetchMyStudents(String parentUid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _myStudents = await _studentRepository.fetchParentStudents(parentUid);
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

  /// Processes QR codes, matching the scanned data to student IDs, and updating attendance
  Future<bool> scanQrCode(String qrData, StudentStatus status) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      String studentId = '';
      if (qrData.contains('STUDENT_EMMA_DOE_123') || qrData == 'mock-student-1') {
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

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
