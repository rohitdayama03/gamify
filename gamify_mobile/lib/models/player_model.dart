class BgmiProfileResponse {
  final int? id;
  final String bgmiId;
  final String? currentRole;
  final String? experience;
  final String? availableTime;
  final String? achievements;
  final String? lookingFor;

  BgmiProfileResponse({
    this.id,
    required this.bgmiId,
    this.currentRole,
    this.experience,
    this.availableTime,
    this.achievements,
    this.lookingFor,
  });

  factory BgmiProfileResponse.fromJson(Map<String, dynamic> json) {
    return BgmiProfileResponse(
      id: json['id'],
      bgmiId: json['bgmiId'],
      currentRole: json['currentRole'],
      experience: json['experience'],
      availableTime: json['availableTime'],
      achievements: json['achievements'],
      lookingFor: json['lookingFor'],
    );
  }
}

class EfootballProfileResponse {
  final int? id;
  final String efootballId;
  final String? highTier;

  EfootballProfileResponse({
    this.id,
    required this.efootballId,
    this.highTier,
  });

  factory EfootballProfileResponse.fromJson(Map<String, dynamic> json) {
    return EfootballProfileResponse(
      id: json['id'],
      efootballId: json['efootballId'],
      highTier: json['highTier'],
    );
  }
}

class PlayerResponse {
  final int playerId;
  final String username;
  final String? playerBio;
  final String? language;
  final String? country;
  final BgmiProfileResponse? bgmiProfile;
  final EfootballProfileResponse? efootballProfile;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PlayerResponse({
    required this.playerId,
    required this.username,
    this.playerBio,
    this.language,
    this.country,
    this.bgmiProfile,
    this.efootballProfile,
    this.createdAt,
    this.updatedAt,
  });

  factory PlayerResponse.fromJson(Map<String, dynamic> json) {
    return PlayerResponse(
      playerId: json['playerId'],
      username: json['username'],
      playerBio: json['playerBio'],
      language: json['language'],
      country: json['country'],
      bgmiProfile: json['bgmiProfile'] != null
          ? BgmiProfileResponse.fromJson(json['bgmiProfile'])
          : null,
      efootballProfile: json['efootballProfile'] != null
          ? EfootballProfileResponse.fromJson(json['efootballProfile'])
          : null,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}