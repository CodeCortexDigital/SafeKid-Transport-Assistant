import '../services/firebase/firestore_service.dart';
import '../models/student_model.dart';

class StudentRepository {
  final FirestoreService _firestoreService;

  StudentRepository(this._firestoreService);

  Future<void> createStudent(StudentModel student) async {
    await _firestoreService.createStudent(student);
  }

  Future<StudentModel> getStudentDetails(String studentId) async {
    return await _firestoreService.getStudent(studentId);
  }

  Stream<StudentModel> watchStudent(String studentId) {
    return _firestoreService.streamStudent(studentId);
  }

  Future<void> updateAttendance(String studentId, StudentStatus status) async {
    await _firestoreService.updateStudentStatus(studentId, status);
  }

  Future<List<StudentModel>> fetchParentStudents(String parentUid, {String? parentPhone}) async {
    return await _firestoreService.getStudentsForParent(parentUid, parentPhone: parentPhone);
  }

  Future<void> updateStudent(StudentModel student) async {
    await _firestoreService.updateStudent(student);
  }

  Future<void> deleteStudent(String studentId) async {
    await _firestoreService.deleteStudent(studentId);
  }

  Future<List<StudentModel>> getAllStudents() async {
    return await _firestoreService.getAllStudents();
  }

  Future<StudentModel?> getStudentByOtp(String otp) async {
    return await _firestoreService.getStudentByOtp(otp);
  }
}
