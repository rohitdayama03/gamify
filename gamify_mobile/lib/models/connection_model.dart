class PlayerSummary {
  final int playerId;
  final String username;
  // Signed S3 link to their profile picture, valid for about an hour; null shows their initial
  final String? avatarUrl;
  final String? playerBio;
  final String? country;
  final String? language;

  PlayerSummary({
    required this.playerId,
    required this.username,
    this.avatarUrl,
    this.playerBio,
    this.country,
    this.language,
  });

  factory PlayerSummary.fromJson(Map<String, dynamic> json) {
    return PlayerSummary(
      playerId: json['playerId'],
      username: json['username'],
      avatarUrl: json['avatarUrl'],
      playerBio: json['playerBio'],
      country: json['country'],
      language: json['language'],
    );
  }
}

enum ConnectionDirection { sent, received }

enum ConnectionStatus { pending, accepted, declined }

class ConnectionResponse {
  final int id;
  final PlayerSummary otherPlayer;
  final ConnectionDirection direction;
  final ConnectionStatus status;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  ConnectionResponse({
    required this.id,
    required this.otherPlayer,
    required this.direction,
    required this.status,
    this.createdAt,
    this.respondedAt,
  });

  factory ConnectionResponse.fromJson(Map<String, dynamic> json) {
    return ConnectionResponse(
      id: json['id'],
      otherPlayer: PlayerSummary.fromJson(json['otherPlayer']),
      direction: json['direction'] == 'SENT' ? ConnectionDirection.sent : ConnectionDirection.received,
      status: ConnectionStatus.values.byName((json['status'] as String).toLowerCase()),
      createdAt: _parseDate(json['createdAt']),
      respondedAt: _parseDate(json['respondedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
