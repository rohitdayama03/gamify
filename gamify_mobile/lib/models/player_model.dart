import 'game.dart';

class GtaProfileResponse {
  final int? id;
  final String characterName;
  final String platform;
  final List<String> activities;
  final int? rank;

  GtaProfileResponse({
    this.id,
    required this.characterName,
    required this.platform,
    this.activities = const [],
    this.rank,
  });

  factory GtaProfileResponse.fromJson(Map<String, dynamic> json) {
    return GtaProfileResponse(
      id: json['id'],
      characterName: json['characterName'],
      platform: json['platform'],
      activities: List<String>.from(json['activities'] ?? const []),
      rank: json['rank'],
    );
  }
}

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
  // Only present on the signed-in player's own profile
  final String? email;
  final String? playerBio;
  final String? language;
  final String? country;
  final List<Game> interestedGames;
  final Game? lastGame;
  final GtaProfileResponse? gtaProfile;
  final BgmiProfileResponse? bgmiProfile;
  final EfootballProfileResponse? efootballProfile;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PlayerResponse({
    required this.playerId,
    required this.username,
    this.email,
    this.playerBio,
    this.language,
    this.country,
    this.interestedGames = const [],
    this.lastGame,
    this.gtaProfile,
    this.bgmiProfile,
    this.efootballProfile,
    this.createdAt,
    this.updatedAt,
  });

  factory PlayerResponse.fromJson(Map<String, dynamic> json) {
    return PlayerResponse(
      playerId: json['playerId'],
      username: json['username'],
      email: json['email'],
      playerBio: json['playerBio'],
      language: json['language'],
      country: json['country'],
      interestedGames: Game.listFromApi(json['interestedGames']),
      lastGame: Game.fromApi(json['lastGame']),
      gtaProfile: json['gtaProfile'] != null
          ? GtaProfileResponse.fromJson(json['gtaProfile'])
          : null,
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

  /// Players who registered before onboarding existed have no interests yet
  bool get needsOnboarding => interestedGames.isEmpty;

  /// Game to open on Home/Discover: last used, else the first interest (PRD §6.1)
  Game? get preferredGame => lastGame ?? (interestedGames.isEmpty ? null : interestedGames.first);

  bool hasProfileFor(Game game) => switch (game) {
        Game.gta => gtaProfile != null,
        Game.bgmi => bgmiProfile != null,
        Game.efootball => efootballProfile != null,
      };

  static DateTime? _parseDate(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}