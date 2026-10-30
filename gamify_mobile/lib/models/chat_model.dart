import 'connection_model.dart';

/// A message in a friend chat or a squad. Squad messages have no [receiverId] and carry [senderName].
class ChatMessage {
  final int id;
  final int senderId;
  final int? receiverId;
  final String? senderName;
  final String content;
  final bool fromMe;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.receiverId,
    this.senderName,
    required this.content,
    required this.fromMe,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      senderName: json['senderUsername'],
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
