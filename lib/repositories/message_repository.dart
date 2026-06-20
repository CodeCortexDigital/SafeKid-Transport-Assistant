import '../services/firebase/firestore_service.dart';
import '../models/message_model.dart';

class MessageRepository {
  final FirestoreService _firestoreService;

  MessageRepository(this._firestoreService);

  Future<void> send(MessageModel message) async {
    await _firestoreService.sendMessage(message);
  }

  Stream<List<MessageModel>> watchChat(String senderId, String receiverId) {
    return _firestoreService.streamMessages(senderId, receiverId);
  }
}
