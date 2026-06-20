import '../services/firebase/firestore_service.dart';
import '../models/billing_model.dart';

class BillingRepository {
  final FirestoreService _firestoreService;

  BillingRepository(this._firestoreService);

  Future<List<BillingModel>> getBills(String parentId) async {
    return await _firestoreService.getBillingRecords(parentId);
  }

  Stream<List<BillingModel>> watchBills(String parentId) {
    return _firestoreService.streamBillingRecords(parentId);
  }
}
