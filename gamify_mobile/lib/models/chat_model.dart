import 'connection_model.dart';

class ChatMessage {
  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final bool fromMe;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.fromMe,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      content: json['content'],
      fromMe: json['fromMe'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

class Conversation {
  final PlayerSummary friend;
  final ChatMessage lastMessage;
  final int unreadCount;

  Conversation({required this.friend, required this.lastMessage, required this.unreadCount});

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      friend: PlayerSummary.fromJson(json['friend']),
      lastMessage: ChatMessage.fromJson(json['lastMessage']),
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}
