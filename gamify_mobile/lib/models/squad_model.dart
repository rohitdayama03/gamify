import 'chat_model.dart';
import 'connection_model.dart';

DateTime? _parseDate(dynamic value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// A squad in the chat list. [lastMessage] is null until someone writes.
class SquadSummary {
  final int id;
  final String name;
  final int ownerId;
  final int memberCount;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime? joinedAt;

  SquadSummary({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberCount,
    this.lastMessage,
    required this.unreadCount,
    this.joinedAt,
  });

  factory SquadSummary.fromJson(Map<String, dynamic> json) {
    return SquadSummary(
      id: json['id'],
      name: json['name'],
      ownerId: json['ownerId'],
      memberCount: json['memberCount'] ?? 0,
      lastMessage: json['lastMessage'] == null ? null : ChatMessage.fromJson(json['lastMessage']),
      unreadCount: json['unreadCount'] ?? 0,
      joinedAt: _parseDate(json['joinedAt']),
    );
  }
}

class SquadMember {
  final PlayerSummary player;
  // False while the invite is still pending
  final bool joined;
  final DateTime? invitedAt;
  final DateTime? joinedAt;

  SquadMember({required this.player, required this.joined, this.invitedAt, this.joinedAt});

  factory SquadMember.fromJson(Map<String, dynamic> json) {
    return SquadMember(
      player: PlayerSummary.fromJson(json['player']),
      joined: json['status'] == 'JOINED',
      invitedAt: _parseDate(json['invitedAt']),
      joinedAt: _parseDate(json['joinedAt']),
    );
  }
}

class SquadDetail {
  final int id;
  final String name;
  final int ownerId;
  // True when the signed-in player owns the squad
  final bool isOwner;
  // Joined members in the order they joined, then pending invites
  final List<SquadMember> members;

  SquadDetail({required this.id, required this.name, required this.ownerId, required this.isOwner, required this.members});

  List<SquadMember> get joined => members.where((m) => m.joined).toList();
  List<SquadMember> get invited => members.where((m) => !m.joined).toList();

  factory SquadDetail.fromJson(Map<String, dynamic> json) {
    final List members = json['members'] ?? [];
    return SquadDetail(
      id: json['id'],
      name: json['name'],
      ownerId: json['ownerId'],
      isOwner: json['owner'] ?? false,
      members: members.map((e) => SquadMember.fromJson(e)).toList(),
    );
  }
}

/// An invite to join a squad. [invitedBy] is null if the inviter has deleted their account.
class SquadInvite {
  final int id;
  final int squadId;
  final String squadName;
  final PlayerSummary? invitedBy;
  final int memberCount;
  final DateTime? createdAt;

  SquadInvite({
    required this.id,
    required this.squadId,
    required this.squadName,
    this.invitedBy,
    required this.memberCount,
    this.createdAt,
  });

  factory SquadInvite.fromJson(Map<String, dynamic> json) {
    return SquadInvite(
      id: json['id'],
      squadId: json['squadId'],
      squadName: json['squadName'],
      invitedBy: json['invitedBy'] == null ? null : PlayerSummary.fromJson(json['invitedBy']),
      memberCount: json['memberCount'] ?? 0,
      createdAt: _parseDate(json['createdAt']),
    );
  }
}
