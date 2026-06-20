import 'package:flutter/material.dart';
import '../repositories/message_repository.dart';
import '../services/firebase/firestore_service.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class ChatProvider extends ChangeNotifier {
  final MessageRepository _messageRepository;
  final FirestoreService _firestoreService;

  List<UserModel> _conversations = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<UserModel> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ChatProvider(this._messageRepository, this._firestoreService);

  /// Fetches users with whom the current user can communicate (Parents or Drivers)
  Future<void> fetchConversations(String currentUserId, UserRole role) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _conversations = await _firestoreService.getChatPartners(currentUserId, role);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a text message to a receiver, inserting it into Firestore
  Future<void> sendMessage(String senderId, String receiverId, String text) async {
    if (text.trim().isEmpty) return;

    final message = MessageModel(
      id: 'MSG_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      receiverId: receiverId,
      messageText: text.trim(),
      timestamp: DateTime.now(),
      isRead: false,
      tripId: 'mock-ride-1',
    );

    try {
      await _messageRepository.send(message);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Marks all unread messages received from a specific partner as read
  Future<void> markMessagesAsRead(String senderId, String receiverId) async {
    try {
      await _messageRepository.markAsRead(senderId, receiverId);
    } catch (_) {}
  }

  /// Exposes a stream of messages between two users sorted chronologically
  Stream<List<MessageModel>> streamMessages(String user1, String user2) {
    return _messageRepository.watchChat(user1, user2);
  }

  /// Exposes a real-time stream of the unread messages count for a specific user conversation
  Stream<int> watchUnreadCount(String currentUserId, String chatPartnerId) {
    return _messageRepository.watchChat(chatPartnerId, currentUserId).map((messages) {
      return messages.where((m) => m.senderId == chatPartnerId && !m.isRead).length;
    });
  }
}
