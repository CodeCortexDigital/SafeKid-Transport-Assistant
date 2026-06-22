import 'package:flutter/material.dart';
import '../repositories/billing_repository.dart';
import '../models/billing_model.dart';
import '../models/student_model.dart';

class BillingProvider extends ChangeNotifier {
  final BillingRepository _billingRepository;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  BillingProvider(this._billingRepository);

  Stream<List<BillingModel>> streamParentBills(String parentId) {
    return _billingRepository.watchBills(parentId);
  }

  Stream<List<BillingModel>> streamDriverRouteBills(List<String> parentIds) {
    return _billingRepository.watchBillsForParents(parentIds);
  }

  Future<void> payBill(String billId, {String paymentMethod = 'Card'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _billingRepository.updateStatus(billId, 'paid', paymentMethod: paymentMethod);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsPaid(String billId) async {
    await payBill(billId, paymentMethod: 'Cash');
  }

  Future<void> createBill(BillingModel bill) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _billingRepository.createBill(bill);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateBill(BillingModel bill) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _billingRepository.updateBill(bill);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteBill(String billId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _billingRepository.deleteBill(billId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> autoGenerateMonthlyBills(List<StudentModel> students) async {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;
    bool createdAny = false;

    for (final student in students) {
      if (student.parentUid.isEmpty) continue;

      try {
        final exists = await _billingRepository.hasBillingRecordForMonth(
          student.id,
          currentYear,
          currentMonth,
        );

        if (!exists) {
          final billingDate = DateTime(currentYear, currentMonth, 1);
          final dueDate = DateTime(currentYear, currentMonth, 10);
          final newBill = BillingModel(
            id: 'bill_${student.id}_${currentYear}_${currentMonth}',
            parentId: student.parentUid,
            studentId: student.id,
            amount: student.monthlyFee,
            status: 'pending',
            billingDate: billingDate,
            dueDate: dueDate,
          );

          await _billingRepository.createBill(newBill);
          createdAny = true;
        }
      } catch (e) {
        debugPrint('Failed to auto-generate bill for student ${student.id}: $e');
      }
    }

    if (createdAny) {
      notifyListeners();
    }
  }
}
