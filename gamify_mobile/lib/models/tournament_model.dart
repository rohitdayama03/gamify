import 'chat_model.dart';
import 'connection_model.dart';
import 'game.dart';

DateTime? _parseDate(dynamic value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// Where the signed-in player stands with a tournament.
enum TournamentRole { organizer, pending, accepted, rejected, none }

/// "1st", "2nd", "3rd", "11th"…
String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
}

class TournamentSummary {
  final int id;
  final String name;
  final Game? game;
  final String? description;
  final DateTime startsAt;
  // Null means no limit
  final int? maxParticipants;
  final int participantCount;
  final bool completed;
  final PlayerSummary organizer;
  final TournamentRole myRole;

  TournamentSummary({
    required this.id,
    required this.name,
    this.game,
    this.description,
    required this.startsAt,
    this.maxParticipants,
    required this.participantCount,
    required this.completed,
    required this.organizer,
    required this.myRole,
  });

  bool get isFull => maxParticipants != null && participantCount >= maxParticipants!;
  bool get hasStarted => !startsAt.isAfter(DateTime.now());
  // The organizer and accepted players share the announcements chat
  bool get canOpenChat => myRole == TournamentRole.organizer || myRole == TournamentRole.accepted;

  String get slotsLabel => maxParticipants == null
      ? '$participantCount joined'
      : '$participantCount / $maxParticipants joined';

  factory TournamentSummary.fromJson(Map<String, dynamic> json) {
    return TournamentSummary(
      id: json['id'],
      name: json['name'],
      game: Game.fromApi(json['game']),
      description: json['description'],
      startsAt: _parseDate(json['startsAt']) ?? DateTime.now(),
      maxParticipants: json['maxParticipants'],
      participantCount: json['participantCount'] ?? 0,
      completed: json['status'] == 'COMPLETED',
      organizer: PlayerSummary.fromJson(json['organizer']),
      myRole: TournamentRole.values.byName(((json['myStatus'] ?? 'NONE') as String).toLowerCase()),
    );
  }
}

enum ParticipantStatus { pending, accepted, rejected }

class TournamentParticipant {
  // The join request's id, used to accept or reject it
  final int id;
  final PlayerSummary player;
  final ParticipantStatus status;
  final int? placement;
  final DateTime? requestedAt;

  TournamentParticipant({required this.id, required this.player, required this.status, this.placement, this.requestedAt});

  factory TournamentParticipant.fromJson(Map<String, dynamic> json) {
    return TournamentParticipant(
      id: json['id'],
      player: PlayerSummary.fromJson(json['player']),
      status: ParticipantStatus.values.byName((json['status'] as String).toLowerCase()),
      placement: json['placement'],
      requestedAt: _parseDate(json['requestedAt']),
    );
  }
}

class TournamentDetail {
  final TournamentSummary tournament;
  // Accepted players for everyone; the organizer also gets pending and rejected requests
  final List<TournamentParticipant> participants;
  final String? resultNotes;

  TournamentDetail({required this.tournament, required this.participants, this.resultNotes});

  List<TournamentParticipant> get accepted => participants.where((p) => p.status == ParticipantStatus.accepted).toList();
  List<TournamentParticipant> get pending => participants.where((p) => p.status == ParticipantStatus.pending).toList();

  factory TournamentDetail.fromJson(Map<String, dynamic> json) {
    final List participants = json['participants'] ?? [];
    return TournamentDetail(
      tournament: TournamentSummary.fromJson(json['tournament']),
      participants: participants.map((e) => TournamentParticipant.fromJson(e)).toList(),
      resultNotes: json['resultNotes'],
    );
  }
}

/// A pending join request to a tournament the signed-in player organizes.
class TournamentRequest {
  final int id;
  final int tournamentId;
  final String tournamentName;
  final Game? game;
  final PlayerSummary player;
  final DateTime? requestedAt;

  TournamentRequest({
    required this.id,
    required this.tournamentId,
    required this.tournamentName,
    this.game,
    required this.player,
    this.requestedAt,
  });

  factory TournamentRequest.fromJson(Map<String, dynamic> json) {
    return TournamentRequest(
      id: json['id'],
      tournamentId: json['tournamentId'],
      tournamentName: json['tournamentName'],
      game: Game.fromApi(json['game']),
      player: PlayerSummary.fromJson(json['player']),
      requestedAt: _parseDate(json['requestedAt']),
    );
  }
}

/// A tournament's announcements chat in the Inbox list.
class TournamentChat {
  final int id;
  final String name;
  final Game? game;
  // True when the signed-in player organizes it, and so can post
  final bool isOrganizer;
  final int participantCount;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime? since;

  TournamentChat({
    required this.id,
    required this.name,
    this.game,
    required this.isOrganizer,
    required this.participantCount,
    this.lastMessage,
    required this.unreadCount,
    this.since,
  });

  factory TournamentChat.fromJson(Map<String, dynamic> json) {
    return TournamentChat(
      id: json['id'],
      name: json['name'],
      game: Game.fromApi(json['game']),
      isOrganizer: json['organizer'] ?? false,
      participantCount: json['participantCount'] ?? 0,
      lastMessage: json['lastMessage'] == null ? null : ChatMessage.fromJson(json['lastMessage']),
      unreadCount: json['unreadCount'] ?? 0,
      since: _parseDate(json['since']),
    );
  }
}

/// A tournament on a player's profile.
class PlayerTournament {
  final int id;
  final String name;
  final Game? game;
  final DateTime startsAt;
  final bool completed;
  final int? placement;
  final int participantCount;
  final String organizerUsername;

  PlayerTournament({
    required this.id,
    required this.name,
    this.game,
    required this.startsAt,
    required this.completed,
    this.placement,
    required this.participantCount,
    required this.organizerUsername,
  });

  factory PlayerTournament.fromJson(Map<String, dynamic> json) {
    return PlayerTournament(
      id: json['id'],
      name: json['name'],
      game: Game.fromApi(json['game']),
      startsAt: _parseDate(json['startsAt']) ?? DateTime.now(),
      completed: json['status'] == 'COMPLETED',
      placement: json['placement'],
      participantCount: json['participantCount'] ?? 0,
      organizerUsername: json['organizerUsername'] ?? '',
    );
  }
}
