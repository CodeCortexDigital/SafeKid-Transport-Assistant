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

  Future<void> updateStatus(String billId, String status, {String? paymentMethod}) async {
    await _firestoreService.updateBillingStatus(billId, status, paymentMethod: paymentMethod);
  }

  Stream<List<BillingModel>> watchBillsForParents(List<String> parentIds) {
    return _firestoreService.streamBillingRecordsForParents(parentIds);
  }

  Future<void> createBill(BillingModel bill) async {
    await _firestoreService.createBillingRecord(bill);
  }

  Future<void> updateBill(BillingModel bill) async {
    await _firestoreService.updateBillingRecord(bill);
  }

  Future<void> deleteBill(String billId) async {
    await _firestoreService.deleteBillingRecord(billId);
  }

  Future<bool> hasBillingRecordForMonth(String studentId, int year, int month) async {
    return await _firestoreService.hasBillingRecordForMonth(studentId, year, month);
  }
}
