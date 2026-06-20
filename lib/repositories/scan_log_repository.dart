import '../services/firebase/firestore_service.dart';
import '../models/scan_log_model.dart';

class ScanLogRepository {
  final FirestoreService _firestoreService;

  ScanLogRepository(this._firestoreService);

  Future<void> logScan(ScanLogModel log) async {
    await _firestoreService.createScanLog(log);
  }

  Future<List<ScanLogModel>> getLogsForStudent(String studentId) async {
    return await _firestoreService.getScanLogsForStudent(studentId);
  }
}
