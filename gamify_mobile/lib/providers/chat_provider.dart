import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/chat_model.dart';

class ChatProvider extends ChangeNotifier {
  // Matches the backend page size; a full page means older messages may exist
  static const int pageSize = 50;

  final ApiClient _apiClient = ApiClient();

  List<Conversation> _conversations = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalUnread => _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  Future<void> fetchConversations() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.chats);
      final List data = response.data ?? [];
      _conversations = data.map((e) => Conversation.fromJson(e)).toList();
      _errorMessage = null;
    } on DioException catch (e) {
      _errorMessage = e.response?.data['message'] ?? 'Failed to load conversations';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Messages with [friendId], oldest first. Pass [afterId] to poll for new messages
  /// or [beforeId] to load an older page. Returns null on failure.
  Future<List<ChatMessage>?> fetchMessages(int friendId, {int? afterId, int? beforeId}) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.chatMessages(friendId),
        queryParameters: {
          'afterId': ?afterId,
          'beforeId': ?beforeId,
        },
      );
      final List data = response.data ?? [];
      _errorMessage = null;
      return data.map((e) => ChatMessage.fromJson(e)).toList();
    } on DioException catch (e) {
      _errorMessage = e.response?.data['message'] ?? 'Failed to load messages';
      return null;
    }
  }

  Future<ChatMessage?> sendMessage(int friendId, String content) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.chatMessages(friendId),
        data: {'content': content},
      );
      _errorMessage = null;
      return ChatMessage.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = e.response?.data['message'] ?? 'Message not sent';
      return null;
    }
  }
}
