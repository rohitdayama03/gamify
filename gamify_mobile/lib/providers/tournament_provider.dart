import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_error.dart';
import '../models/chat_model.dart';
import '../models/game.dart';
import '../models/tournament_format_model.dart';
import '../models/tournament_model.dart';

class TournamentProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  // Inbox data, kept fresh by the main screen's refresh
  List<TournamentChat> _chats = [];
  List<TournamentRequest> _requests = [];
  bool _isLoading = false;
  String? _errorMessage;
  // Request ids with an accept/reject in flight, to disable their buttons
  final Set<int> _busyRequestIds = {};

  List<TournamentChat> get chats => _chats;
  List<TournamentRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalUnread => _chats.fold(0, (sum, c) => sum + c.unreadCount);
  bool isBusy(int requestId) => _busyRequestIds.contains(requestId);

  /// Reloads the announcement chats and the join requests waiting on the player.
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      final responses = await Future.wait([
        _apiClient.dio.get(ApiEndpoints.tournamentChats),
        _apiClient.dio.get(ApiEndpoints.tournamentRequests),
      ]);
      _chats = ((responses[0].data ?? []) as List).map((e) => TournamentChat.fromJson(e)).toList();
      _requests = ((responses[1].data ?? []) as List).map((e) => TournamentRequest.fromJson(e)).toList();
      _errorMessage = null;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load tournaments');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Open tournaments, soonest first; all games when [game] is null. Returns null on failure.
  Future<List<TournamentSummary>?> fetchOpen({Game? game}) =>
      _listRequest(() => _apiClient.dio.get(ApiEndpoints.tournaments, queryParameters: {'game': ?game?.apiValue}));

  /// Shortest search text the backend searches on (TournamentController.MIN_SEARCH_LENGTH).
  static const int minSearchLength = 2;

  /// Tournaments whose name contains [query] or whose organizer's username starts with it, [pageSize] at a
  /// time. Returns null on failure.
  Future<List<TournamentSummary>?> searchTournaments({
    required String query,
    Game? game,
    TournamentStatusFilter status = TournamentStatusFilter.any,
    TournamentSearchSort sort = TournamentSearchSort.relevance,
    int page = 0,
    int pageSize = 20,
  }) =>
      _listRequest(() => _apiClient.dio.get(ApiEndpoints.searchTournaments, queryParameters: {
            'q': query,
            'game': ?game?.apiValue,
            'status': ?status.apiValue,
            'sort': sort.apiValue,
            'page': page,
            'size': pageSize,
          }));

  /// Tournaments the player organizes or has asked to join. Returns null on failure.
  Future<List<TournamentSummary>?> fetchMine() => _listRequest(() => _apiClient.dio.get(ApiEndpoints.myTournaments));

  Future<List<PlayerTournament>?> fetchPlayerTournaments(int playerId) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.playerTournaments(playerId));
      _errorMessage = null;
      return ((response.data ?? []) as List).map((e) => PlayerTournament.fromJson(e)).toList();
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load tournaments');
      return null;
    }
  }

  Future<TournamentDetail?> createTournament({
    required String name,
    required Game game,
    String? description,
    required DateTime startsAt,
    int? maxParticipants,
    FormatDraft? format,
  }) =>
      _detailRequest(
        () => _apiClient.dio.post(ApiEndpoints.tournaments, data: {
          'name': name,
          'game': game.apiValue,
          'description': description,
          // UTC with an offset, which the backend's OffsetDateTime expects
          'startsAt': startsAt.toUtc().toIso8601String(),
          'maxParticipants': maxParticipants,
          if (format != null) 'format': format.toJson(),
        }),
        'Could not create the tournament',
      );

  /// Organizer only, until a player has been accepted.
  Future<TournamentDetail?> updateFormat(int id, FormatDraft format) => _detailRequest(
        () => _apiClient.dio.put(ApiEndpoints.tournamentFormat(id), data: format.toJson()),
        'Could not save the format',
        refreshAfter: false,
      );

  /// Organizer only, once every slot is filled. [order] (participant ids, slot 1 first) for manual seeding;
  /// null shuffles the players.
  Future<TournamentDetail?> startTournament(int id, {List<int>? order}) => _detailRequest(
        () => _apiClient.dio.post(ApiEndpoints.startTournament(id), data: {
          'seeding': order == null ? 'RANDOM' : 'MANUAL',
          'order': order,
        }),
        'Could not start the tournament',
      );

  /// Organizer only, once every result in the stage is in. [groupOrders] maps a group to its participant ids
  /// in finishing order, for groups whose level players the organizer has put in order.
  Future<TournamentDetail?> finishStage(int id, int stageId, {Map<int, List<int>>? groupOrders}) => _detailRequest(
        () => _apiClient.dio.post(ApiEndpoints.finishStage(id, stageId), data: {
          'groupOrders': [
            for (final entry in (groupOrders ?? const <int, List<int>>{}).entries)
              {'groupNo': entry.key, 'participantIds': entry.value},
          ],
        }),
        'Could not finish the stage',
      );

  Future<TournamentFixtures?> fetchFixtures(int id) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.tournamentFixtures(id));
      _errorMessage = null;
      return TournamentFixtures.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load the fixtures');
      return null;
    }
  }

  /// Organizer only. [stats] maps a stat id to its (home, away) values; null values aren't recorded.
  /// Answers with the updated fixtures.
  Future<TournamentFixtures?> recordMatch(
    int id,
    int matchId, {
    required int homeScore,
    required int awayScore,
    int? homePens,
    int? awayPens,
    Map<int, (double?, double?)> stats = const {},
  }) async {
    try {
      final response = await _apiClient.dio.put(ApiEndpoints.tournamentMatch(id, matchId), data: {
        'homeScore': homeScore,
        'awayScore': awayScore,
        'homePens': homePens,
        'awayPens': awayPens,
        'stats': [
          for (final entry in stats.entries) {'statId': entry.key, 'home': entry.value.$1, 'away': entry.value.$2},
        ],
      });
      _errorMessage = null;
      return TournamentFixtures.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Could not save the result');
      return null;
    }
  }

  Future<TournamentLeaderboard?> fetchLeaderboard(int id) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.tournamentLeaderboard(id));
      _errorMessage = null;
      return TournamentLeaderboard.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load the standings');
      return null;
    }
  }

  Future<TournamentDetail?> fetchTournament(int id) =>
      _detailRequest(() => _apiClient.dio.get(ApiEndpoints.tournament(id)), 'Failed to load the tournament', refreshAfter: false);

  Future<TournamentDetail?> requestToJoin(int id) =>
      _detailRequest(() => _apiClient.dio.post(ApiEndpoints.joinTournament(id)), 'Could not send your request');

  Future<TournamentDetail?> withdraw(int id) =>
      _detailRequest(() => _apiClient.dio.delete(ApiEndpoints.joinTournament(id)), 'Could not withdraw');

  Future<TournamentDetail?> acceptRequest(int requestId) =>
      _answer(requestId, () => _apiClient.dio.post(ApiEndpoints.acceptTournamentRequest(requestId)), 'Could not accept the request');

  Future<TournamentDetail?> rejectRequest(int requestId) =>
      _answer(requestId, () => _apiClient.dio.post(ApiEndpoints.rejectTournamentRequest(requestId)), 'Could not reject the request');

  /// [placements] maps player ids to their place (1 = winner).
  Future<TournamentDetail?> recordResult(int id, Map<int, int> placements, String? notes) => _detailRequest(
        () => _apiClient.dio.put(ApiEndpoints.tournamentResult(id), data: {
          'placements': [
            for (final entry in placements.entries) {'playerId': entry.key, 'placement': entry.value},
          ],
          'notes': notes,
        }),
        'Could not save the result',
      );

  Future<bool> deleteTournament(int id) async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.tournament(id));
      _errorMessage = null;
      await refresh();
      return true;
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Could not cancel the tournament');
      return false;
    }
  }

  /// Announcements, oldest first. Pass [afterId] to poll for new ones
  /// or [beforeId] to load an older page. Returns null on failure.
  Future<List<ChatMessage>?> fetchMessages(int id, {int? afterId, int? beforeId}) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.tournamentMessages(id),
        queryParameters: {
          'afterId': ?afterId,
          'beforeId': ?beforeId,
        },
      );
      final List data = response.data ?? [];
      _errorMessage = null;
      return data.map((e) => ChatMessage.fromJson(e)).toList();
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load messages');
      return null;
    }
  }

  /// Organizer only.
  Future<ChatMessage?> sendMessage(int id, String content) async {
    try {
      final response = await _apiClient.dio.post(ApiEndpoints.tournamentMessages(id), data: {'content': content});
      _errorMessage = null;
      return ChatMessage.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Message not sent');
      return null;
    }
  }

  Future<TournamentDetail?> _answer(int requestId, Future<Response> Function() request, String fallbackError) async {
    _busyRequestIds.add(requestId);
    notifyListeners();
    try {
      final detail = await _detailRequest(request, fallbackError);
      // A stale request (e.g. already answered elsewhere) should disappear from the list
      if (detail == null) await refresh();
      return detail;
    } finally {
      _busyRequestIds.remove(requestId);
      notifyListeners();
    }
  }

  Future<List<TournamentSummary>?> _listRequest(Future<Response> Function() request) async {
    try {
      final response = await request();
      _errorMessage = null;
      return ((response.data ?? []) as List).map((e) => TournamentSummary.fromJson(e)).toList();
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, 'Failed to load tournaments');
      return null;
    }
  }

  // Runs a request that answers with the tournament, then reloads the Inbox data so badges stay right
  Future<TournamentDetail?> _detailRequest(Future<Response> Function() request, String fallbackError,
      {bool refreshAfter = true}) async {
    try {
      final response = await request();
      _errorMessage = null;
      if (refreshAfter) await refresh();
      return TournamentDetail.fromJson(response.data);
    } on DioException catch (e) {
      _errorMessage = apiErrorMessage(e, fallbackError);
      return null;
    }
  }
}
