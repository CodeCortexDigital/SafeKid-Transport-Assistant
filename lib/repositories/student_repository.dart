import '../services/firebase/firestore_service.dart';
import '../models/student_model.dart';

class StudentRepository {
  final FirestoreService _firestoreService;

  StudentRepository(this._firestoreService);

  Future<StudentModel> getStudentDetails(String studentId) async {
    return await _firestoreService.getStudent(studentId);
  }

  Stream<StudentModel> watchStudent(String studentId) {
    return _firestoreService.streamStudent(studentId);
  }

  Future<void> updateAttendance(String studentId, StudentStatus status) async {
    await _firestoreService.updateStudentStatus(studentId, status);
  }

  Future<List<StudentModel>> fetchParentStudents(String parentUid) async {
    return await _firestoreService.getStudentsForParent(parentUid);
  }
}
