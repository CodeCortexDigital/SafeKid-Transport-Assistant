import 'package:flutter/material.dart';
import '../repositories/billing_repository.dart';
import '../models/billing_model.dart';

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
}
