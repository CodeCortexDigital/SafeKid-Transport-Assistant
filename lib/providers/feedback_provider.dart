import 'package:flutter/material.dart';
import '../repositories/feedback_repository.dart';
import '../models/feedback_model.dart';

class FeedbackProvider extends ChangeNotifier {
  final FeedbackRepository _feedbackRepository;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  FeedbackProvider(this._feedbackRepository);

  Stream<List<FeedbackModel>> watchAllFeedback() {
    return _feedbackRepository.watchAllFeedback();
  }

  Future<bool> submitFeedback({
    required String userId,
    required String userName,
    required int driverRating,
    required int safetyRating,
    required int punctualityRating,
    required String comments,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final feedback = FeedbackModel(
      id: 'FEED_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: userName.isNotEmpty ? userName : 'Parent',
      driverRating: driverRating,
      safetyRating: safetyRating,
      punctualityRating: punctualityRating,
      comments: comments.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await _feedbackRepository.submit(feedback);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
