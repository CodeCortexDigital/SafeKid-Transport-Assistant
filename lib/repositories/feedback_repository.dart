import '../services/firebase/firestore_service.dart';
import '../models/feedback_model.dart';

class FeedbackRepository {
  final FirestoreService _firestoreService;

  FeedbackRepository(this._firestoreService);

  Future<void> submit(FeedbackModel feedback) async {
    await _firestoreService.submitFeedback(feedback);
  }

  Stream<List<FeedbackModel>> watchAllFeedback() {
    return _firestoreService.streamAllFeedback();
  }
}
